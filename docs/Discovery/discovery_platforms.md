# Discovery Platforms

**Purpose**: Setup and configuration guide for all Discovery & Indexing platforms used by Social Marketer  
**Last Updated**: February 12, 2026

> These platforms correspond to the three tiers in the app's **Discovery & Indexing** panel.

---

## 1. Search Engines

Platforms that crawl and index wisdombook.life for organic search traffic.

### Google Search Console

- **Status**: ✅ Connected
- **Integration**: Service Account Key → Google Indexing API
- **Setup**: Import JSON key via Discovery panel → "Import Key"

### Bing Webmaster Tools

- **Status**: 🔲 Planned
- **Notes**: Coming soon

---

## 2. Web Directories

Curated directories that list wisdombook.life for referral traffic and domain authority.

### Curlie (DMOZ)

- **Status**: ⏳ Submitted (February 12, 2026)
- **URL**: <https://curlie.org>
- **Category**: Society > Religion and Spirituality > Christianity > Christian Living > Devotionals
- **Notes**: Free, human-edited directory. Awaiting editor review (response time varies).

### Best of the Web

- **Status**: 🔲 Planned
- **URL**: <https://botw.org>
- **Notes**: Curated web directory

### Jasmine Directory

- **Status**: 🔲 Planned
- **URL**: <https://www.jasminedirectory.com>
- **Notes**: Quality web directory

---

## 3. RSS Aggregators

Feed readers and content platforms that consume wisdombook.life RSS feeds to reach subscribers and improve discoverability.

### Available Feeds

| Feed         | URL                                  | Content                   |
|--------------|--------------------------------------|---------------------------|
| All Wisdom   | `wisdombook.life/feed/wisdom.xml`    | Combined (50 items)       |
| Thoughts     | `wisdombook.life/feed/thoughts.xml`  | Thoughts only (50 items)  |
| Quotes       | `wisdombook.life/feed/quotes.xml`    | Quotes only (50 items)    |
| Passages     | `wisdombook.life/feed/passages.xml`  | Bible passages (50 items) |
| Daily Wisdom | `wisdombook.life/feed/daily.xml`     | 1 random entry/day        |

---

### Feedly

- **Status**: ✅ Active (February 12, 2026)
- **URL**: <https://feedly.com>
- **Tier**: Free
- **Role**: Primary RSS aggregator — gets wisdombook.life content in front of Feedly's user base

#### Free Tier Limits

| Resource                             | Limit                      |
|--------------------------------------|----------------------------|
| Sources (feeds you follow)           | 100                        |
| Feeds / folders                      | 3 each                     |
| Personal Boards                      | 3                          |
| Public Boards                        | ❌ (Pro only — $6/mo)      |
| Integrations (Zapier, Buffer, etc.)  | ❌ (Pro only)              |
| Feedly AI (Leo)                      | ❌ (Pro+ only — $8.25/mo)  |

#### Free-Tier Strategy

Since we want to maximize the free tier, the goal is **not** to use Feedly as an automation hub (that's Social Marketer's job), but rather to **make wisdombook.life discoverable to Feedly's millions of users**:

1. **Register all 5 RSS feeds** with Feedly so they appear in Feedly Discover search
2. **Optimize RSS metadata** (titles, descriptions, categories, og:image) for Feedly's categorization engine
3. **Use Personal Boards** (3 max) to curate our own best content as a subscriber showcase
4. **Drive followers** via social media CTAs: "Follow us on Feedly"

> **Key Insight**: Feedly has no "submission portal." Content becomes discoverable when *any* user subscribes to an RSS feed URL. The first subscription effectively registers the feed with Feedly's index.

#### Implementation Plan

> 📄 See: [Feedly Implementation Plan](./feedly_implementation_plan.md)

---

### Flipboard

- **Status**: 🔲 Planned
- **URL**: <https://flipboard.com>
- **Notes**: Social magazine platform — coming soon

### NewsBlur

- **Status**: 🔲 Planned
- **URL**: <https://newsblur.com>
- **Notes**: Personal news reader — coming soon
