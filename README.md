# Social Marketer

A native macOS application for managing content distribution across 18 social media platforms.

## Overview

Social Marketer is a Swift/SwiftUI desktop application that automates content syndication from the Wisdom Book platform to multiple social media channels using a hybrid API/automation approach.

## Features

- **Multi-Platform Distribution**: Manage content across 18 social media platforms
- **Content Ingestion**: Pull content from wisdombook.life via REST API and RSS feeds
- **Hybrid Automation**: Combines direct API integration with browser automation
- **Native macOS**: Built with Swift and SwiftUI for optimal performance

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Project Structure

```
SocialMarketer/
├── SocialMarketer/          # Main application code
│   ├── App/                 # App entry point and configuration
│   ├── Views/               # SwiftUI views
│   ├── Models/              # Data models
│   ├── Services/            # API clients and automation services
│   └── Resources/           # Assets and resources
├── docs/                    # Documentation
│   └── marketing/           # Marketing strategy and platform registry
└── SocialMarketer.xcodeproj # Xcode project
```

## Getting Started

1. Clone the repository
2. Open `SocialMarketer.xcodeproj` in Xcode
3. Build and run the project

## Documentation

See the `docs/marketing` folder for:

- Platform registry (18 social media accounts)
- Content distribution strategy
- Marketing workflows

## License

TBD

## Contact

For questions or support, contact: <devcalvinlm@gmail.com>
