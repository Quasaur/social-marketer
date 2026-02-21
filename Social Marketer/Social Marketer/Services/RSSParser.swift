//
//  RSSParser.swift
//  SocialMarketer
//
//  RSS feed parser for wisdombook.life content
//

import Foundation

/// Represents a single wisdom entry from the RSS feed
struct WisdomEntry: Identifiable, Codable {
    let id: UUID
    let title: String
    let content: String
    let reference: String?
    let link: URL
    let pubDate: Date
    let category: WisdomCategory
    
    enum WisdomCategory: String, Codable {
        case thought = "Thought"
        case quote = "Quote"
        case passage = "Passage"
        case introduction = "Introduction"
    }
}

/// RSS feed parser service
actor RSSParser {
    
    enum RSSError: Error {
        case invalidURL
        case fetchFailed(Error)
        case parsingFailed
    }
    
    // MARK: - Feed URLs
    
    static let feedURLs: [String: URL] = [
        "daily": URL(string: "https://www.wisdombook.life/feed/daily.xml")!,
        "wisdom": URL(string: "https://www.wisdombook.life/feed/wisdom.xml")!,
        "thoughts": URL(string: "https://www.wisdombook.life/feed/thoughts.xml")!,
        "quotes": URL(string: "https://www.wisdombook.life/feed/quotes.xml")!,
        "passages": URL(string: "https://www.wisdombook.life/feed/passages.xml")!
    ]
    
    // MARK: - Public Methods
    
    /// Fetch the daily wisdom entry
    func fetchDaily() async throws -> WisdomEntry? {
        let entries = try await fetchFeed(url: Self.feedURLs["daily"]!)
        return entries.first
    }
    
    /// Fetch entries from a specific feed
    func fetchFeed(url: URL) async throws -> [WisdomEntry] {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let entries = try parseRSS(data: data)
            return entries
        } catch {
            Task { @MainActor in
                ErrorLog.shared.log(category: "RSS", message: "Feed fetch failed for \(url.lastPathComponent)", detail: error.localizedDescription)
            }
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func parseRSS(data: Data) throws -> [WisdomEntry] {
        let parser = RSSXMLParser(data: data)
        return try parser.parse()
    }
}

/// XML parser for RSS feeds
@preconcurrency
final class RSSXMLParser: NSObject, XMLParserDelegate {
    
    // MARK: - Shared Formatters & Patterns (allocated once, reused across all entries)
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "E, dd MMM yyyy HH:mm:ss zzz"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    // Pre-compiled regex patterns for fallback extraction only
    private static let scriptureRefRegex = try! NSRegularExpression(pattern: "([1-3]?\\s?[A-Z][a-z]+(?:\\s+[a-z]+[A-Za-z]*)*\\s+\\d+:\\d+(?:[-,]\\d+)*)", options: .caseInsensitive)
    private static let bookNameRegex = try! NSRegularExpression(pattern: "<em>\\s*(?!Parent\\s+Topic)(?!Topic)(?!From)([^<]+?)\\s*</em>", options: .caseInsensitive)
    
    private let data: Data
    private var entries: [WisdomEntry] = []
    private var currentElement: String = ""
    private var currentTitle: String = ""
    private var currentContent: String = ""
    private var currentLink: String = ""
    private var currentPubDate: String = ""
    private var currentCategory: String = ""
    private var currentWisdomSource: String = ""
    private var isInsideItem: Bool = false
    
    init(data: Data) {
        self.data = data
    }
    
    func parse() throws -> [WisdomEntry] {
        if Log.isDebugMode {
            Log.debug("XMLParser.parse() starting...", category: "RSS")
        }
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        if Log.isDebugMode {
            Log.debug("XMLParser.parse() completed, \(entries.count) entries", category: "RSS")
        }
        return entries
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "item" {
            isInsideItem = true
            currentTitle = ""
            currentContent = ""
            currentLink = ""
            currentPubDate = ""
            currentCategory = ""
            currentWisdomSource = ""
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideItem else { return }
        
        switch currentElement {
        case "title":
            currentTitle += string
        case "description":
            currentContent += string
        case "link":
            currentLink += string
        case "pubDate":
            currentPubDate += string
        case "category":
            currentCategory += string
        case "wisdom:source":
            // XMLParser reports the full qualified name when namespace processing is off (default)
            currentWisdomSource += string
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard elementName == "item" else { return }
        isInsideItem = false
        
        print("[DEBUG] Processing item #\(entries.count + 1)...")
        
        // Parse category
        let category: WisdomEntry.WisdomCategory
        if currentCategory.contains("Thought") {
            category = .thought
        } else if currentCategory.contains("Quote") {
            category = .quote
        } else {
            category = .passage
        }
        
        // Extract reference — priority: wisdom:source > title suffix > <em> book > content regex
        var titleText = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        var reference: String? = nil
        
        // 1. Primary: <wisdom:source> element (canonical since Feb 2026)
        let wisdomSource = currentWisdomSource.trimmingCharacters(in: .whitespacesAndNewlines)
        if !wisdomSource.isEmpty {
            reference = wisdomSource
        }
        
        // 2. Fallback: titles may contain reference after " - " (legacy format)
        if reference == nil, let dashRange = titleText.range(of: " - ", options: .backwards) {
            let possibleRef = String(titleText[dashRange.upperBound...])
            if possibleRef.contains(":") {
                reference = possibleRef.trimmingCharacters(in: .whitespacesAndNewlines)
                titleText = String(titleText[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // 3. Fallback: extract book name from <em> tag (standalone, not "Parent Topic")
        if reference == nil {
            if Log.isDebugMode {
                Log.debug("Calling extractBookName...", category: "RSS")
            }
            reference = extractBookName(from: currentContent)
            if Log.isDebugMode {
                Log.debug("extractBookName done", category: "RSS")
            }
        }
        
        // 4. Fallback: try extracting scripture reference from content text
        // DISABLED: Causes catastrophic backtracking on some inputs
        // All feeds now have <wisdom:source> so this is unnecessary
        /*
        if reference == nil {
            if Log.isDebugMode {
                Log.debug("Calling extractReference...", category: "RSS")
            }
            reference = extractReference(from: currentContent)
            if Log.isDebugMode {
                Log.debug("extractReference done", category: "RSS")
            }
        }
        */
        
        // Clean content
        print("[DEBUG] Calling cleanHTML...")
        let cleanContent = cleanHTML(currentContent)
        print("[DEBUG] cleanHTML done")
        
        // Parse date
        let pubDate = Self.dateFormatter.date(from: currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines)) ?? Date()
        
        let entry = WisdomEntry(
            id: UUID(),
            title: titleText,
            content: cleanContent,
            reference: reference,
            link: URL(string: currentLink.trimmingCharacters(in: .whitespacesAndNewlines)) ?? URL(string: "https://wisdombook.life")!,
            pubDate: pubDate,
            category: category
        )
        
        entries.append(entry)
    }
    
    private func cleanHTML(_ html: String) -> String {
        // RSS feed now outputs clean plain text content (as of Feb 13, 2026)
        // Only need to decode HTML entities (required by RSS spec)
        return html
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractReference(from content: String) -> String? {
        let range = NSRange(content.startIndex..., in: content)
        guard let match = Self.scriptureRefRegex.firstMatch(in: content, range: range),
              let matchRange = Range(match.range, in: content) else {
            return nil
        }
        return String(content[matchRange])
    }
    
    private func extractBookName(from content: String) -> String? {
        let range = NSRange(content.startIndex..., in: content)
        let matches = Self.bookNameRegex.matches(in: content, range: range)
        for match in matches {
            guard let captureRange = Range(match.range(at: 1), in: content) else { continue }
            let name = String(content[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if name.hasPrefix("Level") || name.isEmpty { continue }
            return name
        }
        return nil
    }
}
