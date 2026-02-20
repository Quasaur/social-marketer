# Project Brief: Social Marketer

## Project Overview

**Social Marketer** is a native macOS desktop application for automating content distribution across 18 social media platforms. It serves as the primary tool for driving traffic to wisdombook.life and building a following of Ko-fi supporters.

## Mission Statement

Drive visitors from all over the world to wisdombook.life and build a devoted following of Ko-fi supporters.

## Success Metrics

| Metric | Goal |
|--------|------|
| Site traffic | Grow monthly |
| Registered members | Maximize conversions |
| Ko-fi supporters | Build sustainable support |

## Core Requirements

### V1 Distribution Channels
- **Social Media**: X, Instagram, LinkedIn, YouTube, Substack
- **Search Engines**: Google Search Console
- **RSS Aggregators**: Feedly
- **Web Directories**: 1 high-DA directory

### Content Strategy
- **Source**: wisdombook.life RSS feeds
- **Format**: Quote graphics with 10 border templates
- **Frequency**: 1 post/day

### Technical Requirements
- **Platform**: macOS 14.0+ (Sonoma)
- **Language**: Swift 5.9+
- **Framework**: SwiftUI
- **Architecture**: Native macOS app with launchd background execution

## Scope

### V1 Features (MVP)
- Quote graphic generation (local Core Graphics)
- 5 social media connectors
- Clickable URL in every post
- Google Search Console ping
- Feedly submission
- launchd background execution
- Success/failure logging

### V2+ Expansion
- +4 additional platforms
- Analytics dashboard
- Queue management

### V3
- +9 platforms (headless browser automation)
- Apple Notes sync

## Project Structure

```
SocialMarketer/
├── App/                    # App entry point
├── Views/                  # SwiftUI views
├── Models/                 # Core Data models
├── Services/               # API clients, automation, connectors
├── Resources/              # Border templates, assets
└── docs/                   # Documentation
```

## Key Integration

**Social Effects**: HTTP API integration (port 5390) for video generation from RSS content.

## Constraints

- No AI required for V1 (local rendering only)
- Must work offline after initial setup
- External drive storage required for videos

## Timeline

**V1**: 4-6 weeks

---
*Created*: February 2026  
*Last Updated*: February 19, 2026
