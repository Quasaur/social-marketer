# Feedly Implementation Plan

**Goal**: Register wisdombook.life with Feedly and optimize for discovery — all on the free tier  
**Date**: February 11, 2026  
**Prerequisite**: RSS feeds already live at `wisdombook.life/feed/*.xml`

---

## Context

Feedly is an RSS aggregator with millions of users. Unlike social media platforms, Feedly doesn't require API credentials or OAuth — content becomes discoverable when any user subscribes to an RSS feed URL. Our strategy is to use Feedly as a **passive discovery channel**, not an automation hub (that's Social Marketer's job).

### Free Tier Constraints

| Resource         | Limit        | Impact                                                             |
|------------------|--------------|--------------------------------------------------------------------|
| Sources          | 100          | More than enough for our use                                       |
| Feeds / Folders  | 3 each       | We must pick our 3 best feeds to follow                            |
| Personal Boards  | 3            | Curate "Best Of" collections for showcase                          |
| Public Boards    | ❌ Pro only  | Cannot share curated boards publicly                               |
| Integrations     | ❌ Pro only  | No Zapier/Buffer — irrelevant since Social Marketer handles posting |
| Feedly AI (Leo)  | ❌ Pro+ only | Cannot train AI prioritization                                     |

### What We Can Do for Free

1. **Register feeds** — subscribing makes them searchable in Feedly Discover
2. **Optimize metadata** — Feedly's card view uses `og:image`, titles, and descriptions from RSS
3. **Curate boards** — 3 personal boards to organize our best content
4. **Drive followers** — Feedly "follow" URLs can be shared on social media and on wisdombook.life

---

## Proposed Changes

### Phase 1 — Feedly Account Setup (Manual)

No code changes. These are one-time manual steps performed in the Feedly web app.

#### Steps

1. **Create a Feedly account** at <https://feedly.com> (sign up with Google or email)
2. **Subscribe to our 3 most strategic feeds** (free tier allows 3 feeds):

   | Feed         | URL                                          | Rationale                                      |
   |--------------|----------------------------------------------|-------------------------------------------------|
   | All Wisdom   | `https://wisdombook.life/feed/wisdom.xml`    | Broadest content — registers the master feed    |
   | Daily Wisdom | `https://wisdombook.life/feed/daily.xml`     | Fresh content daily — keeps the feed "alive"    |
   | Quotes       | `https://wisdombook.life/feed/quotes.xml`    | Most "snackable" / shareable content type       |

3. **Organize into folders** (free tier allows 3 folders):
   - `Wisdom Book` — contains all 3 feeds above

4. **Create 3 Personal Boards** to curate standout content:

   | Board                   | Purpose                                                      |
   |-------------------------|--------------------------------------------------------------|
   | ⭐ Best of Wisdom Book  | Top-performing quotes and thoughts                           |
   | 📖 Daily Highlights     | Bookmark the best daily wisdom entries                       |
   | 🔥 Trending Topics      | Content aligned with current cultural/spiritual discussions  |

5. **Verify discovery** — search for "wisdombook" or "Book of Wisdom" in Feedly Discover to confirm the feeds are indexed

---

### Phase 2 — RSS Feed Optimization for Feedly

Enhancements to the Django RSS feeds backend to improve how content appears in Feedly's card view.

#### [MODIFY] [feeds.py](file:///Users/quasaur/Developer/social-marketer/docs/rss_feed.md)

> **Note**: The actual feed code lives in the wisdombook.life backend (not in Social Marketer). These changes are documented here for reference — they would be implemented in the Wisdom Book backend repo.

**Changes**:

1. Add `<image>` element to each channel (Feedly uses this as the feed icon):

   ```xml
   <image>
     <url>https://wisdombook.life/static/icons/feed-icon-512.png</url>
     <title>The Book of Wisdom</title>
     <link>https://wisdombook.life</link>
   </image>
   ```

2. Add keyword-rich `<category>` tags to feed items for Feedly's AI categorization:
   - `Wisdom`, `Philosophy`, `Faith`, `Personal Growth`, `Daily Inspiration`
   - These help Feedly surface content when users follow Power Searches

3. Ensure all `<description>` content includes 2–3 sentences (not just the raw quote text) so Feedly's card preview is informative

4. Add `<atom:icon>` for feed icon display in modern readers

> [!NOTE]
> These backend RSS changes benefit **all** RSS aggregators (Flipboard, NewsBlur, Inoreader) — not just Feedly. They should be implemented once and will improve discoverability across the board.

---

### Phase 3 — "Follow on Feedly" Links

