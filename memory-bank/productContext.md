# Product Context: Social Marketer

## Problem Statement

Content creators struggle to maintain consistent presence across multiple social media platforms. Manual posting is time-consuming and leads to inconsistent messaging. Wisdom Book needs a systematic way to distribute inspirational content to drive traffic and build community.

## Solution

A native macOS application that automates content distribution with:
- **One-click publishing** to multiple platforms
- **Consistent branding** through templated quote graphics
- **Scheduled automation** via launchd background execution
- **Local rendering** for privacy and reliability

## User Experience Goals

1. **Simple Setup**: Configure once, run automatically
2. **Visual Preview**: See graphics before posting
3. **Platform Management**: Toggle platforms on/off easily
4. **Error Recovery**: Clear logs and retry mechanisms
5. **Minimal Maintenance**: "Set it and forget it" operation

## Content Flow

```
wisdombook.life RSS → Quote Graphic Generator → Platform Distributors
                           ↓
                    10 Border Templates
                    Core Graphics Rendering
                    Watermarked Output
```

## Platform Strategy

### Priority 1 (V1)
- **X (Twitter)**: Quick quotes, threaded thoughts
- **Instagram**: Visual-first, story-driven
- **LinkedIn**: Professional wisdom, business audience
- **YouTube**: Community posts for subscribers
- **Substack**: Notes for newsletter readers

### Future Platforms
- Facebook, Pinterest, Bluesky, Tumblr

## Content Types

| Type | Source | Format |
|------|--------|--------|
| Daily Wisdom | /feed/daily.xml | Quote graphic |
| Thoughts | /feed/thoughts.xml | Extended content |
| Quotes | /feed/quotes.xml | Short quotes |
| Passages | /feed/passages.xml | Scripture passages |

## Success Indicators

- Consistent daily posting across all platforms
- Growing wisdombook.life traffic
- Increased Ko-fi supporter conversions
- Reduced manual posting time to near-zero

## Differentiation

Unlike general social media managers, Social Marketer is:
- **Purpose-built** for wisdom/spiritual content
- **Fully native** macOS experience
- **Offline-capable** after setup
- **Integrated** with Social Effects for video
