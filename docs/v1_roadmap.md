# Social Marketer V1 Roadmap

**Project**: Native MacOS Desktop Application for Social Media Automation  
**Version**: 1.0 (MVP)  
**Created**: February 5, 2026  
**Architecture**: Swift/SwiftUI + `launchd` (No AI Required)

---

## Prime Directive

> **Mission**: Drive visitors from all over the world to wisdombook.life and build a devoted following of Ko-fi supporters.

**Success Metrics**:

| Metric | Goal |
|--------|------|
| Site traffic | Grow monthly |
| Registered members | Maximize conversions |
| Ko-fi supporters | Build sustainable support |

---

## V1 Distribution Channels

| Channel | V1 Target | V2+ Expansion |
|---------|-----------|---------------|
| **Social Media** | X, IG, LinkedIn, YouTube, Substack | +FB, Pinterest, Bluesky, Tumblr |
| **Search Engines** | Google Search Console | +Bing, Yandex, DuckDuckGo |
| **RSS Aggregators** | Feedly | +Flipboard, NewsBlur, Inoreader |
| **Web Directories** | 1 high-DA directory | +Niche directories |

### V1 Account Configuration (Priority 1 Platforms)

| Platform | Account | Post Type |
|----------|---------|-----------|
| X (Twitter) | @Quasauthor | Image post |
| Instagram | @quasauthor777 (→ Business) | Image post |
| LinkedIn | @quasaur | Image post |
| YouTube | @CalvinMitchell | Community post |
| Substack | @clmjournal | Notes/image post |

---

## V1 Content: Quote Graphics

### Local Rendering (No External AI)

```
RSS Content → Random template → Core Graphics text overlay → Export PNG
```

### Image Structure (All Required)

| Element | Description |
|---------|-------------|
| **Title** | Greek/English header (always present) |
| **Content** | Wisdom text from RSS |
| **References** | Scripture citations |
| **Watermark** | `wisdombook.life` in bold gold |
| **Border** | 1 of 10 templates (auto-rotate) |

### 10 Border Templates (Bundled Assets)

1. Art Deco
2. Greek Laurel
3. Sacred Geometry
4. Celtic Knot
5. Minimalist
6. Baroque
7. Victorian
8. Islamic Geometric
9. Stained Glass
10. Modern Glow

---

## Platform Link Strategy

| Platform | Link Method |
|----------|-------------|
| **X (Twitter)** | URL in post text (clickable) |
| **Facebook** | URL generates link preview card |
| **LinkedIn** | URL in post text + preview |
| **Instagram** | "Link in bio" + caption CTA |
| **Bluesky** | URL in post text (clickable) |

> Every post includes `wisdombook.life` URL where platform allows

---

## Posting Schedule (V1)

| Setting | Default |
|---------|---------|
| **Frequency** | 1 post/day (from `/feed/daily.xml`) |
| **Timing** | Optimal per platform (see below) |

**Optimal Posting Times** (EST):

| Platform | Best Time |
|----------|-----------|
| X (Twitter) | 9:00 AM |
| Facebook | 1:00 PM |
| LinkedIn | 10:00 AM |
| Instagram | 6:00 PM |
| Bluesky | 9:00 AM |

## V1 Features

| Feature | Priority |
|---------|----------|
| Quote graphic generation (local) | 🔴 Critical |
| 5 social media connectors (+Threads) | 🔴 Critical |
| Clickable URL in every post | 🔴 Critical |
| Google Search Console ping | 🔴 Critical |
| Feedly submission | 🔴 Critical |
| `launchd` background execution | 🔴 Critical |
| Success/failure logging | 🟡 High |
| Login Item (start at boot) | 🟡 High |

---

## V1 Architecture

```
┌────────────────────────────────────────────────────────────┐
│                    Social Marketer V1                      │
├────────────────────────────────────────────────────────────┤
│  RSS Parser → Image Generator → Platform Distributors     │
│       ↓              ↓                    ↓                │
│  wisdombook.life  Core Graphics    X, IG, LinkedIn,       │
│  /feed/*.xml      + 10 templates   FB+Threads, Bluesky    │
│                        +                                   │
│                   Google, Feedly, Directory               │
└────────────────────────────────────────────────────────────┘
```

---

## Implementation Phases

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| **Foundation** | Week 1-2 | Xcode setup, Core Data, launchd scheduler, RSS parser |
| **Image Gen** | Week 2-3 | 10 border templates, Core Graphics renderer |
| **Platform APIs** | Week 3-4 | Twitter, Instagram, LinkedIn, Facebook, Bluesky |
| **Distribution** | Week 4-5 | Google ping, Feedly submission, directory submit |
| **Polish** | Week 5-6 | Logging, Login Item, error handling, testing |

**Total Timeline**: 4-6 weeks

---

## Content Source

```
https://wisdombook.life/feed/wisdom.xml   (all content)
https://wisdombook.life/feed/thoughts.xml (thoughts only)
https://wisdombook.life/feed/quotes.xml   (quotes only)
https://wisdombook.life/feed/passages.xml (passages only)
https://wisdombook.life/feed/daily.xml    (1 random/day)
```

---

## Version Roadmap

| Version | Scope | Timeline |
|---------|-------|----------|
| **V1** | 5 social + Google + Feedly + 1 directory | 4-6 weeks |
| **V2** | +4 platforms, analytics, queue management | +4 weeks |
| **V3** | +9 platforms (headless browser), Apple Notes sync | +4 weeks |
