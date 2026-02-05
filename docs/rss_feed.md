# RSS Feed Implementation Plan

> **Status:** ✅ IMPLEMENTED & VERIFIED  
> **Date Completed:** February 5, 2026  
> **Production URLs:** All feeds live at `https://wisdombook.life/feed/*.xml`

## Execution Summary

All 5 RSS feed endpoints have been successfully implemented and tested:

- ✅ **All Wisdom Feed** (`/feed/wisdom.xml`) - Combined feed with 50 most recent items
- ✅ **Thoughts Feed** (`/feed/thoughts.xml`) - Thoughts only (50 items)
- ✅ **Quotes Feed** (`/feed/quotes.xml`) - Quotes only (50 items)
- ✅ **Passages Feed** (`/feed/passages.xml`) - Bible passages only (50 items)
- ✅ **Daily Wisdom Feed** (`/feed/daily.xml`) - One random entry per day (24hr cache)

### Implementation Details

- **Django App:** `backend/rss_feeds/` created with `feeds.py` and `urls.py`
- **URL Routing:** Added `path("feed/", include("rss_feeds.urls"))` to main URLs
- **Settings:** Added `rss_feeds` to `INSTALLED_APPS`
- **Parent Topics:** Included in all feeds except Daily Wisdom (as planned)
- **Access:** All feeds are publicly accessible (no authentication required)

### Verification Results

All feeds tested locally and confirmed:

- Valid XML structure (`<?xml version="1.0" encoding="utf-8"?>`)
- RSS 2.0 compliant (`<rss version="2.0">`)
- Proper channel metadata (title, link, description)
- Item elements with title, link, description, guid
- Parent topic context included where appropriate

---

## Overview

Implement RSS 2.0 compliant feeds for wisdombook.life to enable automated content distribution via Social Marketer and other RSS readers.

## Feed Strategy

### Proposed Feeds

1. **All Wisdom Feed** - `/feed/wisdom.xml` - Combined feed of all content types
2. **Thoughts Feed** - `/feed/thoughts.xml` - Thoughts only
3. **Quotes Feed** - `/feed/quotes.xml` - Quotes only  
4. **Passages Feed** - `/feed/passages.xml` - Bible passages only
5. **Daily Wisdom Feed** - `/feed/daily.xml` - One random entry per day

---

## Feed Examples

### 1. All Wisdom Feed (`/feed/wisdom.xml`)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>The Book of Wisdom - All Content</title>
    <link>https://wisdombook.life</link>
    <description>Wisdom from thoughts, quotes, and Bible passages across all levels</description>
    <language>en-us</language>
    <atom:link href="https://wisdombook.life/feed/wisdom.xml" rel="self" type="application/rss+xml"/>
    <lastBuildDate>Wed, 05 Feb 2026 12:00:00 GMT</lastBuildDate>
    <generator>Django RSS Feed</generator>
    
    <!-- Thought Item -->
    <item>
      <title>Thought: TO BE LED</title>
      <link>https://wisdombook.life/thoughts/to-be-led</link>
      <description>
        <![CDATA[
        <p><strong>Level 3 Thought</strong></p>
        <p>To be led by the Spirit of God is to be led by the Spirit of Truth...</p>
        <p><em>From: THE SPIRIT OF TRUTH</em></p>
        ]]>
      </description>
      <guid isPermaLink="true">https://wisdombook.life/thoughts/to-be-led</guid>
      <pubDate>Wed, 05 Feb 2026 06:00:00 GMT</pubDate>
      <category>Thought</category>
      <category>Level 3</category>
    </item>
    
    <!-- Quote Item -->
    <item>
      <title>Quote: LOGICAL COURSE</title>
      <link>https://wisdombook.life/quotes/logical-course</link>
      <description>
        <![CDATA[
        <p><strong>Level 4 Quote</strong></p>
        <p>The logical course of action for an ignorant creature (and all creatures are ignorant to varying degrees) is to place its total faith in its Creator Who knows and understands all.</p>
        <p><em>From: IGNORANCE</em></p>
        ]]>
      </description>
      <guid isPermaLink="true">https://wisdombook.life/quotes/logical-course</guid>
      <pubDate>Tue, 04 Feb 2026 18:00:00 GMT</pubDate>
      <category>Quote</category>
      <category>Level 4</category>
    </item>
    
    <!-- Passage Item -->
    <item>
      <title>Passage: OBLIGATION</title>
      <link>https://wisdombook.life/passages/obligation</link>
      <description>
        <![CDATA[
        <p><strong>Level 3 Passage - Proverbs 3:27,28</strong></p>
        <p>Do not withhold good from those to whom it is due, when it is in your power to do it.</p>
        <p><em>From: OBLIGATION</em></p>
        ]]>
      </description>
      <guid isPermaLink="true">https://wisdombook.life/passages/obligation</guid>
      <pubDate>Mon, 03 Feb 2026 12:00:00 GMT</pubDate>
      <category>Passage</category>
      <category>Level 3</category>
    </item>
  </channel>
