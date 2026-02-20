# Active Context: Social Marketer

## Current Status
🟡 **In Development** - Core infrastructure being built

## Recent Changes

### Latest Updates (February 19, 2026)
- **Memory Bank Initiated**: Documentation structure established
- **Social Effects API Integration**: Documented HTTP API for video generation
- **API Documentation**: Created comprehensive API integration guide
- **Project Structure**: Defined V1 roadmap and architecture

### Current Work Focus

#### Immediate Priorities
1. **Core Data Setup**: Models for Posts, Platforms, Logs
2. **RSS Parser**: Connect to wisdombook.life feeds
3. **Quote Graphic Generator**: Core Graphics implementation with 10 templates
4. **Platform Connectors**: X, Instagram, LinkedIn APIs

#### Active Development Areas
- SwiftUI view architecture
- Service layer design
- launchd background execution setup

## Next Steps

### This Week
- [ ] Implement Core Data stack
- [ ] Build RSS parser service
- [ ] Create QuoteGraphicGenerator with templates
- [ ] Set up PlatformConnector protocol

### Short Term (2-3 weeks)
- [ ] Complete 5 platform connectors
- [ ] Implement scheduling service
- [ ] Add logging and error handling
- [ ] Create Settings UI

### Medium Term (4-6 weeks)
- [ ] Google Search Console integration
- [ ] Feedly submission automation
- [ ] launchd background execution
- [ ] V1 testing and polish

## Technical Decisions

### Architecture
- **SwiftUI** for UI (native macOS experience)
- **Core Data** for persistence
- **Combine** for reactive programming
- **launchd** for background execution

### Platform Strategy
- Start with 5 priority platforms
- OAuth-based authentication
- REST API where available
- Browser automation fallback for complex platforms

## Important Patterns & Preferences

### Code Organization
- Services pattern for all external APIs
- Protocol-based design for platform connectors
- Core Graphics for image generation (no external AI)

### Configuration
- Platform credentials in Keychain
- RSS feed URLs configurable
- Posting schedule customizable

## Known Issues

- External drive dependency for video storage
- launchd complexity for background execution
- OAuth token refresh handling

## Learnings

- Social Effects integration requires running local API server
- macOS app sandboxing limits some automation options
- Core Graphics sufficient for V1 image generation needs
