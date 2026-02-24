//
//  PlatformSettingsView+Helpers.swift
//  SocialMarketer
//
//  Helper methods for PlatformSettingsView
//

import SwiftUI

extension PlatformSettingsView {
    
    /// Get the first pending post (scheduled post for the day)
    /// Auto-populates the queue from RSS if empty (for test posts)
    func getFirstPendingPost() async -> Post? {
        let context = PersistenceController.shared.viewContext
        
        // Check if queue is empty and auto-populate if needed
        let pendingCount = await context.perform {
            Post.fetchPending(in: context).count
        }
        
        if pendingCount == 0 {
            print("📬 Queue is empty - auto-populating from RSS for test post...")
            let scheduler = PostScheduler()
            await scheduler.autoPopulateQueueFromRSS()
        }
        
        return await context.perform {
            let pending = Post.fetchPending(in: context)
            let now = Date()
            // Return the first post that is due (scheduled date <= now)
            // or just the first pending post if none are specifically due
            return pending.first { post in
                guard let scheduled = post.scheduledDate else { return false }
                return scheduled <= now
            } ?? pending.first
        }
    }
    
    /// Get the scheduled post for today (due post)
    /// Auto-populates the queue from RSS if empty (for test posts)
    func getScheduledPostForToday() async -> Post? {
        let context = PersistenceController.shared.viewContext
        
        // Check if queue is empty and auto-populate if needed
        let pendingCount = await context.perform {
            Post.fetchPending(in: context).count
        }
        
        if pendingCount == 0 {
            print("📬 Queue is empty - auto-populating from RSS for test post...")
            let scheduler = PostScheduler()
            await scheduler.autoPopulateQueueFromRSS()
        }
        
        return await context.perform {
            let pending = Post.fetchPending(in: context)
            let now = Date()
            let calendar = Calendar.current
            
            // Find post scheduled for today (or earliest due post)
            return pending.first { post in
                guard let scheduled = post.scheduledDate else { return false }
                return scheduled <= now
            } ?? pending.min { post1, post2 in
                guard let date1 = post1.scheduledDate else { return false }
                guard let date2 = post2.scheduledDate else { return true }
                return date1 < date2
            }
        }
    }
    
    func findExistingVideo(for title: String) async -> URL? {
        let scheduler = PostScheduler()
        return scheduler.findExistingVideo(for: title)
    }
    
    func markPostAsPosted(_ post: Post, result: PostResult) async {
        let context = PersistenceController.shared.viewContext
        await context.perform {
            post.postStatus = .posted
            post.postedDate = Date()
            
            let youtubePlatform = Platform.fetchEnabled(in: context).first { $0.name == "YouTube" }
            
            if let platform = youtubePlatform {
                let log = PostLog(
                    context: context,
                    post: post,
                    platform: platform,
                    postID: result.postID,
                    postURL: result.postURL
                )
                log.timestamp = Date()
            }
            
            PersistenceController.shared.save()
        }
    }
}
