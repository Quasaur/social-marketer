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
        "daily": URL(string: "https://wisdombook.life/feed/daily.xml")!,
        "wisdom": URL(string: "https://wisdombook.life/feed/wisdom.xml")!,
        "thoughts": URL(string: "https://wisdombook.life/feed/thoughts.xml")!,
        "quotes": URL(string: "https://wisdombook.life/feed/quotes.xml")!,
        "passages": URL(string: "https://wisdombook.life/feed/passages.xml")!
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
        
        // Extract reference from content (e.g., "- Proverbs 3:27")
        let reference = extractReference(from: currentContent)
        
        // Clean content
        let cleanContent = cleanHTML(currentContent)
        
        // Parse date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "E, dd MMM yyyy HH:mm:ss zzz"
        let pubDate = dateFormatter.date(from: currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines)) ?? Date()
        
        let entry = WisdomEntry(
            id: UUID(),
            title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            content: cleanContent,
            reference: reference,
            link: URL(string: currentLink.trimmingCharacters(in: .whitespacesAndNewlines)) ?? URL(string: "https://wisdombook.life")!,
            pubDate: pubDate,
            category: category
        )
        
        entries.append(entry)
    }
    
    private func cleanHTML(_ html: String) -> String {
        // Remove HTML tags and CDATA
        var text = html
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "<!\\[CDATA\\[", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\]\\]>", with: "", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text
    }
    
    private func extractReference(from content: String) -> String? {
        // Look for scripture references like "Proverbs 3:27"
        let pattern = "([1-3]?\\s?[A-Z][a-z]+\\s\\d+:\\d+(?:[-,]\\d+)?)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range, in: content) else {
            return nil
        }
        return String(content[range])
    }
}