</rss>
```

### 2. Thoughts Feed (`/feed/thoughts.xml`)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>The Book of Wisdom - Thoughts</title>
    <link>https://wisdombook.life/thoughts</link>
    <description>Insights and reflections from The Book of Wisdom</description>
    <language>en-us</language>
    <atom:link href="https://wisdombook.life/feed/thoughts.xml" rel="self" type="application/rss+xml"/>
    
    <item>
      <title>TO BE LED</title>
      <link>https://wisdombook.life/thoughts/to-be-led</link>
      <description>
        <![CDATA[
        <p><strong>Level 3</strong></p>
        <p>To be led by the Spirit of God is to be led by the Spirit of Truth...</p>
        <p><em>Parent Topic: THE SPIRIT OF TRUTH</em></p>
        ]]>
      </description>
      <guid isPermaLink="true">https://wisdombook.life/thoughts/to-be-led</guid>
      <pubDate>Wed, 05 Feb 2026 06:00:00 GMT</pubDate>
      <category>Level 3</category>
    </item>
  </channel>
</rss>
```

### 3. Quotes Feed (`/feed/quotes.xml`)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>The Book of Wisdom - Quotes</title>
    <link>https://wisdombook.life/quotes</link>
    <description>Curated quotes from The Book of Wisdom</description>
    <language>en-us</language>
    <atom:link href="https://wisdombook.life/feed/quotes.xml" rel="self" type="application/rss+xml"/>
    
    <item>
      <title>LOGICAL COURSE</title>
      <link>https://wisdombook.life/quotes/logical-course</link>
      <description>
        <![CDATA[
        <p><strong>Level 4</strong></p>
        <p>The logical course of action for an ignorant creature (and all creatures are ignorant to varying degrees) is to place its total faith in its Creator Who knows and understands all.</p>
        <p><em>Parent Topic: IGNORANCE</em></p>
        ]]>
      </description>
      <guid isPermaLink="true">https://wisdombook.life/quotes/logical-course</guid>
      <pubDate>Tue, 04 Feb 2026 18:00:00 GMT</pubDate>
      <category>Level 4</category>
    </item>
  </channel>
</rss>
```

### 4. Passages Feed (`/feed/passages.xml`)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>The Book of Wisdom - Bible Passages</title>
    <link>https://wisdombook.life/passages</link>
    <description>Scripture passages from The Book of Wisdom</description>
    <language>en-us</language>
    <atom:link href="https://wisdombook.life/feed/passages.xml" rel="self" type="application/rss+xml"/>
    
    <item>
      <title>OBLIGATION - Proverbs 3:27,28</title>
      <link>https://wisdombook.life/passages/obligation</link>
      <description>
        <![CDATA[
        <p><strong>Level 3 - Proverbs 3:27,28</strong></p>
        <p>Do not withhold good from those to whom it is due, when it is in your power to do it.</p>
        <p><em>Parent Topic: OBLIGATION</em></p>
        ]]>
      </description>
      <guid isPermaLink="true">https://wisdombook.life/passages/obligation</guid>
      <pubDate>Mon, 03 Feb 2026 12:00:00 GMT</pubDate>
      <category>Level 3</category>
      <category>Proverbs</category>
    </item>
  </channel>
</rss>
```

### 5. Daily Wisdom Feed (`/feed/daily.xml`)