Generate Feedly subscription URLs that can be used in Social Marketer posts and on wisdombook.life.

#### Feedly Follow URL Format

```text
https://feedly.com/i/subscription/feed/https://wisdombook.life/feed/wisdom.xml
```

| Feed       | Feedly Follow URL                                                                |
|------------|-----------------------------------------------------------------------------------|
| All Wisdom | `https://feedly.com/i/subscription/feed/https://wisdombook.life/feed/wisdom.xml` |
| Quotes     | `https://feedly.com/i/subscription/feed/https://wisdombook.life/feed/quotes.xml` |
| Daily      | `https://feedly.com/i/subscription/feed/https://wisdombook.life/feed/daily.xml`  |

These URLs can be:

- Shared in Social Marketer posts as a CTA: *"Follow us on Feedly for daily wisdom"*
- Added to the wisdombook.life footer or About page
- Included in email digests

---

### Phase 4 — Social Marketer App: Feedly Row in DiscoveryView

Replace the Feedly placeholder row with a functional status row.

#### [MODIFY] [DiscoveryView.swift](file:///Users/quasaur/Developer/social-marketer/Social%20Marketer/Social%20Marketer/Views/DiscoveryView.swift)

**Current** (line 116–120): Feedly is a `DiscoveryPlaceholderRow` showing "Coming soon"

**Change to**: A `FeedlyRow` component that:

- Shows a green ✅ status when the user marks Feedly as set up
- Provides a "Open Feedly" button that opens `https://feedly.com` in the default browser
- Provides a "Copy Feed URL" button that copies `https://wisdombook.life/feed/wisdom.xml` to clipboard
- Stores setup status in `UserDefaults` (simple boolean — no API key needed)

**Design** (matching the existing `GoogleSearchConsoleRow` pattern):

```text
┌──────────────────────────────────────────────────────┐
│ 📡 Feedly                          [Copy Feed URL]   │
│    wisdombook.life/feed/wisdom.xml  [Open Feedly  ]   │
│    ✅ Set up                        [  Mark Done  ]   │
└──────────────────────────────────────────────────────┘
```

---

## What We Are NOT Doing (Free Tier Boundaries)

These features require paid Feedly tiers and are **out of scope**:

| Feature                   | Tier Required   | Alternative                                                         |
|---------------------------|-----------------|---------------------------------------------------------------------|
| Public Boards             | Pro ($6/mo)     | Share direct links to wisdombook.life categories instead            |
| Zapier/Buffer integration | Pro ($6/mo)     | Social Marketer handles all posting automation                      |
| Leo AI training           | Pro+ ($8.25/mo) | Optimize RSS metadata keywords for organic categorization           |
| Newsletter ingestion      | Pro+ ($8.25/mo) | Email digests already handled by Wisdom Book's notification system  |

> [!TIP]
> **When to upgrade**: If wisdombook.life gains a significant Feedly following (100+ subscribers), the Pro tier at $6/mo becomes worthwhile for Public Boards — allowing you to create shareable curated collections that function as landing pages.

---

## Verification Plan

### Manual Verification (Phase 1 — Account Setup)

1. Log in to <https://feedly.com>
2. Subscribe to `https://wisdombook.life/feed/wisdom.xml`
3. Verify content appears in the Feedly reader with:
   - Correct titles
   - Content preview text
   - Feed icon (after Phase 2 enhancements)
4. Search "wisdombook" in Feedly Discover — confirm the feed appears

### Manual Verification (Phase 4 — App Changes)

1. Build and run Social Marketer in Xcode
2. Navigate to the **Discovery & Indexing** panel
3. Expand the **RSS Aggregators** section
4. Verify the Feedly row shows:
   - Feed URL text
   - "Copy Feed URL" button → copies URL to clipboard
   - "Open Feedly" button → opens Feedly in browser
   - "Mark Done" button → toggles ✅ status
5. Quit and relaunch → verify the ✅ status persists

---

## Implementation Order

| #   | Phase                    | Type                       | Effort   |
|-----|--------------------------|----------------------------|----------|
| 1   | Feedly Account Setup     | Manual (one-time)          | 10 min   |
| 2   | RSS Feed Optimization    | Backend (Wisdom Book repo) | ~1 hour  |
| 3   | Feedly Follow URLs       | Documentation only         | 5 min    |
| 4   | DiscoveryView Feedly Row | Swift (Social Marketer)    | ~30 min  |

> [!IMPORTANT]
> **Phase 1 can be done immediately** — no code changes required. Phases 2–4 can follow in any order.
