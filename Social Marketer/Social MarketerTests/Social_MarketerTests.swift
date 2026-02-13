//
//  Social_MarketerTests.swift
//  Social MarketerTests
//
//  Comprehensive unit tests for Social Marketer
//

import XCTest
@testable import Social_Marketer

// MARK: - WisdomEntry Tests

final class WisdomEntryTests: XCTestCase {
    
    func testWisdomEntryCreation() throws {
        let entry = WisdomEntry(
            id: UUID(),
            title: "Test Wisdom",
            content: "Be kind to one another.",
            reference: "Ephesians 4:32",
            link: URL(string: "https://wisdombook.life/wisdom/test")!,
            pubDate: Date(),
            category: .thought
        )
        
        XCTAssertEqual(entry.title, "Test Wisdom")
        XCTAssertEqual(entry.content, "Be kind to one another.")
        XCTAssertEqual(entry.reference, "Ephesians 4:32")
        XCTAssertEqual(entry.category, .thought)
        XCTAssertEqual(entry.link.absoluteString, "https://wisdombook.life/wisdom/test")
    }
    
    func testWisdomCategoryRawValues() throws {
        XCTAssertEqual(WisdomEntry.WisdomCategory.thought.rawValue, "Thought")
        XCTAssertEqual(WisdomEntry.WisdomCategory.quote.rawValue, "Quote")
        XCTAssertEqual(WisdomEntry.WisdomCategory.passage.rawValue, "Passage")
        XCTAssertEqual(WisdomEntry.WisdomCategory.introduction.rawValue, "Introduction")
    }
    
    func testWisdomCategoryFromRawValue() throws {
        XCTAssertEqual(WisdomEntry.WisdomCategory(rawValue: "Thought"), .thought)
        XCTAssertEqual(WisdomEntry.WisdomCategory(rawValue: "Quote"), .quote)
        XCTAssertEqual(WisdomEntry.WisdomCategory(rawValue: "Passage"), .passage)
        XCTAssertEqual(WisdomEntry.WisdomCategory(rawValue: "Introduction"), .introduction)
        XCTAssertNil(WisdomEntry.WisdomCategory(rawValue: "Invalid"))
    }
    
    func testWisdomEntryWithNilReference() throws {
        let entry = WisdomEntry(
            id: UUID(),
            title: "No Reference",
            content: "A thought without a source.",
            reference: nil,
            link: URL(string: "https://wisdombook.life")!,
            pubDate: Date(),
            category: .thought
        )
        
        XCTAssertNil(entry.reference)
    }
    
    func testWisdomEntryCodable() throws {
        let entry = WisdomEntry(
            id: UUID(),
            title: "Codable Test",
            content: "Test content",
            reference: "Test 1:1",
            link: URL(string: "https://wisdombook.life/test")!,
            pubDate: Date(timeIntervalSince1970: 1700000000),
            category: .quote
        )
        
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(WisdomEntry.self, from: data)
        
        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.title, entry.title)
        XCTAssertEqual(decoded.content, entry.content)
        XCTAssertEqual(decoded.reference, entry.reference)
        XCTAssertEqual(decoded.category, entry.category)
        XCTAssertEqual(decoded.link, entry.link)
    }
}

// MARK: - RSS Parser Tests

final class RSSXMLParserTests: XCTestCase {
    
    // MARK: - Basic Parsing
    
