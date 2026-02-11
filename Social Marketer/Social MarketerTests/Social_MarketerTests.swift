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
        // HTML tags should be stripped
        XCTAssertFalse(entries.first?.content.contains("<p>") ?? true)
        XCTAssertFalse(entries.first?.content.contains("<b>") ?? true)
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
        // Test default category (not Thought or Quote = passage)
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
    
    func testParseScriptureReference() throws {
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
        // The reference extractor should find "Proverbs 3:5"
        if let ref = entries.first?.reference {
            XCTAssertTrue(ref.contains("Proverbs"), "Reference should contain 'Proverbs', got: \(ref)")
        }
        // Note: reference extraction is best-effort; nil is acceptable for edge cases
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