**Special Behavior:** Returns ONE random entry per day (cached for 24 hours)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>The Book of Wisdom - Daily Wisdom</title>
    <link>https://wisdombook.life</link>
    <description>One piece of wisdom delivered daily</description>
    <language>en-us</language>
    <atom:link href="https://wisdombook.life/feed/daily.xml" rel="self" type="application/rss+xml"/>
    <ttl>1440</ttl><!-- Cache for 24 hours (1440 minutes) -->
    
    <item>
      <title>Today's Wisdom: LOGICAL COURSE</title>
      <link>https://wisdombook.life/quotes/logical-course</link>
      <description>
        <![CDATA[
        <p><strong>Quote - Level 4</strong></p>
        <p>The logical course of action for an ignorant creature (and all creatures are ignorant to varying degrees) is to place its total faith in its Creator Who knows and understands all.</p>
        ]]>
      </description>
      <guid isPermaLink="false">daily-2026-02-05</guid>
      <pubDate>Wed, 05 Feb 2026 00:00:00 GMT</pubDate>
      <category>Daily Wisdom</category>
    </item>
  </channel>
</rss>
```

---

## Technical Implementation

### 1. Django RSS Feed Framework

Use Django's built-in `django.contrib.syndication.views.Feed` class.

**Create:** `backend/feeds_app/` (new Django app)

```
feeds_app/
├── __init__.py
├── apps.py
├── feeds.py          # Feed class definitions
├── urls.py           # Feed URL routing
└── utils.py          # Helper functions (date formatting, caching)
```

### 2. Feed Classes

#### `feeds.py`

```python
from django.contrib.syndication.views import Feed
from django.utils.feedgenerator import Rss201rev2Feed
from django.urls import reverse
from thoughts_app.models import Thought
from quotes_app.models import Quote
from passages_app.models import Passage
from django.core.cache import cache
import random
from datetime import datetime

class AllWisdomFeed(Feed):
    title = "The Book of Wisdom - All Content"
    link = "/"
    description = "Wisdom from thoughts, quotes, and Bible passages across all levels"
    feed_type = Rss201rev2Feed
    
    def items(self):
        # Combine all content types, sorted by most recent
        thoughts = list(Thought.objects.filter(is_active=True).order_by('-id')[:20])
        quotes = list(Quote.objects.filter(is_active=True).order_by('-id')[:20])
        passages = list(Passage.objects.filter(is_active=True).order_by('-id')[:20])
        
        # Combine and sort by ID (proxy for recency)
        all_items = thoughts + quotes + passages
        all_items.sort(key=lambda x: x.id, reverse=True)
        return all_items[:50]  # Return 50 most recent
    
    def item_title(self, item):
        content_type = item.__class__.__name__
        return f"{content_type}: {item.title}"
    
    def item_description(self, item):
        # Build HTML description based on content type
        if isinstance(item, Thought):
            return self._format_thought(item)
        elif isinstance(item, Quote):
            return self._format_quote(item)
        elif isinstance(item, Passage):
            return self._format_passage(item)
    
    def item_link(self, item):
        content_type = item.__class__.__name__.lower()
        return f"/{content_type}s/{item.slug}"
    
    def item_guid(self, item):
        return self.item_link(item)
    
    def item_categories(self, item):
        categories = [item.__class__.__name__, f"Level {item.level}"]
        return categories
    
    def _format_thought(self, thought):
        desc = f"<p><strong>Level {thought.level} Thought</strong></p>"
        if thought.description:
            desc += f"<p>{thought.description}</p>"
        if thought.parent_id:
            from topics_app.models import Topic
            parent = Topic.objects.filter(neo4j_id=thought.parent_id).first()
            if parent:
                desc += f"<p><em>From: {parent.title}</em></p>"
        return desc
    
    def _format_quote(self, quote):
        desc = f"<p><strong>Level {quote.level} Quote</strong></p>"
        if quote.contents.exists():
            content = quote.contents.first().en_content
            desc += f"<p>{content}</p>"
        if quote.parent:
            desc += f"<p><em>From: {quote.parent.title}</em></p>"
        return desc
    
    def _format_passage(self, passage):
        reference = f"{passage.book} {passage.chapter}:{passage.verse}" if passage.book else ""
        desc = f"<p><strong>Level {passage.level} Passage"
        if reference:
            desc += f" - {reference}"
        desc += "</strong></p>"
        if passage.contents.exists():
            content = passage.contents.first().en_content
            desc += f"<p>{content}</p>"
        if passage.parent:
            desc += f"<p><em>From: {passage.parent.title}</em></p>"
        return desc


