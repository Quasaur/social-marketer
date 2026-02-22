//
//  PlatformSettingsView+Helpers.swift
//  SocialMarketer
//
//  Helper methods for PlatformSettingsView
//

import SwiftUI

extension PlatformSettingsView {
    
    func getFirstPendingPost() async -> Post? {
        let context = PersistenceController.shared.viewContext
        return await context.perform {
            return Post.fetchPending(in: context).first
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
