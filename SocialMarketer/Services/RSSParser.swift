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
        Log.rss.info("Fetching feed: \(url.lastPathComponent)")
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let entries = try parseRSS(data: data)
            Log.rss.info("Parsed \(entries.count) entries from \(url.lastPathComponent)")
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
    
    private let data: Data
    private var entries: [WisdomEntry] = []
    private var currentElement: String = ""
    private var currentTitle: String = ""
    private var currentContent: String = ""
    private var currentLink: String = ""
    private var currentPubDate: String = ""
    private var currentCategory: String = ""
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
        
        // Extract reference: first try title (\"TITLE - Proverbs 3:27\"), then description
        var titleText = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        var reference: String? = nil
        
        // Titles may contain reference after " - " (e.g., "SCORNERS - Proverbs 3:34")
        if let dashRange = titleText.range(of: " - ", options: .backwards) {
            let possibleRef = String(titleText[dashRange.upperBound...])
            // Check if the part after " - " looks like a Scripture reference
            if possibleRef.contains(":") {
                reference = possibleRef.trimmingCharacters(in: .whitespacesAndNewlines)
                titleText = String(titleText[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // For quotes: extract book name from <em> tag (standalone, not "Parent Topic")
        if reference == nil {
            reference = extractBookName(from: currentContent)
        }
        
        // Fallback: try extracting scripture reference from content
        if reference == nil {
            reference = extractReference(from: currentContent)
        }
        
        // Clean content
        let cleanContent = cleanHTML(currentContent)
        
        // Parse date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "E, dd MMM yyyy HH:mm:ss zzz"
        let pubDate = dateFormatter.date(from: currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines)) ?? Date()
        
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
        // Convert paragraph and break tags to newlines first (preserves structure)
        text = text.replacingOccurrences(of: "</p>", with: "\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        // Remove remaining HTML tags and CDATA
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "<!\\[CDATA\\[", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\]\\]>", with: "", options: .regularExpression)
        // Decode HTML entities
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        // Strip multilingual content markers and non-English translations
        // Remove "# Thought: TITLE" header lines
        text = text.replacingOccurrences(of: "(?m)^\\s*#\\s*Thought:.*$", with: "", options: .regularExpression)
        // Remove language markers like [!Thought-en], [!Pensamiento-es], etc.
        text = text.replacingOccurrences(of: "\\[![^\\]]+\\]", with: "", options: .regularExpression)
        // Remove non-English text blocks: everything from first non-English marker to end of paragraph
        // Non-English markers: Pensamiento, Pensée, सोचा, 思考
        if let nonEnRange = text.range(of: "(?s)(Llegará|C'est une|Es algo|Es una|वह दिन|यह एक|这是|邪恶|我们).*$", options: .regularExpression) {
            text = String(text[..<nonEnRange.lowerBound])
        }
        // Strip metadata lines: "Thought - Level 5", "Level 4 Passage", "Level 4 - Proverbs 3:34", etc.
        text = text.replacingOccurrences(of: "(?m)^\\s*(Thought|Quote|Passage|Introduction)\\s*-\\s*Level\\s*\\d+\\s*$", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?m)^\\s*Level\\s*\\d+\\s*(Thought|Quote|Passage|Introduction)\\s*$", with: "", options: .regularExpression)
        // Strip "Level N - Reference" lines (e.g., "Level 4 - Proverbs 3:34")
        text = text.replacingOccurrences(of: "(?m)^\\s*Level\\s*\\d+\\s*-\\s*.*$", with: "", options: .regularExpression)
        // Strip standalone "Level N" lines
        text = text.replacingOccurrences(of: "(?m)^\\s*Level\\s*\\d+\\s*$", with: "", options: .regularExpression)
        // Strip "From: Topic: ..." and "Parent Topic: ..." lines
        text = text.replacingOccurrences(of: "(?m)^\\s*From:?\\s*Topic:?\\s*.*$", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?m)^\\s*Parent\\s+Topic:?\\s*.*$", with: "", options: .regularExpression)
        // Strip standalone book name lines (not preceded by content indicators)
        // These are lines that are just a book title, like "The Narrow Way"
        if let bookName = extractBookName(from: html) {
            // Strip the plain-text version of the book name on its own line
            let escaped = NSRegularExpression.escapedPattern(for: bookName)
            text = text.replacingOccurrences(of: "(?m)^\\s*" + escaped + "\\s*$", with: "", options: .regularExpression)
        }
        // Collapse multiple blank lines into one
        text = text.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text
    }
    
    private func extractReference(from content: String) -> String? {
        // Look for scripture references like "Proverbs 3:27", "1 Corinthians 13:4", "Proverbs 3:21-26"
        let pattern = "([1-3]?\\s?[A-Z][a-z]+(?:\\s+[a-z]+[A-Za-z]*)*\\s+\\d+:\\d+(?:[-,]\\d+)*)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range, in: content) else {
            return nil
        }
        return String(content[range])
    }
    
    private func extractBookName(from content: String) -> String? {
        // Look for standalone <em> tags that contain a book name (not "Parent Topic" or "Topic" lines)
        // Pattern: <em>Book Name</em> where Book Name doesn't start with "Parent Topic" or "Topic"
        let pattern = "<em>\\s*(?!Parent\\s+Topic)(?!Topic)(?!From)([^<]+?)\\s*</em>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        
        let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        for match in matches {
            guard let range = Range(match.range(at: 1), in: content) else { continue }
            let name = String(content[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            // Skip if it looks like metadata
            if name.hasPrefix("Level") || name.isEmpty { continue }
            return name
        }
        return nil
    }
}
