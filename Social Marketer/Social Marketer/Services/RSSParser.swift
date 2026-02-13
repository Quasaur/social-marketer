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
        Log.rss.info("Fetching daily wisdom entry...")
        let entries = try await fetchFeed(url: Self.feedURLs["daily"]!)
        Log.rss.debug("Daily fetch returned \(entries.count) entries")
        return entries.first
    }
    
    /// Fetch entries from a specific feed
    func fetchFeed(url: URL) async throws -> [WisdomEntry] {
        let startTime = Date()
        Log.rss.info("Fetching feed: \(url.lastPathComponent)")
        do {
            let networkStart = Date()
            let (data, _) = try await URLSession.shared.data(from: url)
            let networkTime = Date().timeIntervalSince(networkStart)
            Log.rss.info("Network fetch completed in \(String(format: "%.2f", networkTime))s, data size: \(data.count) bytes")
            
            let parseStart = Date()
            let entries = try parseRSS(data: data)
            let parseTime = Date().timeIntervalSince(parseStart)
            Log.rss.info("XML parsing completed in \(String(format: "%.2f", parseTime))s")
            
            let totalTime = Date().timeIntervalSince(startTime)
            Log.rss.info("Parsed \(entries.count) entries from \(url.lastPathComponent) in \(String(format: "%.2f", totalTime))s total")
            return entries
        } catch {
            Log.rss.error("Feed fetch failed for \(url.lastPathComponent): \(error.localizedDescription)")
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
final class RSSXMLParser: NSObject, XMLParserDelegate {
    
    // MARK: - Shared Formatters & Patterns (allocated once, reused across all entries)
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "E, dd MMM yyyy HH:mm:ss zzz"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    // Pre-compiled regex patterns for cleanHTML, extractReference, and extractBookName
    private static let brTagRegex = try! NSRegularExpression(pattern: "<br\\s*/?>", options: .caseInsensitive)
    private static let htmlTagRegex = try! NSRegularExpression(pattern: "<[^>]+>", options: [])
    private static let cdataOpenRegex = try! NSRegularExpression(pattern: "<!\\[CDATA\\[", options: [])
    private static let cdataCloseRegex = try! NSRegularExpression(pattern: "\\]\\]>", options: [])
    private static let thoughtHeaderRegex = try! NSRegularExpression(pattern: "(?m)^\\s*#\\s*Thought:.*$", options: [])
    private static let languageMarkerRegex = try! NSRegularExpression(pattern: "\\[![^\\]]+\\]", options: [])
    private static let nonEnglishRegex = try! NSRegularExpression(pattern: "(?s)(Llegará|C'est une|Es algo|Es una|वह दिन|यह एक|这是|邪恶|我们).*$", options: [])
    private static let metadataTypeLevel = try! NSRegularExpression(pattern: "(?m)^\\s*(Thought|Quote|Passage|Introduction)\\s*-\\s*Level\\s*\\d+\\s*$", options: [])
    private static let metadataLevelType = try! NSRegularExpression(pattern: "(?m)^\\s*Level\\s*\\d+\\s*(Thought|Quote|Passage|Introduction)\\s*$", options: [])
    private static let metadataLevelRef = try! NSRegularExpression(pattern: "(?m)^\\s*Level\\s*\\d+\\s*-\\s*.*$", options: [])
    private static let metadataLevelStandalone = try! NSRegularExpression(pattern: "(?m)^\\s*Level\\s*\\d+\\s*$", options: [])
    private static let fromTopicRegex = try! NSRegularExpression(pattern: "(?m)^\\s*From:?\\s*Topic:?\\s*.*$", options: [])
    private static let parentTopicRegex = try! NSRegularExpression(pattern: "(?m)^\\s*Parent\\s+Topic:?\\s*.*$", options: [])
    private static let multiBlankLineRegex = try! NSRegularExpression(pattern: "\\n{3,}", options: [])
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
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
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
            reference = extractBookName(from: currentContent)
        }
        
        // 4. Fallback: try extracting scripture reference from content text
        if reference == nil {
            reference = extractReference(from: currentContent)
        }
        
        // Clean content
        let cleanContent = cleanHTML(currentContent)
        
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
        var text = html
        let fullRange = { NSRange(text.startIndex..., in: text) }
        // Convert paragraph and break tags to newlines first (preserves structure)
        text = text.replacingOccurrences(of: "</p>", with: "\n", options: .caseInsensitive)
        text = Self.brTagRegex.stringByReplacingMatches(in: text, range: fullRange(), withTemplate: "\n")
        // Remove remaining HTML tags and CDATA
        text = Self.htmlTagRegex.stringByReplacingMatches(in: text, range: fullRange(), withTemplate: "")
        text = Self.cdataOpenRegex.stringByReplacingMatches(in: text, range: fullRange(), withTemplate: "")
        text = Self.cdataCloseRegex.stringByReplacingMatches(in: text, range: fullRange(), withTemplate: "")
        // Decode HTML entities
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        // Strip multilingual content markers and non-English translations
        // Remove "# Thought: TITLE" header lines
        text = Self.thoughtHeaderRegex.stringByReplacingMatches(in: text, range: fullRange(), withTemplate: "")
        // Remove language markers like [!Thought-en], [!Pensamiento-es], etc.
        text = Self.languageMarkerRegex.stringByReplacingMatches(in: text, range: fullRange(), withTemplate: "")
        // Remove non-English text blocks: everything from first non-English marker to end
        if let match = Self.nonEnglishRegex.firstMatch(in: text, range: fullRange()) {
            let matchRange = Range(match.range, in: text)!
            text = String(text[..<matchRange.lowerBound])
        }
        // Strip metadata lines: "Thought - Level 5", "Level 4 Passage", etc.
        text = Self.metadataTypeLevel.stringByReplacingMatches(in: text, range: fullRange(), withTemplate: "")
        text = Self.metadataLevelType.stringByReplacingMatches(in: text, range: fullRange(), withTemplate: "")
        // Strip "Level N - Reference" lines
        text = Self.metadataLevelRef.stringByReplacingMatches(in: text, range: fullRange(), withTemplate: "")
        // Strip standalone "Level N" lines
        text = Self.metadataLevelStandalone.stringByReplacingMatches(in: text, range: fullRange(), withTemplate: "")
        // Strip "From: Topic: ..." and "Parent Topic: ..." lines
        text = Self.fromTopicRegex.stringByReplacingMatches(in: text, range: fullRange(), withTemplate: "")
        text = Self.parentTopicRegex.stringByReplacingMatches(in: text, range: fullRange(), withTemplate: "")
        // Collapse multiple blank lines into one
        text = Self.multiBlankLineRegex.stringByReplacingMatches(in: text, range: fullRange(), withTemplate: "\n\n")
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text
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