class ThoughtsFeed(Feed):
    title = "The Book of Wisdom - Thoughts"
    link = "/thoughts"
    description = "Insights and reflections from The Book of Wisdom"
    
    def items(self):
        return Thought.objects.filter(is_active=True).order_by('-id')[:50]
    
    def item_title(self, item):
        return item.title
    
    def item_description(self, item):
        desc = f"<p><strong>Level {item.level}</strong></p>"
        if item.description:
            desc += f"<p>{item.description}</p>"
        if item.parent_id:
            from topics_app.models import Topic
            parent = Topic.objects.filter(neo4j_id=item.parent_id).first()
            if parent:
                desc += f"<p><em>Parent Topic: {parent.title}</em></p>"
        return desc
    
    def item_link(self, item):
        return f"/thoughts/{item.slug}"
    
    def item_categories(self, item):
        return [f"Level {item.level}"]


class QuotesFeed(Feed):
    title = "The Book of Wisdom - Quotes"
    link = "/quotes"
    description = "Curated quotes from The Book of Wisdom"
    
    def items(self):
        return Quote.objects.filter(is_active=True).order_by('-id')[:50]
    
    def item_title(self, item):
        return item.title
    
    def item_description(self, item):
        desc = f"<p><strong>Level {item.level}</strong></p>"
        if item.contents.exists():
            content = item.contents.first().en_content
            desc += f"<p>{content}</p>"
        if item.parent:
            desc += f"<p><em>Parent Topic: {item.parent.title}</em></p>"
        return desc
    
    def item_link(self, item):
        return f"/quotes/{item.slug}"
    
    def item_categories(self, item):
        return [f"Level {item.level}"]


class PassagesFeed(Feed):
    title = "The Book of Wisdom - Bible Passages"
    link = "/passages"
    description = "Scripture passages from The Book of Wisdom"
    
    def items(self):
        return Passage.objects.filter(is_active=True).order_by('-id')[:50]
    
    def item_title(self, item):
        reference = f"{item.book} {item.chapter}:{item.verse}" if item.book else ""
        return f"{item.title} - {reference}" if reference else item.title
    
    def item_description(self, item):
        reference = f"{item.book} {item.chapter}:{item.verse}" if item.book else ""
        desc = f"<p><strong>Level {item.level}"
        if reference:
            desc += f" - {reference}"
        desc += "</strong></p>"
        if item.contents.exists():
            content = item.contents.first().en_content
            desc += f"<p>{content}</p>"
        if item.parent:
            desc += f"<p><em>Parent Topic: {item.parent.title}</em></p>"
        return desc
    
    def item_link(self, item):
        return f"/passages/{item.slug}"
    
    def item_categories(self, item):
        categories = [f"Level {item.level}"]
        if item.book:
            categories.append(item.book)
        return categories


class DailyWisdomFeed(Feed):
    title = "The Book of Wisdom - Daily Wisdom"
    link = "/"
    description = "One piece of wisdom delivered daily"
    ttl = 1440  # Cache for 24 hours
    
    def items(self):
        # Cache key based on current date
        today = datetime.now().strftime('%Y-%m-%d')
        cache_key = f'daily_wisdom_{today}'
        
        cached_item = cache.get(cache_key)
        if cached_item:
            return [cached_item]
        
        # Get random item from all content types
        thoughts = list(Thought.objects.filter(is_active=True).values_list('id', flat=True))
        quotes = list(Quote.objects.filter(is_active=True).values_list('id', flat=True))
        passages = list(Passage.objects.filter(is_active=True).values_list('id', flat=True))
        
        # Randomly choose content type
        content_types = []
        if thoughts:
            content_types.append(('thought', thoughts))
        if quotes:
            content_types.append(('quote', quotes))
        if passages:
            content_types.append(('passage', passages))
        
        if not content_types:
            return []
        
        chosen_type, ids = random.choice(content_types)
        chosen_id = random.choice(ids)
        
        if chosen_type == 'thought':
            item = Thought.objects.get(id=chosen_id)
        elif chosen_type == 'quote':
            item = Quote.objects.get(id=chosen_id)
        else:
            item = Passage.objects.get(id=chosen_id)
        
        # Cache for 24 hours
        cache.set(cache_key, item, 86400)
        return [item]
    
    def item_title(self, item):
        return f"Today's Wisdom: {item.title}"
    
    def item_description(self, item):
        content_type = item.__class__.__name__
        desc = f"<p><strong>{content_type} - Level {item.level}</strong></p>"
        
        if isinstance(item, Thought) and item.description:
            desc += f"<p>{item.description}</p>"
        elif hasattr(item, 'contents') and item.contents.exists():
            content = item.contents.first().en_content
            desc += f"<p>{content}</p>"
        
        return desc
    
    def item_link(self, item):
        content_type = item.__class__.__name__.lower()
        return f"/{content_type}s/{item.slug}"
    
    def item_guid(self, item):
        today = datetime.now().strftime('%Y-%m-%d')
        return f"daily-{today}"
    
    def item_guid_is_permalink(self, item):
        return False
    
    def item_categories(self, item):
        return ["Daily Wisdom"]