    func testParseValidRSSFeed() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <title>Wisdom Book</title>
                <item>
                    <title>Daily Thought</title>
                    <description>Be still and know.</description>
                    <link>https://wisdombook.life/wisdom/daily</link>
                    <pubDate>Mon, 10 Feb 2026 09:00:00 EST</pubDate>
                    <category>Thought</category>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.title, "Daily Thought")
        XCTAssertEqual(entries.first?.content, "Be still and know.")
        XCTAssertEqual(entries.first?.category, .thought)
        XCTAssertEqual(entries.first?.link.absoluteString, "https://wisdombook.life/wisdom/daily")
    }
    
    func testParseMultipleItems() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <item>
                    <title>First</title>
                    <description>Content 1</description>
                    <link>https://wisdombook.life/1</link>
                    <pubDate>Mon, 10 Feb 2026 09:00:00 EST</pubDate>
                    <category>Thought</category>
                </item>
                <item>
                    <title>Second</title>
                    <description>Content 2</description>
                    <link>https://wisdombook.life/2</link>
                    <pubDate>Tue, 11 Feb 2026 09:00:00 EST</pubDate>
                    <category>Quote</category>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].title, "First")
        XCTAssertEqual(entries[0].category, .thought)
        XCTAssertEqual(entries[1].title, "Second")
        XCTAssertEqual(entries[1].category, .quote)
    }
    
    func testParseEmptyFeed() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <title>Empty Feed</title>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        XCTAssertTrue(entries.isEmpty)
    }
    
    func testParseCategoryMapping() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <item>
                    <title>Unknown Cat</title>
                    <description>Content</description>
                    <link>https://wisdombook.life/test</link>
                    <pubDate>Mon, 10 Feb 2026 09:00:00 EST</pubDate>
                    <category>SomethingElse</category>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        XCTAssertEqual(entries.first?.category, .passage, "Unknown categories should default to Passage")
    }
    
    func testParseMultipleCategories() throws {
        // Real feeds have multiple <category> elements per item
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <item>
                    <title>Multi Cat</title>
                    <description>Content</description>
                    <link>https://wisdombook.life/test</link>
                    <pubDate>Mon, 10 Feb 2026 09:00:00 EST</pubDate>
                    <category>Wisdom</category>
                    <category>Philosophy</category>
                    <category>Faith</category>
                    <category>Quote</category>
                    <category>Level 3</category>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.category, .quote, "Should pick 'Quote' from the combined category text")
    }
    
    // MARK: - HTML Cleaning
    
    func testParseHTMLContent() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <item>
                    <title>HTML Test</title>
                    <description>&lt;p&gt;This is &lt;b&gt;bold&lt;/b&gt; text.&lt;/p&gt;</description>
                    <link>https://wisdombook.life/test</link>
                    <pubDate>Mon, 10 Feb 2026 09:00:00 EST</pubDate>
                    <category>Passage</category>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        XCTAssertEqual(entries.count, 1)
        XCTAssertFalse(entries.first?.content.contains("<p>") ?? true, "HTML <p> tags should be stripped")
        XCTAssertFalse(entries.first?.content.contains("<b>") ?? true, "HTML <b> tags should be stripped")
        XCTAssertTrue(entries.first?.content.contains("bold") ?? false, "Text content should be preserved")
    }
    
    func testHTMLEntityDecoding() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <item>
                    <title>Entity Test</title>
                    <description>&lt;p&gt;God&amp;apos;s &amp;amp; man&amp;apos;s ways&lt;/p&gt;</description>
                    <link>https://wisdombook.life/test</link>
                    <pubDate>Mon, 10 Feb 2026 09:00:00 EST</pubDate>
                    <category>Thought</category>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        let content = entries.first?.content ?? ""
        XCTAssertFalse(content.contains("&amp;"), "HTML entities should be decoded")
    }
    
    // MARK: - Real-World Thought Format
    
    func testParseRealThoughtEntry() throws {
        // Matches the actual format from wisdombook.life/feed/thoughts.xml
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <item>
                    <title>THE HOLY SPIRIT</title>
                    <description>&lt;p&gt;&lt;strong&gt;Level 1 Thought&lt;/strong&gt;&lt;/p&gt;&lt;p&gt;The Holy Spirit is God, and all men must be filled with Him.&lt;/p&gt;&lt;p&gt;&lt;em&gt;From: Topic: Topic: The GODHEAD&lt;/em&gt;&lt;/p&gt;</description>
                    <link>https://wisdombook.life/thoughts/the-holy-spirit</link>
                    <pubDate>Thu, 13 Feb 2026 14:00:00 GMT</pubDate>
                    <category>Wisdom</category>
                    <category>Philosophy</category>
                    <category>Thought</category>
                    <category>Level 1</category>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        XCTAssertEqual(entries.count, 1)
        let entry = entries[0]
        XCTAssertEqual(entry.title, "THE HOLY SPIRIT")
        XCTAssertEqual(entry.category, .thought)
        // Content should have "Level 1 Thought" and "From: Topic:" metadata stripped
        XCTAssertFalse(entry.content.contains("Level 1"), "Level metadata should be stripped")
        XCTAssertFalse(entry.content.contains("From: Topic:"), "From: Topic: line should be stripped")
        XCTAssertTrue(entry.content.contains("The Holy Spirit is God"), "Core content must be preserved")
    }
    
    func testParseThoughtWithScriptureInContent() throws {
        // Some thoughts embed scripture references inline
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <item>
                    <title>YISRAEL</title>
                    <description>&lt;p&gt;&lt;strong&gt;Level 4 Thought&lt;/strong&gt;&lt;/p&gt;&lt;p&gt;Two wrongs don't make a right…until Israel repents. Daniel 9:26&lt;/p&gt;&lt;p&gt;&lt;em&gt;From: Topic: Topic: Chronology&lt;/em&gt;&lt;/p&gt;</description>
                    <link>https://wisdombook.life/thoughts/yisrael</link>
                    <pubDate>Thu, 13 Feb 2026 14:00:00 GMT</pubDate>
                    <category>Thought</category>
                    <category>Level 4</category>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        let entry = entries[0]
        XCTAssertEqual(entry.category, .thought)
        // Scripture reference in content should be extracted
        if let ref = entry.reference {
            XCTAssertTrue(ref.contains("Daniel"), "Reference should contain 'Daniel', got: \(ref)")
        }
    }
    
    // MARK: - Real-World Quote Format
    
    func testParseRealQuoteWithBookName() throws {
        // Matches the actual format from wisdombook.life/feed/quotes.xml
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <item>
                    <title>WHERE IS GOD?</title>
                    <description>&lt;p&gt;&lt;strong&gt;Level 4 Quote&lt;/strong&gt;&lt;/p&gt;&lt;p&gt;GOD is the eight-billion-ton Leviathan in the room...yet you cannot see Him.&lt;/p&gt;&lt;p&gt;&lt;em&gt;The Narrow Way&lt;/em&gt;&lt;/p&gt;&lt;p&gt;&lt;em&gt;From: Topic: Topic: Predestination&lt;/em&gt;&lt;/p&gt;</description>
                    <link>https://wisdombook.life/quotes/where-is-god</link>
                    <pubDate>Thu, 13 Feb 2026 14:00:00 GMT</pubDate>
                    <category>Wisdom</category>
                    <category>Quote</category>
                    <category>Level 4</category>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        XCTAssertEqual(entries.count, 1)
        let entry = entries[0]
        XCTAssertEqual(entry.title, "WHERE IS GOD?")
        XCTAssertEqual(entry.category, .quote)
        // Book name should be extracted as reference
        XCTAssertEqual(entry.reference, "The Narrow Way", "Book name from <em> tag should be the reference")
        // Content should be cleaned of metadata
        XCTAssertFalse(entry.content.contains("Level 4"), "Level metadata should be stripped")
        XCTAssertFalse(entry.content.contains("From: Topic:"), "From: Topic: line should be stripped")
        XCTAssertTrue(entry.content.contains("Leviathan"), "Core quote content must be preserved")
        // With wisdom:source as canonical, book names remain in content
        XCTAssertTrue(entry.content.contains("The Narrow Way"), "Book name from <em> tag remains in content")
    }
    
    func testParseQuoteWithLongBookName() throws {
        // Book names can be long: "IMMMUNITY to the Lake of Fire: A No-Nonsense Guide"
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <item>
                    <title>WEALTH AND FAITH</title>
                    <description>&lt;p&gt;&lt;strong&gt;Level 3 Quote&lt;/strong&gt;&lt;/p&gt;&lt;p&gt;Wealth and Faith are mutually exclusive.&lt;/p&gt;&lt;p&gt;&lt;em&gt;IMMMUNITY to the Lake of Fire: A No-Nonsense Guide&lt;/em&gt;&lt;/p&gt;&lt;p&gt;&lt;em&gt;From: Topic: Topic: Abundance&lt;/em&gt;&lt;/p&gt;</description>
                    <link>https://wisdombook.life/quotes/wealth-and-faith</link>
                    <pubDate>Thu, 13 Feb 2026 14:00:00 GMT</pubDate>
                    <category>Quote</category>
                    <category>Level 3</category>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        let entry = entries[0]
        XCTAssertEqual(entry.reference, "IMMMUNITY to the Lake of Fire: A No-Nonsense Guide")
        XCTAssertTrue(entry.content.contains("Wealth and Faith"), "Core content must be preserved")
    }
    
    func testParseQuoteWithMarkdownLinks() throws {
        // Some quotes contain markdown-style links: [text](url)
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <item>
                    <title>UNGODLY</title>
                    <description>&lt;p&gt;&lt;strong&gt;Level 4 Quote&lt;/strong&gt;&lt;/p&gt;&lt;p&gt;This is what the Bible means by 'ungodly' ([Psalms 1:4,5](https://www.biblegateway.com/passage/?search=Psalms+1%3A4-5&amp;amp;version=ESV)).&lt;/p&gt;&lt;p&gt;&lt;em&gt;The Narrow Way&lt;/em&gt;&lt;/p&gt;&lt;p&gt;&lt;em&gt;From: Topic: Topic: Malevolence&lt;/em&gt;&lt;/p&gt;</description>
                    <link>https://wisdombook.life/quotes/ungodly</link>
                    <pubDate>Thu, 13 Feb 2026 14:00:00 GMT</pubDate>
                    <category>Quote</category>
                    <category>Level 4</category>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        let entry = entries[0]
        XCTAssertEqual(entry.reference, "The Narrow Way")
        XCTAssertTrue(entry.content.contains("ungodly"), "Core content must be preserved")
    }
    
    // MARK: - Real-World Passage Format
    
    func testParseRealPassageWithBibleRef() throws {
        // Matches the actual format from wisdombook.life/feed/passages.xml (Feb 2026+)
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
            <channel xmlns:wisdom="https://wisdombook.life/ns/1.0">
                <item>
                    <title>SCORNERS</title>
                    <description>&lt;p&gt;&lt;strong&gt;Level 4 Passage&lt;/strong&gt;&lt;/p&gt;&lt;p&gt;Toward the scorners He [The LORD] is scornful,&lt;/p&gt;&lt;p&gt;&lt;em&gt;From: Topic: Topic: Malevolence&lt;/em&gt;&lt;/p&gt;</description>
                    <link>https://wisdombook.life/passages/scorners</link>
                    <pubDate>Thu, 13 Feb 2026 14:00:00 GMT</pubDate>
                    <category>Wisdom</category>
                    <category>Passage</category>
                    <category>Scripture</category>
                    <category>Level 4</category>
                    <category>Proverbs</category>
                    <wisdom:source>Proverbs 3:34</wisdom:source>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        XCTAssertEqual(entries.count, 1)
        let entry = entries[0]
        XCTAssertEqual(entry.title, "SCORNERS")
        XCTAssertEqual(entry.category, .passage)
        // Reference should come from <wisdom:source>
        XCTAssertEqual(entry.reference, "Proverbs 3:34", "Reference should come from wisdom:source element")
        // Content should be cleaned
        XCTAssertTrue(entry.content.contains("scorners"), "Core passage text must be preserved")
        XCTAssertFalse(entry.content.contains("From: Topic:"), "From: Topic: line should be stripped")
    }
    
    func testParsePassageWithVerseRange() throws {
        // Passages may have verse ranges like Proverbs 2:10-12
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
            <channel xmlns:wisdom="https://wisdombook.life/ns/1.0">
                <item>
                    <title>PROTECTION FROM EVIL</title>
                    <description>&lt;p&gt;&lt;strong&gt;Level 4 Passage&lt;/strong&gt;&lt;/p&gt;&lt;p&gt;For wisdom will enter your heart.&lt;/p&gt;&lt;p&gt;&lt;em&gt;From: Topic: Topic: Malevolence&lt;/em&gt;&lt;/p&gt;</description>
                    <link>https://wisdombook.life/passages/protection-from-evil</link>
                    <pubDate>Thu, 13 Feb 2026 14:00:00 GMT</pubDate>
                    <category>Passage</category>
                    <category>Level 4</category>
                    <wisdom:source>Proverbs 2:10-12</wisdom:source>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        let entry = entries[0]
        XCTAssertEqual(entry.title, "PROTECTION FROM EVIL")
        XCTAssertEqual(entry.reference, "Proverbs 2:10-12", "Reference with verse range from wisdom:source")
    }
    
    func testParsePassageWithCommaVerses() throws {
        // Some passages use comma-separated verses: Proverbs 3:7,8
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
            <channel xmlns:wisdom="https://wisdombook.life/ns/1.0">
                <item>
                    <title>PRIDE-AS-EVIL</title>
                    <description>&lt;p&gt;&lt;strong&gt;Level 4 Passage&lt;/strong&gt;&lt;/p&gt;&lt;p&gt;Do not be wise in your own eyes; Fear the LORD.&lt;/p&gt;&lt;p&gt;&lt;em&gt;From: Topic: Topic: Lowliness of Heart&lt;/em&gt;&lt;/p&gt;</description>
                    <link>https://wisdombook.life/passages/pride-as-evil</link>
                    <pubDate>Thu, 13 Feb 2026 14:00:00 GMT</pubDate>
                    <category>Passage</category>
                    <wisdom:source>Proverbs 3:7,8</wisdom:source>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        let entry = entries[0]
        XCTAssertEqual(entry.title, "PRIDE-AS-EVIL")
        XCTAssertEqual(entry.reference, "Proverbs 3:7,8", "Reference with comma-separated verses from wisdom:source")
    }
    
    // MARK: - Content Cleaning

    func testMetadataLevelLineStripping() throws {
        // The <strong>Level N Type</strong> line should be stripped from content
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <item>
                    <title>NO WATER</title>
                    <description>&lt;p&gt;&lt;strong&gt;Level 4 Thought&lt;/strong&gt;&lt;/p&gt;&lt;p&gt;How can a fish say there is no water? Yet men say there is no God!&lt;/p&gt;&lt;p&gt;&lt;em&gt;From: Topic: Topic: The Science of Ideology&lt;/em&gt;&lt;/p&gt;</description>
                    <link>https://wisdombook.life/thoughts/no-water</link>
                    <pubDate>Thu, 13 Feb 2026 14:00:00 GMT</pubDate>
                    <category>Thought</category>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        let content = entries[0].content
        XCTAssertFalse(content.contains("Level 4"), "Level metadata should NOT appear in content")
        XCTAssertFalse(content.contains("Level 4 Thought"), "Full level line should be stripped")
        XCTAssertFalse(content.contains("From: Topic:"), "From: Topic: should be stripped")
        XCTAssertFalse(content.contains("Science of Ideology"), "Topic name should be stripped with From: line")
        XCTAssertTrue(content.contains("How can a fish"), "Core content must be preserved")
    }
    
    func testFromTopicTopicPattern() throws {
        // Feed uses doubled "Topic:" pattern: "From: Topic: Topic: X"
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <item>
                    <title>TEST</title>
                    <description>&lt;p&gt;Core content here.&lt;/p&gt;&lt;p&gt;&lt;em&gt;From: Topic: Topic: Earth's Natural Processes&lt;/em&gt;&lt;/p&gt;</description>
                    <link>https://wisdombook.life/thoughts/test</link>
                    <pubDate>Thu, 13 Feb 2026 14:00:00 GMT</pubDate>
                    <category>Thought</category>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        let content = entries[0].content
        XCTAssertFalse(content.contains("From:"), "From: line should be fully stripped")
        XCTAssertFalse(content.contains("Earth's Natural Processes"), "Topic text should be stripped")
        XCTAssertTrue(content.contains("Core content here"), "Core content must be preserved")
    }
    
    func testScriptureReferenceInContent() throws {
        // Simple scripture reference extraction from plain content
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <item>
                    <title>Scripture</title>
                    <description>Trust in the Lord with all your heart. Proverbs 3:5</description>
                    <link>https://wisdombook.life/test</link>
                    <pubDate>Mon, 10 Feb 2026 09:00:00 GMT</pubDate>
                    <category>Passage</category>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        XCTAssertEqual(entries.count, 1)
        if let ref = entries.first?.reference {
            XCTAssertTrue(ref.contains("Proverbs"), "Reference should contain 'Proverbs', got: \(ref)")
        }
    }
    
    // MARK: - Wisdom.xml Mixed Feed
    
    func testParseMixedWisdomFeed() throws {
        // wisdom.xml contains thoughts, quotes, and passages together
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
            <channel xmlns:wisdom="https://wisdombook.life/ns/1.0">
                <title>Wisdom Book - All Wisdom</title>
                <item>
                    <title>Ecological Care</title>
                    <description>&lt;p&gt;&lt;strong&gt;Level 6 Thought&lt;/strong&gt;&lt;/p&gt;&lt;p&gt;(Weeping over BP Oil Spill).&lt;/p&gt;&lt;p&gt;&lt;em&gt;From: Topic: Topic: Earth's Natural Processes&lt;/em&gt;&lt;/p&gt;</description>
                    <link>https://wisdombook.life/thoughts/ecological-care</link>
                    <pubDate>Thu, 13 Feb 2026 14:00:00 GMT</pubDate>
                    <category>Thought</category>
                    <category>Level 6</category>
                </item>
                <item>
                    <title>WRONG REASON</title>
                    <description>&lt;p&gt;&lt;strong&gt;Level 3 Quote&lt;/strong&gt;&lt;/p&gt;&lt;p&gt;IT IS POSSIBLE TO PERFORM A GOOD DEED FOR THE WRONG REASON.&lt;/p&gt;&lt;p&gt;&lt;em&gt;The Basics and More: A Year's Sermons&lt;/em&gt;&lt;/p&gt;&lt;p&gt;&lt;em&gt;From: Topic: Topic: Spiritual Disposition&lt;/em&gt;&lt;/p&gt;</description>
                    <link>https://wisdombook.life/quotes/wrong-reason</link>
                    <pubDate>Thu, 13 Feb 2026 14:00:00 GMT</pubDate>
                    <category>Quote</category>
                    <category>Level 3</category>
                </item>
                <item>
                    <title>OBLIGATION</title>
                    <description>&lt;p&gt;&lt;strong&gt;Level 3 Passage&lt;/strong&gt;&lt;/p&gt;&lt;p&gt;Do not withhold good from those to whom it is due,&lt;/p&gt;&lt;p&gt;&lt;em&gt;From: Topic: Topic: Matters of the Conscience&lt;/em&gt;&lt;/p&gt;</description>
                    <link>https://wisdombook.life/passages/obligation</link>
                    <pubDate>Thu, 13 Feb 2026 14:00:00 GMT</pubDate>
                    <category>Passage</category>
                    <category>Level 3</category>
                    <wisdom:source>Proverbs 3:27,28</wisdom:source>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        XCTAssertEqual(entries.count, 3)
        
        // Thought
        XCTAssertEqual(entries[0].category, .thought)
        XCTAssertEqual(entries[0].title, "Ecological Care")
        XCTAssertTrue(entries[0].content.contains("Weeping"), "Thought content must be preserved")
        XCTAssertFalse(entries[0].content.contains("Level 6"), "Level line should be stripped")
        
        // Quote with book name
        XCTAssertEqual(entries[1].category, .quote)
        XCTAssertEqual(entries[1].reference, "The Basics and More: A Year's Sermons")
        XCTAssertTrue(entries[1].content.contains("GOOD DEED"), "Quote content must be preserved")
        
        // Passage with Bible ref
        XCTAssertEqual(entries[2].category, .passage)
        XCTAssertEqual(entries[2].title, "OBLIGATION")
        XCTAssertEqual(entries[2].reference, "Proverbs 3:27,28", "Reference from wisdom:source")
        XCTAssertNotNil(entries[2].reference, "Passage should have Bible reference")
        if let ref = entries[2].reference {
            XCTAssertTrue(ref.contains("Proverbs") && ref.contains("3:27"),
                          "Reference should be 'Proverbs 3:27,28', got: \(ref)")
        }
    }
    
    // MARK: - Edge Cases
    
    func testThoughtWithNoFromTopicLine() throws {
        // Some entries may not have the From: Topic: metadata
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <item>
                    <title>SIMPLE</title>
                    <description>&lt;p&gt;A simple thought with no metadata.&lt;/p&gt;</description>
                    <link>https://wisdombook.life/thoughts/simple</link>
                    <pubDate>Thu, 13 Feb 2026 14:00:00 GMT</pubDate>
                    <category>Thought</category>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].content, "A simple thought with no metadata.")
        XCTAssertNil(entries[0].reference, "Thought without scripture should have nil reference")
    }
    
    func testQuoteWithoutBookName() throws {
        // A quote that only has From: Topic but no book <em> tag
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <item>
                    <title>NO BOOK QUOTE</title>
                    <description>&lt;p&gt;&lt;strong&gt;Level 3 Quote&lt;/strong&gt;&lt;/p&gt;&lt;p&gt;A quote without a book name.&lt;/p&gt;&lt;p&gt;&lt;em&gt;From: Topic: Topic: General&lt;/em&gt;&lt;/p&gt;</description>
                    <link>https://wisdombook.life/quotes/no-book</link>
                    <pubDate>Thu, 13 Feb 2026 14:00:00 GMT</pubDate>
                    <category>Quote</category>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        let entry = entries[0]
        XCTAssertEqual(entry.category, .quote)
        // Without a book <em>, reference should be nil (From: Topic: is excluded by negative lookahead)
        XCTAssertNil(entry.reference, "Quote without book name should have nil reference")
        XCTAssertTrue(entry.content.contains("without a book name"), "Content should be preserved")
    }
    
    func testBreakTagPreservation() throws {
        // Some entries use <br/> tags for line breaks
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <item>
                    <title>LINE BREAKS</title>
                    <description>&lt;p&gt;Line one.&lt;/br&gt;Line two.&lt;/p&gt;</description>
                    <link>https://wisdombook.life/thoughts/breaks</link>
                    <pubDate>Thu, 13 Feb 2026 14:00:00 GMT</pubDate>
                    <category>Thought</category>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        let content = entries[0].content
        XCTAssertFalse(content.contains("</br>"), "Break tags should be stripped")
        XCTAssertTrue(content.contains("Line one"), "Content before break must be preserved")
        XCTAssertTrue(content.contains("Line two"), "Content after break must be preserved")
    }
    
    // MARK: - wisdom:source Namespace Tests
    
    func testParseWisdomSourceForQuote() throws {
        // Quotes now include <wisdom:source> with the book name
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
            <channel xmlns:wisdom="https://wisdombook.life/ns/1.0">
                <item>
                    <title>THE SALVATION</title>
                    <description>&lt;p&gt;&lt;strong&gt;Level 2 Quote&lt;/strong&gt;&lt;/p&gt;&lt;p&gt;THERE IS NO SALVATION APART FROM JESUS.&lt;/p&gt;&lt;p&gt;&lt;em&gt;The Narrow Way&lt;/em&gt;&lt;/p&gt;&lt;p&gt;&lt;em&gt;From: Topic: Topic: The Good News&lt;/em&gt;&lt;/p&gt;</description>
                    <link>https://wisdombook.life/quotes/the-salvation</link>
                    <pubDate>Thu, 13 Feb 2026 14:00:00 GMT</pubDate>
                    <category>Quote</category>
                    <category>Level 2</category>
                    <wisdom:source>The Narrow Way</wisdom:source>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        let entry = entries[0]
        XCTAssertEqual(entry.category, .quote)
        XCTAssertEqual(entry.reference, "The Narrow Way", "wisdom:source should provide the book name")
        XCTAssertTrue(entry.content.contains("SALVATION"), "Core content must be preserved")
    }
    
    func testWisdomSourceTakesPriorityOverFallback() throws {
        // When both wisdom:source and <em> book name exist, wisdom:source wins
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel xmlns:wisdom="https://wisdombook.life/ns/1.0">
                <item>
                    <title>PRIORITY TEST</title>
                    <description>&lt;p&gt;Content text.&lt;/p&gt;&lt;p&gt;&lt;em&gt;Fallback Book Name&lt;/em&gt;&lt;/p&gt;</description>
                    <link>https://wisdombook.life/quotes/priority</link>
                    <pubDate>Thu, 13 Feb 2026 14:00:00 GMT</pubDate>
                    <category>Quote</category>
                    <wisdom:source>Canonical Source</wisdom:source>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        XCTAssertEqual(entries[0].reference, "Canonical Source",
                       "wisdom:source should take priority over <em> fallback")
    }
    
    func testFallbackStillWorksWithoutWisdomSource() throws {
        // Feeds without wisdom:source should still extract references via fallbacks
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <item>
                    <title>LEGACY - Proverbs 1:7</title>
                    <description>&lt;p&gt;The fear of the LORD is the beginning of knowledge.&lt;/p&gt;</description>
                    <link>https://wisdombook.life/passages/legacy</link>
                    <pubDate>Thu, 13 Feb 2026 14:00:00 GMT</pubDate>
                    <category>Passage</category>
                </item>
            </channel>
        </rss>
        """
        
        let data = xml.data(using: .utf8)!
        let parser = RSSXMLParser(data: data)
        let entries = try parser.parse()
        
        XCTAssertEqual(entries[0].title, "LEGACY", "Title should strip legacy suffix")
        XCTAssertEqual(entries[0].reference, "Proverbs 1:7",
                       "Legacy title-suffix extraction should still work as fallback")
    }
}

// MARK: - Platform Tier Tests

final class PlatformTierTests: XCTestCase {
    
    func testAPIAvailableTierCount() throws {
        XCTAssertEqual(PlatformTier.apiAvailable.count, 5)
    }
    
    func testTheRestTierCount() throws {
        XCTAssertEqual(PlatformTier.theRest.count, 3)
    }
    
    func testAPIAvailablePlatformNames() throws {
        let names = PlatformTier.apiAvailable.map { $0.name }
        XCTAssertTrue(names.contains("YouTube"))
        XCTAssertTrue(names.contains("TikTok"))
        XCTAssertTrue(names.contains("Threads"))
        XCTAssertTrue(names.contains("Bluesky"))
        XCTAssertTrue(names.contains("Reddit"))
    }
    
    func testTheRestPlatformNames() throws {
        let names = PlatformTier.theRest.map { $0.name }
        XCTAssertTrue(names.contains("Substack"))
        XCTAssertTrue(names.contains("Medium"))
        XCTAssertTrue(names.contains("Tumblr"))
    }
    
    func testTierItemsHaveIcons() throws {
        for item in PlatformTier.apiAvailable {
            XCTAssertFalse(item.icon.isEmpty, "\(item.name) should have an icon")
        }
        for item in PlatformTier.theRest {
            XCTAssertFalse(item.icon.isEmpty, "\(item.name) should have an icon")
        }
    }
    
    func testTierItemsHaveNotes() throws {
        for item in PlatformTier.apiAvailable {
            XCTAssertFalse(item.note.isEmpty, "\(item.name) should have a note")
        }
        for item in PlatformTier.theRest {
            XCTAssertFalse(item.note.isEmpty, "\(item.name) should have a note")
        }
    }
}

// MARK: - PostResult & PostStatus Tests

final class PostResultTests: XCTestCase {
    
    func testPostStatusRawValues() throws {
        XCTAssertEqual(PostStatus.pending.rawValue, "pending")
        XCTAssertEqual(PostStatus.posted.rawValue, "posted")
        XCTAssertEqual(PostStatus.failed.rawValue, "failed")
    }
    
    func testPostStatusFromRawValue() throws {
        XCTAssertEqual(PostStatus(rawValue: "pending"), .pending)
        XCTAssertEqual(PostStatus(rawValue: "posted"), .posted)
        XCTAssertEqual(PostStatus(rawValue: "failed"), .failed)
        XCTAssertNil(PostStatus(rawValue: "unknown"))
    }
    
    func testSuccessfulPostResult() throws {
        let result = PostResult(
            success: true,
            postID: "12345",
            postURL: URL(string: "https://x.com/i/status/12345"),
            error: nil
        )
        
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.postID, "12345")
        XCTAssertNotNil(result.postURL)
        XCTAssertNil(result.error)
    }
    
    func testFailedPostResult() throws {
        let error = PlatformError.notConfigured
        let result = PostResult(
            success: false,
            postID: nil,
            postURL: nil,
            error: error
        )
        
        XCTAssertFalse(result.success)
        XCTAssertNil(result.postID)
        XCTAssertNil(result.postURL)
        XCTAssertNotNil(result.error)
    }
}

// MARK: - Error Description Tests

final class ErrorDescriptionTests: XCTestCase {
    
    func testContentErrorDescriptions() throws {
        XCTAssertNotNil(ContentError.invalidFeedURL.errorDescription)
        XCTAssertTrue(ContentError.invalidFeedURL.errorDescription!.contains("RSS"))
        
        let innerError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "test error"])
        XCTAssertNotNil(ContentError.fetchFailed(innerError).errorDescription)
        XCTAssertTrue(ContentError.fetchFailed(innerError).errorDescription!.contains("fetch"))
        
        XCTAssertNotNil(ContentError.cacheFailed.errorDescription)
    }
    
    func testKeychainErrorDescriptions() throws {
        XCTAssertNotNil(KeychainError.notFound.errorDescription)
        XCTAssertTrue(KeychainError.notFound.errorDescription!.contains("not found"))
        
        XCTAssertNotNil(KeychainError.saveFailed(0).errorDescription)
        XCTAssertNotNil(KeychainError.retrieveFailed(0).errorDescription)
        XCTAssertNotNil(KeychainError.deleteFailed(0).errorDescription)
    }
    
    func testSchedulerErrorDescriptions() throws {
        XCTAssertNotNil(SchedulerError.plistNotFound.errorDescription)
        XCTAssertTrue(SchedulerError.plistNotFound.errorDescription!.contains("plist"))
        
        XCTAssertNotNil(SchedulerError.launchctlFailed("load").errorDescription)
        XCTAssertTrue(SchedulerError.launchctlFailed("load").errorDescription!.contains("load"))
    }
}

// MARK: - Logging System Tests

final class LoggingSystemTests: XCTestCase {
    
    func testSubsystemIdentifier() throws {
        XCTAssertEqual(Log.subsystem, "com.wisdombook.SocialMarketer")
    }
    
    func testAllLogCategoriesExist() throws {
        // Verify all loggers can be accessed (they are static properties)
        _ = Log.app
        _ = Log.scheduler
        _ = Log.persistence
        _ = Log.twitter
        _ = Log.instagram
        _ = Log.linkedin
        _ = Log.facebook
        _ = Log.pinterest
        _ = Log.oauth
        _ = Log.keychain
        _ = Log.content
        _ = Log.rss
        _ = Log.graphic
        _ = Log.indexing
    }
    
    func testDiagnosticCommandContainsSubsystem() throws {
        XCTAssertTrue(Log.diagnosticCommand.contains(Log.subsystem))
    }
    
    func testStreamCommandContainsSubsystem() throws {
        XCTAssertTrue(Log.streamCommand.contains(Log.subsystem))
    }
}

// MARK: - OAuth1Signer Tests

final class OAuth1SignerTests: XCTestCase {
    
    func testSignerCreation() throws {
        let signer = OAuth1Signer(
            consumerKey: "test-key",
            consumerSecret: "test-secret",
            accessToken: "test-token",
            accessTokenSecret: "test-token-secret"
        )
        
        XCTAssertEqual(signer.consumerKey, "test-key")
        XCTAssertEqual(signer.consumerSecret, "test-secret")
        XCTAssertEqual(signer.accessToken, "test-token")
        XCTAssertEqual(signer.accessTokenSecret, "test-token-secret")
    }
    
    func testSignedRequestHasAuthorizationHeader() throws {
        let signer = OAuth1Signer(
            consumerKey: "test-key",
            consumerSecret: "test-secret",
            accessToken: "test-token",
            accessTokenSecret: "test-token-secret"
        )
        
        let url = URL(string: "https://api.twitter.com/2/tweets")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let signedRequest = signer.sign(request)
        
        let authHeader = signedRequest.value(forHTTPHeaderField: "Authorization")
        XCTAssertNotNil(authHeader, "Signed request must have Authorization header")
        XCTAssertTrue(authHeader!.hasPrefix("OAuth "), "Auth header must start with 'OAuth '")
        XCTAssertTrue(authHeader!.contains("oauth_consumer_key"), "Auth header must contain consumer key")
        XCTAssertTrue(authHeader!.contains("oauth_signature"), "Auth header must contain signature")
        XCTAssertTrue(authHeader!.contains("oauth_nonce"), "Auth header must contain nonce")
        XCTAssertTrue(authHeader!.contains("oauth_timestamp"), "Auth header must contain timestamp")
    }
    
    func testSignedRequestPreservesOriginalHeaders() throws {
        let signer = OAuth1Signer(
            consumerKey: "k", consumerSecret: "s",
            accessToken: "t", accessTokenSecret: "ts"
        )
        
        let url = URL(string: "https://api.twitter.com/2/tweets")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let signedRequest = signer.sign(request)
        
        XCTAssertEqual(signedRequest.httpMethod, "POST")
        XCTAssertEqual(signedRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }
    
    func testDifferentRequestsProduceDifferentSignatures() throws {
        let signer = OAuth1Signer(
            consumerKey: "k", consumerSecret: "s",
            accessToken: "t", accessTokenSecret: "ts"
        )
        
        let url1 = URL(string: "https://api.twitter.com/2/tweets")!
        let url2 = URL(string: "https://api.twitter.com/2/users/me")!
        
        var request1 = URLRequest(url: url1)
        request1.httpMethod = "POST"
        
        var request2 = URLRequest(url: url2)
        request2.httpMethod = "GET"
        
        let signed1 = signer.sign(request1)
        let signed2 = signer.sign(request2)
        
        XCTAssertNotEqual(
            signed1.value(forHTTPHeaderField: "Authorization"),
            signed2.value(forHTTPHeaderField: "Authorization"),
            "Different requests should produce different auth headers"
        )
    }
}

// MARK: - RSS Feed URLs Tests

final class RSSFeedURLTests: XCTestCase {
    
    func testAllFeedURLsExist() throws {
        XCTAssertNotNil(RSSParser.feedURLs["daily"])
        XCTAssertNotNil(RSSParser.feedURLs["wisdom"])
        XCTAssertNotNil(RSSParser.feedURLs["thoughts"])
        XCTAssertNotNil(RSSParser.feedURLs["quotes"])
        XCTAssertNotNil(RSSParser.feedURLs["passages"])
    }
    
    func testFeedURLsPointToWisdomBook() throws {
        for (_, url) in RSSParser.feedURLs {
            XCTAssertTrue(
                url.absoluteString.contains("wisdombook.life"),
                "Feed URL should point to wisdombook.life: \(url)"
            )
        }
    }
    
    func testFeedURLsAreXML() throws {
        for (_, url) in RSSParser.feedURLs {
            XCTAssertTrue(
                url.pathExtension == "xml",
                "Feed URL should have .xml extension: \(url)"
            )
        }
    }
    
    func testFeedCount() throws {
        XCTAssertEqual(RSSParser.feedURLs.count, 5)
    }
}

// MARK: - Platform Credentials Tests

final class PlatformCredentialsTests: XCTestCase {
    
    func testTwitterCredentialsCodable() throws {
        let creds = PlatformCredentials.TwitterCredentials(
            accessToken: "token",
            refreshToken: "refresh-token"
        )
        
        let data = try JSONEncoder().encode(creds)
        let decoded = try JSONDecoder().decode(PlatformCredentials.TwitterCredentials.self, from: data)
        
        XCTAssertEqual(decoded.accessToken, creds.accessToken)
        XCTAssertEqual(decoded.refreshToken, creds.refreshToken)
    }
    
    func testTwitterCredentialsWithNilRefreshToken() throws {
        let creds = PlatformCredentials.TwitterCredentials(
            accessToken: "token",
            refreshToken: nil
        )
        
        let data = try JSONEncoder().encode(creds)
        let decoded = try JSONDecoder().decode(PlatformCredentials.TwitterCredentials.self, from: data)
        
        XCTAssertEqual(decoded.accessToken, "token")
        XCTAssertNil(decoded.refreshToken)
    }
    
    func testInstagramCredentialsCodable() throws {
        let creds = PlatformCredentials.InstagramCredentials(
            accessToken: "token123",
            businessAccountID: "12345"
        )
        
        let data = try JSONEncoder().encode(creds)
        let decoded = try JSONDecoder().decode(PlatformCredentials.InstagramCredentials.self, from: data)
        
        XCTAssertEqual(decoded.accessToken, creds.accessToken)
        XCTAssertEqual(decoded.businessAccountID, creds.businessAccountID)
    }
    
    func testLinkedInCredentialsCodable() throws {
        let creds = PlatformCredentials.LinkedInCredentials(
            accessToken: "li-token",
            personURN: "urn:li:person:12345"
        )
        
        let data = try JSONEncoder().encode(creds)
        let decoded = try JSONDecoder().decode(PlatformCredentials.LinkedInCredentials.self, from: data)
        
        XCTAssertEqual(decoded.accessToken, creds.accessToken)
        XCTAssertEqual(decoded.personURN, creds.personURN)
    }
    
    func testFacebookCredentialsCodable() throws {
        let creds = PlatformCredentials.FacebookCredentials(
            accessToken: "fb-token",
            pageID: "page123",
            pageAccessToken: "page-token"
        )
        
        let data = try JSONEncoder().encode(creds)
        let decoded = try JSONDecoder().decode(PlatformCredentials.FacebookCredentials.self, from: data)
        
        XCTAssertEqual(decoded.accessToken, creds.accessToken)
        XCTAssertEqual(decoded.pageID, creds.pageID)
        XCTAssertEqual(decoded.pageAccessToken, creds.pageAccessToken)
    }
    
    func testPinterestCredentialsCodable() throws {
        let creds = PlatformCredentials.PinterestCredentials(
            accessToken: "pin-token",
            boardID: "board123"
        )
        
        let data = try JSONEncoder().encode(creds)
        let decoded = try JSONDecoder().decode(PlatformCredentials.PinterestCredentials.self, from: data)
        
        XCTAssertEqual(decoded.accessToken, creds.accessToken)
        XCTAssertEqual(decoded.boardID, creds.boardID)
    }
    
    func testPlatformCredentialsAllNil() throws {
        let creds = PlatformCredentials()
        
        XCTAssertNil(creds.twitter)
        XCTAssertNil(creds.instagram)
        XCTAssertNil(creds.linkedin)
        XCTAssertNil(creds.facebook)
        XCTAssertNil(creds.pinterest)
    }
}

// MARK: - ErrorLogService Tests

@MainActor
final class ErrorLogServiceTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        ErrorLog.shared.clear()
    }
    
    func testLogAddsEntry() throws {
        ErrorLog.shared.log(category: "Test", message: "Something broke")
        
        XCTAssertEqual(ErrorLog.shared.entries.count, 1)
        XCTAssertEqual(ErrorLog.shared.entries.first?.category, "Test")
        XCTAssertEqual(ErrorLog.shared.entries.first?.message, "Something broke")
    }
    
    func testLogWithDetail() throws {
        ErrorLog.shared.log(category: "RSS", message: "Feed failed", detail: "404 Not Found")
        
        XCTAssertEqual(ErrorLog.shared.entries.first?.detail, "404 Not Found")
    }
    
    func testLogWithoutDetail() throws {
        ErrorLog.shared.log(category: "App", message: "Minor issue")
        
        XCTAssertNil(ErrorLog.shared.entries.first?.detail)
    }
    
    func testNewestFirst() throws {
        ErrorLog.shared.log(category: "A", message: "First")
        ErrorLog.shared.log(category: "B", message: "Second")
        
        XCTAssertEqual(ErrorLog.shared.entries.first?.message, "Second")
        XCTAssertEqual(ErrorLog.shared.entries.last?.message, "First")
    }
    
    func testCapsAt100() throws {
        for i in 0..<120 {
            ErrorLog.shared.log(category: "Test", message: "Error \(i)")
        }
        
        XCTAssertEqual(ErrorLog.shared.entries.count, ErrorLog.maxEntries)
        XCTAssertEqual(ErrorLog.shared.entries.first?.message, "Error 119", "Newest entry should be first")
    }
    
    func testClear() throws {
        ErrorLog.shared.log(category: "Test", message: "Error 1")
        ErrorLog.shared.log(category: "Test", message: "Error 2")
        
        ErrorLog.shared.clear()
        
        XCTAssertTrue(ErrorLog.shared.entries.isEmpty)
        XCTAssertEqual(ErrorLog.shared.count, 0)
    }
    
    func testCountProperty() throws {
        XCTAssertEqual(ErrorLog.shared.count, 0)
        
        ErrorLog.shared.log(category: "A", message: "One")
        ErrorLog.shared.log(category: "B", message: "Two")
        
        XCTAssertEqual(ErrorLog.shared.count, 2)
    }
    
    func testEntryHasUniqueIDs() throws {
        ErrorLog.shared.log(category: "A", message: "One")
        ErrorLog.shared.log(category: "A", message: "Two")
        
        let ids = ErrorLog.shared.entries.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count, "All entries should have unique IDs")
    }
    
    func testEntryHasTimestamp() throws {
        let before = Date()
        ErrorLog.shared.log(category: "Test", message: "Timed")
        let after = Date()
        
        let timestamp = ErrorLog.shared.entries.first!.timestamp
        XCTAssertTrue(timestamp >= before && timestamp <= after)
    }
}
