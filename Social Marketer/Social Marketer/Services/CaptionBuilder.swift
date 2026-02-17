//
//  CaptionBuilder.swift
//  SocialMarketer
//
//  Builds captions and hashtags for social media posts from WisdomEntry data.
//  Extracted from PostScheduler.swift to follow Single Responsibility Principle.
//

import Foundation

/// Generates platform-appropriate captions and hashtags from wisdom entries.
struct CaptionBuilder {
    
    // MARK: - Public API
    
    /// Build a full caption with content, attribution, link, and hashtags
    func buildCaption(from entry: WisdomEntry) -> String {
        var caption = entry.content
        
        if let reference = entry.reference {
            caption += "\n\n— \(reference)"
        }
        
        caption += "\n\n🔗 \(entry.link.absoluteString)"
        caption += "\n\n" + buildHashtags(from: entry).joined(separator: " ")
        
        return caption
    }
    
    /// Build a short caption with only hashtags + link (for Twitter & LinkedIn image posts)
    func buildHashtagCaption(from entry: WisdomEntry) -> String {
        let hashtags = buildHashtags(from: entry).joined(separator: " ")
        return "\(hashtags)\n\n🔗 \(entry.link.absoluteString)"
    }
    
    /// Extract 3 meaningful hashtags from the entry's title and content
    func buildHashtags(from entry: WisdomEntry) -> [String] {
        let stopWords: Set<String> = [
            "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
            "of", "with", "by", "from", "is", "it", "as", "was", "are", "be",
            "this", "that", "these", "those", "has", "have", "had", "not", "no",
            "do", "does", "did", "will", "would", "could", "should", "may",
            "can", "shall", "might", "must", "been", "being", "its", "his",
            "her", "he", "she", "they", "them", "their", "we", "our", "you",
            "your", "who", "whom", "which", "what", "when", "where", "how",
            "all", "each", "every", "both", "few", "more", "most", "other",
            "some", "such", "than", "too", "very", "just", "about", "above",
            "after", "again", "also", "any", "because", "before", "between",
            "come", "into", "know", "let", "like", "make", "many", "much",
            "now", "only", "over", "own", "said", "same", "so", "still",
            "then", "there", "through", "under", "upon", "well", "were",
            "while", "why", "yet", "one", "two", "even", "out", "up", "down"
        ]
        
        /// Extract candidate words from text, filtering stop words and short words
        func extractKeywords(from text: String) -> [String] {
            text.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 2 && !stopWords.contains($0) && $0.rangeOfCharacter(from: .decimalDigits) == nil }
        }
        
        // Title words get priority — they're the most descriptive
        let titleWords = extractKeywords(from: entry.title)
        let contentWords = extractKeywords(from: entry.content)
        
        // Build a unique list: title words first, then longest content words
        var seen = Set<String>()
        var selected: [String] = []
        
        for word in titleWords {
            guard !seen.contains(word) else { continue }
            seen.insert(word)
            selected.append(word)
            if selected.count == 3 { break }
        }
        
        if selected.count < 3 {
            // Sort remaining content words by length (longer = more meaningful)
            let remaining = contentWords
                .filter { !seen.contains($0) }
                .sorted { $0.count > $1.count }
            
            for word in remaining {
                guard !seen.contains(word) else { continue }
                seen.insert(word)
                selected.append(word)
                if selected.count == 3 { break }
            }
        }
        
        // Fallback if we still don't have 3
        let fallbacks = ["wisdom", "wisdombook", "dailywisdom"]
        for fb in fallbacks where selected.count < 3 {
            if !seen.contains(fb) {
                selected.append(fb)
            }
        }
        
        return selected.prefix(3).map { "#\($0)" }
    }
}