```

#### `urls.py`

```python
from django.urls import path
from .feeds import (
    AllWisdomFeed,
    ThoughtsFeed,
    QuotesFeed,
    PassagesFeed,
    DailyWisdomFeed
)

app_name = 'feeds'

urlpatterns = [
    path('wisdom.xml', AllWisdomFeed(), name='all_wisdom'),
    path('thoughts.xml', ThoughtsFeed(), name='thoughts'),
    path('quotes.xml', QuotesFeed(), name='quotes'),
    path('passages.xml', PassagesFeed(), name='passages'),
    path('daily.xml', DailyWisdomFeed(), name='daily'),
]
```

### 3. Main URL Configuration

**Update:** `backend/config/urls.py`

```python
from django.urls import path, include

urlpatterns = [
    # ... existing patterns ...
    path('feed/', include('feeds_app.urls')),
]
```

### 4. Settings Configuration

**Update:** `backend/config/settings.py`

```python
INSTALLED_APPS = [
    # ... existing apps ...
    'feeds_app',
]

# Cache configuration for daily feed
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
        'LOCATION': 'unique-snowflake',
    }
}
```

---

## Verification Plan

### 1. RSS Validation

Use **W3C Feed Validation Service**: <https://validator.w3.org/feed/>

Test each feed:

- <https://wisdombook.life/feed/wisdom.xml>
- <https://wisdombook.life/feed/thoughts.xml>
- <https://wisdombook.life/feed/quotes.xml>
- <https://wisdombook.life/feed/passages.xml>
- <https://wisdombook.life/feed/daily.xml>

### 2. RSS Reader Testing

Test feeds in popular RSS readers:

- **Feedly** (web-based)
- **NetNewsWire** (macOS native)
- **Reeder** (macOS/iOS)

### 3. Daily Feed Caching Test

```bash
# Test daily feed returns same item within 24 hours
curl https://wisdombook.life/feed/daily.xml > daily1.xml
sleep 5
curl https://wisdombook.life/feed/daily.xml > daily2.xml
diff daily1.xml daily2.xml  # Should be identical
```

### 4. Browser Testing

Open feed URLs directly in browser to verify XML rendering:

- Chrome/Safari should display formatted feed
- View source to verify XML structure

---

## Deployment Checklist

- [ ] Create `feeds_app` Django app
- [ ] Implement feed classes in `feeds.py`
- [ ] Configure URL routing
- [ ] Update `settings.py` with cache configuration
- [ ] Run migrations (if any models added)
- [ ] Test locally on <http://localhost:8000/feed/>
- [ ] Validate feeds with W3C validator
- [ ] Test in RSS readers
- [ ] Commit changes to Git
- [ ] Push to GitHub
- [ ] Verify Heroku deployment
- [ ] Test production feeds at wisdombook.life/feed/
- [ ] Update documentation

---

## Future Enhancements (V2+)

1. **Language-Specific Feeds**: `/feed/wisdom-es.xml`, `/feed/wisdom-fr.xml`
2. **Level-Specific Feeds**: `/feed/level-1.xml`, `/feed/level-2.xml`
3. **Topic-Specific Feeds**: `/feed/topics/the-godhead.xml`
4. **Podcast Feed**: Audio narration of daily wisdom (iTunes-compatible RSS)
5. **Full-Text Search Feed**: `/feed/search?q=faith`

---

## Notes

- All feeds return **English content only** (en_content, en_title)
- Feeds are **publicly accessible** (no authentication required)
- Daily feed uses **Django's cache framework** for 24-hour persistence
- Feed items use **slug-based URLs** for permalinks
- HTML in descriptions uses **CDATA** to prevent XML parsing issues
