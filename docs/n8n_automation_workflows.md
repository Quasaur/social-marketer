# n8n Automation Workflows for The Book of Wisdom Marketing

**Purpose**: Automate social media posting across 18 platforms  
**Tool**: n8n (workflow automation platform)  
**Created**: February 4, 2026

---

## Overview

This document provides n8n workflow configurations to automate the marketing strategy for The Book of Wisdom. These workflows will handle content scheduling, cross-posting, and engagement tracking across all 18 social media platforms.

---

## Prerequisites

### Required n8n Nodes/Integrations

1. **Social Media Nodes**:
   - Twitter/X
   - Instagram (via Facebook Graph API)
   - LinkedIn
   - Facebook
   - YouTube
   - TikTok (via API)
   - Pinterest
   - Tumblr
   - RSS/Webhook for others

2. **Utility Nodes**:
   - Schedule Trigger
   - Google Sheets (content calendar)
   - Airtable (alternative to Sheets)
   - HTTP Request (for custom APIs)
   - Set/Function (data transformation)
   - Switch/IF (conditional logic)

3. **Storage**:
   - Google Drive (for images)
   - Cloudinary (image hosting)
   - Database (PostgreSQL for tracking)

---

## Workflow 1: Daily Wisdom Post Automation

### Purpose

Post daily wisdom quotes across all platforms at optimal times.

### Trigger

- **Type**: Schedule
- **Frequency**: Daily at 8:00 AM EST

### Workflow Steps

```json
{
  "name": "Daily Wisdom Post",
  "nodes": [
    {
      "name": "Schedule Trigger",
      "type": "n8n-nodes-base.scheduleTrigger",
      "parameters": {
        "rule": {
          "interval": [
            {
              "field": "cronExpression",
              "expression": "0 8 * * *"
            }
          ]
        },
        "timezone": "America/New_York"
      }
    },
    {
      "name": "Get Today's Content",
      "type": "n8n-nodes-base.googleSheets",
      "parameters": {
        "operation": "read",
        "sheetId": "YOUR_SHEET_ID",
        "range": "Content Calendar!A:F",
        "filters": {
          "date": "={{$today}}"
        }
      }
    },
    {
      "name": "Get Quote Image",
      "type": "n8n-nodes-base.googleDrive",
      "parameters": {
        "operation": "download",
        "fileId": "={{$node['Get Today\\'s Content'].json['image_id']}}"
      }
    },
    {
      "name": "Post to Twitter/X",
      "type": "n8n-nodes-base.twitter",
      "parameters": {
        "operation": "tweet",
        "text": "={{$node['Get Today\\'s Content'].json['caption']}}\\n\\n#Wisdom #TheBookOfWisdom\\n\\nhttps://wisdombook.life",
        "attachments": "={{$node['Get Quote Image'].json['data']}}"
      }
    },
    {
      "name": "Post to Instagram",
      "type": "n8n-nodes-base.instagram",
      "parameters": {
        "operation": "post",
        "caption": "={{$node['Get Today\\'s Content'].json['caption']}}\\n\\n#Wisdom #TheBookOfWisdom #Philosophy\\n\\nLink in bio: wisdombook.life",
        "imageUrl": "={{$node['Get Quote Image'].json['webContentLink']}}"
      }
    },
    {
      "name": "Post to LinkedIn",
      "type": "n8n-nodes-base.linkedIn",
      "parameters": {
        "operation": "post",
        "text": "={{$node['Get Today\\'s Content'].json['linkedin_caption']}}\\n\\nExplore more: https://wisdombook.life\\n\\n#Wisdom #Leadership",
        "imageUrl": "={{$node['Get Quote Image'].json['webContentLink']}}"
      }
    },
    {
      "name": "Post to Facebook",
      "type": "n8n-nodes-base.facebook",
      "parameters": {
        "operation": "post",
        "message": "={{$node['Get Today\\'s Content'].json['caption']}}\\n\\nVisit: https://wisdombook.life",
        "imageUrl": "={{$node['Get Quote Image'].json['webContentLink']}}"
      }
    },
    {
      "name": "Post to Pinterest",
      "type": "n8n-nodes-base.pinterest",
      "parameters": {
        "operation": "createPin",
        "boardId": "YOUR_BOARD_ID",
        "note": "={{$node['Get Today\\'s Content'].json['caption']}}",
        "imageUrl": "={{$node['Get Quote Image'].json['webContentLink']}}",
        "link": "https://wisdombook.life"
      }
    },
    {
      "name": "Log Success",
      "type": "n8n-nodes-base.postgres",
      "parameters": {
        "operation": "insert",
        "table": "post_log",
        "columns": "date,content_id,platforms,status",
        "values": "={{$today}},={{$node['Get Today\\'s Content'].json['id']}},all,success"
      }
    }
  ]
}
```

### Configuration Notes

1. **Google Sheets Setup**:
   - Create a "Content Calendar" sheet with columns:
     - Date
     - Content ID
     - Quote/Thought
     - Caption
     - LinkedIn Caption (professional tone)
     - Image ID (Google Drive)
     - Hashtags
     - Platforms (comma-separated)

2. **Image Storage**:
   - Store quote graphics in Google Drive
   - Reference by file ID in spreadsheet
   - Alternative: Use Cloudinary for better performance

3. **Platform-Specific Captions**:
   - Use different caption columns for different platforms
   - LinkedIn needs professional tone
   - Instagram needs more hashtags
   - Twitter needs brevity

---

## Workflow 2: Multi-Platform Cross-Poster

### Purpose

Post the same content to multiple platforms with platform-specific formatting.

### Trigger

- **Type**: Webhook
- **Method**: POST
- **Payload**: Content data

### Workflow Steps

```json
{
  "name": "Cross-Platform Poster",
  "nodes": [
    {
      "name": "Webhook Trigger",
      "type": "n8n-nodes-base.webhook",
      "parameters": {
        "path": "post-wisdom",
        "method": "POST",
        "responseMode": "lastNode"
      }
    },
    {
      "name": "Parse Content",
      "type": "n8n-nodes-base.set",
      "parameters": {
        "values": {
          "quote": "={{$json.body.quote}}",
          "imageUrl": "={{$json.body.imageUrl}}",
          "platforms": "={{$json.body.platforms.split(',')}}",
          "hashtags": "={{$json.body.hashtags}}"
        }
      }
    },
    {
      "name": "Check Platforms",
      "type": "n8n-nodes-base.switch",
      "parameters": {
        "dataPropertyName": "platforms",
        "rules": {
          "rules": [
            {
              "value": "twitter",
              "output": 0
            },
            {
              "value": "instagram",
              "output": 1
            },
            {
              "value": "linkedin",
              "output": 2
            },
            {
              "value": "facebook",
              "output": 3
            },
            {
              "value": "all",
              "output": 4
            }
          ]
        }
      }
    },
    {
      "name": "Format for Twitter",
      "type": "n8n-nodes-base.function",
      "parameters": {
        "functionCode": "const quote = $input.item.json.quote;\\nconst hashtags = $input.item.json.hashtags;\\nconst maxLength = 280 - 30; // Reserve space for link\\n\\nlet text = quote;\\nif (text.length > maxLength) {\\n  text = text.substring(0, maxLength - 3) + '...';\\n}\\n\\ntext += '\\\\n\\\\n' + hashtags + '\\\\n\\\\nhttps://wisdombook.life';\\n\\nreturn {\\n  json: {\\n    text: text,\\n    imageUrl: $input.item.json.imageUrl\\n  }\\n};"
      }
    },
    {
      "name": "Format for Instagram",
      "type": "n8n-nodes-base.function",
      "parameters": {
        "functionCode": "const quote = $input.item.json.quote;\\nconst hashtags = $input.item.json.hashtags;\\n\\nconst caption = quote + '\\\\n\\\\n' + hashtags + '\\\\n\\\\nLink in bio: wisdombook.life';\\n\\nreturn {\\n  json: {\\n    caption: caption,\\n    imageUrl: $input.item.json.imageUrl\\n  }\\n};"
      }
    },
    {
      "name": "Format for LinkedIn",
      "type": "n8n-nodes-base.function",
      "parameters": {
        "functionCode": "const quote = $input.item.json.quote;\\n\\n// More professional tone for LinkedIn\\nconst text = quote + '\\\\n\\\\nExplore more wisdom and insights at The Book of Wisdom.\\\\n\\\\nhttps://wisdombook.life\\\\n\\\\n#Wisdom #Leadership #PersonalDevelopment';\\n\\nreturn {\\n  json: {\\n    text: text,\\n    imageUrl: $input.item.json.imageUrl\\n  }\\n};"
      }
    },
    {
      "name": "Post to All Platforms",
      "type": "n8n-nodes-base.merge",
      "parameters": {
        "mode": "mergeByPosition"
      }
    }
  ]
}
```

### Usage

**Trigger via HTTP Request**:

```bash
curl -X POST https://your-n8n-instance.com/webhook/post-wisdom \\
  -H "Content-Type: application/json" \\
  -d '{
    "quote": "Wisdom is not a product of schooling but of the lifelong attempt to acquire it.",
    "imageUrl": "https://drive.google.com/file/d/YOUR_FILE_ID",
    "platforms": "twitter,instagram,linkedin,facebook",
    "hashtags": "#Wisdom #Philosophy #TheBookOfWisdom"
  }'
```

---

## Workflow 3: Content Calendar Scheduler

### Purpose

Schedule posts for the entire week/month based on content calendar.

### Trigger

- **Type**: Manual / Weekly Schedule
- **Frequency**: Every Sunday at 6:00 PM EST

### Workflow Steps

```json
{
  "name": "Weekly Content Scheduler",
  "nodes": [
    {
      "name": "Schedule Trigger",
      "type": "n8n-nodes-base.scheduleTrigger",
      "parameters": {
        "rule": {
          "interval": [
            {
              "field": "cronExpression",
              "expression": "0 18 * * 0"
            }
          ]
        },
        "timezone": "America/New_York"
      }
    },
    {
      "name": "Get Next Week's Content",
      "type": "n8n-nodes-base.googleSheets",
      "parameters": {
        "operation": "read",
        "sheetId": "YOUR_SHEET_ID",
        "range": "Content Calendar!A:J",
        "filters": {
          "dateRange": "next_7_days"
        }
      }
    },
    {
      "name": "Loop Through Posts",
      "type": "n8n-nodes-base.splitInBatches",
      "parameters": {
        "batchSize": 1
      }
    },
    {
      "name": "Schedule Individual Post",
      "type": "n8n-nodes-base.httpRequest",
      "parameters": {
        "method": "POST",
        "url": "https://your-n8n-instance.com/webhook/schedule-post",
        "body": {
          "date": "={{$json.date}}",
          "time": "={{$json.time}}",
          "content": "={{$json.quote}}",
          "imageId": "={{$json.image_id}}",
          "platforms": "={{$json.platforms}}",
          "hashtags": "={{$json.hashtags}}"
        }
      }
    },
    {
      "name": "Log Scheduled Posts",
      "type": "n8n-nodes-base.postgres",
      "parameters": {
        "operation": "insert",
        "table": "scheduled_posts",
        "columns": "date,time,content_id,platforms,status",
        "values": "={{$json.date}},={{$json.time}},={{$json.content_id}},={{$json.platforms}},scheduled"
      }
    }
  ]
}
```

---

## Workflow 4: Platform-Specific Optimal Time Poster

### Purpose

Post to each platform at its optimal engagement time.

### Multiple Triggers

```json
{
  "name": "Optimal Time Multi-Platform Poster",
  "nodes": [
    {
      "name": "Twitter Morning Post",
      "type": "n8n-nodes-base.scheduleTrigger",
      "parameters": {
        "rule": {
          "interval": [
            {
              "field": "cronExpression",
              "expression": "0 8 * * *"
            }
          ]
        }
      }
    },
    {
      "name": "Instagram Lunch Post",
      "type": "n8n-nodes-base.scheduleTrigger",
      "parameters": {
        "rule": {
          "interval": [
            {
              "field": "cronExpression",
              "expression": "0 12 * * *"
            }
          ]
        }
      }
    },
    {
      "name": "LinkedIn Afternoon Post",
      "type": "n8n-nodes-base.scheduleTrigger",
      "parameters": {
        "rule": {
          "interval": [
            {
              "field": "cronExpression",
              "expression": "0 14 * * 2-4"
            }
          ]
        }
      }
    },
    {
      "name": "Twitter Evening Post",
      "type": "n8n-nodes-base.scheduleTrigger",
      "parameters": {
        "rule": {
          "interval": [
            {
              "field": "cronExpression",
              "expression": "0 18 * * *"
            }
          ]
        }
      }
    },
    {
      "name": "Get Content for Time Slot",
      "type": "n8n-nodes-base.googleSheets",
      "parameters": {
        "operation": "read",
        "sheetId": "YOUR_SHEET_ID",
        "range": "Content Calendar!A:J",
        "filters": {
          "date": "={{$today}}",
          "timeSlot": "={{$node.name}}"
        }
      }
    }
  ]
}
```

### Optimal Posting Times

**Based on Marketing Strategy**:

- **Twitter/X**: 8am, 12pm, 6pm EST
- **Instagram**: 11am, 2pm, 7pm EST
- **LinkedIn**: 8am, 12pm, 5pm EST (Tue-Thu best)
- **Facebook**: 9am, 1pm, 3pm EST
- **TikTok**: 6am, 10am, 10pm EST
- **Pinterest**: 2pm, 9pm EST

---

## Workflow 5: Engagement Monitor & Response

### Purpose

Monitor engagement across platforms and alert for high-performing posts or comments requiring response.

### Trigger

- **Type**: Schedule
- **Frequency**: Every 2 hours

### Workflow Steps

```json
{
  "name": "Engagement Monitor",
  "nodes": [
    {
      "name": "Schedule Trigger",
      "type": "n8n-nodes-base.scheduleTrigger",
      "parameters": {
        "rule": {
          "interval": [
            {
              "field": "hours",
              "hoursInterval": 2
            }
          ]
        }
      }
    },
    {
      "name": "Check Twitter Mentions",
      "type": "n8n-nodes-base.twitter",
      "parameters": {
        "operation": "search",
        "searchText": "@Quasauthor OR wisdombook.life",
        "returnAll": false,
        "limit": 50
      }
    },
    {
      "name": "Check Instagram Comments",
      "type": "n8n-nodes-base.instagram",
      "parameters": {
        "operation": "getComments",
        "mediaId": "recent"
      }
    },
    {
      "name": "Filter Unanswered",
      "type": "n8n-nodes-base.filter",
      "parameters": {
        "conditions": {
          "boolean": [
            {
              "value1": "={{$json.replied}}",
              "value2": false
            }
          ]
        }
      }
    },
    {
      "name": "Send Notification",
      "type": "n8n-nodes-base.emailSend",
      "parameters": {
        "toEmail": "your-email@example.com",
        "subject": "New Engagement on The Book of Wisdom",
        "text": "You have {{$json.length}} new mentions/comments requiring attention.\\n\\nCheck your social media platforms."
      }
    },
    {
      "name": "Log Engagement",
      "type": "n8n-nodes-base.postgres",
      "parameters": {
        "operation": "insert",
        "table": "engagement_log",
        "columns": "platform,type,content,timestamp,responded",
        "values": "={{$json.platform}},={{$json.type}},={{$json.content}},={{$now}},false"
      }
    }
  ]
}
```

---

## Workflow 6: Analytics Aggregator

### Purpose

Collect analytics from all platforms and compile into weekly report.

### Trigger

- **Type**: Schedule
- **Frequency**: Every Sunday at 8:00 PM EST

### Workflow Steps

```json
{
  "name": "Weekly Analytics Report",
  "nodes": [
    {
      "name": "Schedule Trigger",
      "type": "n8n-nodes-base.scheduleTrigger",
      "parameters": {
        "rule": {
          "interval": [
            {
              "field": "cronExpression",
              "expression": "0 20 * * 0"
            }
          ]
        }
      }
    },
    {
      "name": "Get Twitter Analytics",
      "type": "n8n-nodes-base.twitter",
      "parameters": {
        "operation": "getAnalytics",
        "dateRange": "last_7_days"
      }
    },
    {
      "name": "Get Instagram Insights",
      "type": "n8n-nodes-base.instagram",
      "parameters": {
        "operation": "getInsights",
        "metrics": "impressions,reach,engagement",
        "period": "week"
      }
    },
    {
      "name": "Get LinkedIn Analytics",
      "type": "n8n-nodes-base.linkedIn",
      "parameters": {
        "operation": "getAnalytics",
        "dateRange": "last_7_days"
      }
    },
    {
      "name": "Get Website Traffic",
      "type": "n8n-nodes-base.googleAnalytics",
      "parameters": {
        "operation": "getReport",
        "viewId": "YOUR_VIEW_ID",
        "dateRange": "last_7_days",
        "metrics": "sessions,users,pageviews",
        "dimensions": "source"
      }
    },
    {
      "name": "Compile Report",
      "type": "n8n-nodes-base.function",
      "parameters": {
        "functionCode": "const twitter = $node['Get Twitter Analytics'].json;\\nconst instagram = $node['Get Instagram Insights'].json;\\nconst linkedin = $node['Get LinkedIn Analytics'].json;\\nconst website = $node['Get Website Traffic'].json;\\n\\nconst report = {\\n  week: $today,\\n  twitter: {\\n    followers: twitter.followers,\\n    engagement: twitter.engagement_rate,\\n    topPost: twitter.top_post\\n  },\\n  instagram: {\\n    followers: instagram.followers,\\n    reach: instagram.reach,\\n    engagement: instagram.engagement\\n  },\\n  linkedin: {\\n    followers: linkedin.followers,\\n    impressions: linkedin.impressions\\n  },\\n  website: {\\n    sessions: website.sessions,\\n    users: website.users,\\n    socialTraffic: website.social_sessions\\n  },\\n  summary: `Week of ${$today}: ${website.users} website visitors, ${twitter.engagement + instagram.engagement} social engagements`\\n};\\n\\nreturn {\\n  json: report\\n};"
      }
    },
    {
      "name": "Save to Google Sheets",
      "type": "n8n-nodes-base.googleSheets",
      "parameters": {
        "operation": "append",
        "sheetId": "YOUR_ANALYTICS_SHEET_ID",
        "range": "Weekly Reports!A:Z",
        "values": "={{$json}}"
      }
    },
    {
      "name": "Email Report",
      "type": "n8n-nodes-base.emailSend",
      "parameters": {
        "toEmail": "your-email@example.com",
        "subject": "Weekly Analytics Report - The Book of Wisdom",
        "html": "<h2>Weekly Analytics Report</h2><p>={{$json.summary}}</p><h3>Details:</h3><pre>={{JSON.stringify($json, null, 2)}}</pre>"
      }
    }
  ]
}
```

---

## Content Calendar Template (Google Sheets)

### Sheet Structure

| Column | Header | Description | Example |
|--------|--------|-------------|---------|
| A | Date | Post date | 2026-02-05 |
| B | Time | Post time | 08:00 |
| C | Day | Day of week | Wednesday |
| D | Content Type | Type of post | Quote |
| E | Quote/Thought | Main content | "Wisdom begins in wonder." |
| F | Source | Attribution | Socrates |
| G | Caption | General caption | Wisdom begins in wonder. - Socrates |
| H | LinkedIn Caption | Professional version | As Socrates wisely noted... |
| I | Hashtags | Hashtags to use | #Wisdom #Philosophy #Socrates |
| J | Image ID | Google Drive ID | 1abc123def456 |
| K | Platforms | Target platforms | twitter,instagram,linkedin |
| L | Status | Post status | scheduled/posted/failed |
| M | Engagement | Total engagement | 245 |
| N | Notes | Additional notes | High performer |

### Sample Rows

```
Date       | Time  | Day       | Type  | Quote                                    | Source    | Caption                                  | LinkedIn Caption                         | Hashtags                    | Image ID      | Platforms                  | Status    |
-----------|-------|-----------|-------|------------------------------------------|-----------|------------------------------------------|------------------------------------------|-----------------------------|---------------|----------------------------|-----------|
2026-02-05 | 08:00 | Wednesday | Quote | Wisdom begins in wonder.                 | Socrates  | Wisdom begins in wonder. - Socrates      | As Socrates wisely noted...              | #Wisdom #Philosophy         | 1abc123def456 | twitter,instagram,linkedin | scheduled |
2026-02-05 | 12:00 | Wednesday | Thought| The pursuit of truth requires humility.  | Original  | The pursuit of truth requires humility.  | In leadership and life...                | #Wisdom #Truth #Leadership  | 1def456ghi789 | linkedin,facebook          | scheduled |
2026-02-05 | 18:00 | Wednesday | Quote | Know thyself.                            | Socrates  | Know thyself. - Socrates                 | Self-awareness is the foundation...      | #Wisdom #SelfAwareness      | 1ghi789jkl012 | twitter,instagram          | scheduled |
```

---

## Setup Instructions

### Step 1: Install n8n

**Self-Hosted**:

```bash
npm install -g n8n
n8n start
```

**Docker**:

```bash
docker run -it --rm \\
  --name n8n \\
  -p 5678:5678 \\
  -v ~/.n8n:/home/node/.n8n \\
  n8nio/n8n
```

**Cloud**: Use n8n.cloud for hosted solution

### Step 2: Connect Social Media Accounts

1. Go to **Credentials** in n8n
2. Add credentials for each platform:
   - Twitter/X API (OAuth 2.0)
   - Instagram Business API (via Facebook)
   - LinkedIn API
   - Facebook Graph API
   - Pinterest API
   - YouTube Data API
   - Google Sheets API
   - Google Drive API

### Step 3: Create Content Calendar

1. Create Google Sheet with template structure above
2. Populate with first week's content
3. Get Sheet ID from URL
4. Share sheet with n8n service account

### Step 4: Import Workflows

1. Copy workflow JSON from this document
2. In n8n, go to **Workflows** → **Import from File/URL**
3. Paste JSON and import
4. Update credentials and IDs
5. Activate workflow

### Step 5: Test Workflows

1. Start with manual trigger
2. Test one platform at a time
3. Verify posts appear correctly
4. Check analytics logging
5. Activate automated schedules

---

## Alternative Platforms (HTTP Requests)

For platforms without native n8n nodes, use HTTP Request node with their APIs:

### GETTR API

```json
{
  "name": "Post to GETTR",
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "method": "POST",
    "url": "https://api.gettr.com/v1/post",
    "authentication": "genericCredentialType",
    "headers": {
      "Authorization": "Bearer {{$credentials.gettr.token}}"
    },
    "body": {
      "text": "={{$json.caption}}",
      "imageUrl": "={{$json.imageUrl}}"
    }
  }
}
```

### GAB API

```json
{
  "name": "Post to GAB",
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "method": "POST",
    "url": "https://api.gab.com/v1/statuses",
    "authentication": "genericCredentialType",
    "headers": {
      "Authorization": "Bearer {{$credentials.gab.token}}"
    },
    "body": {
      "status": "={{$json.caption}}",
      "media_ids": ["={{$json.mediaId}}"]
    }
  }
}
```

### Bluesky API

```json
{
  "name": "Post to Bluesky",
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "method": "POST",
    "url": "https://bsky.social/xrpc/com.atproto.repo.createRecord",
    "authentication": "genericCredentialType",
    "headers": {
      "Authorization": "Bearer {{$credentials.bluesky.token}}"
    },
    "body": {
      "repo": "quasaur.bsky.social",
      "collection": "app.bsky.feed.post",
      "record": {
        "text": "={{$json.caption}}",
        "createdAt": "={{$now}}"
      }
    }
  }
}
```

---

## Monitoring & Maintenance

### Daily Checks

- Review failed posts in logs
- Check engagement notifications
- Respond to comments/mentions

### Weekly Tasks

- Review analytics report
- Adjust content calendar
- Update quote graphics
- Plan next week's content

### Monthly Tasks

- Comprehensive analytics review
- Strategy adjustments
- Platform performance comparison
- Content performance analysis

---

## Troubleshooting

### Common Issues

**1. Authentication Failures**

- Refresh OAuth tokens
- Check API rate limits
- Verify credential permissions

**2. Failed Posts**

- Check image URLs are accessible
- Verify caption length limits
- Ensure hashtags are valid

**3. Scheduling Issues**

- Verify timezone settings
- Check cron expressions
- Ensure n8n is running

**4. Missing Analytics**

- Confirm API access
- Check date range parameters
- Verify metrics are available

---

## Cost Considerations

### n8n Pricing

- **Self-Hosted**: Free (server costs only)
- **n8n Cloud**: $20-50/month depending on executions

### API Costs

- Most social media APIs are free for basic usage
- Monitor rate limits to avoid paid tiers
- Google Sheets/Drive: Free for personal use

### Recommended Setup

- Start with n8n Cloud for ease
- Migrate to self-hosted if scaling
- Use free tiers of all APIs initially

---

## Next Steps

1. **Set up n8n instance** (cloud or self-hosted)
2. **Create content calendar** in Google Sheets
3. **Connect first 3 platforms** (Twitter, Instagram, LinkedIn)
4. **Import and test Workflow 1** (Daily Wisdom Post)
5. **Expand to remaining platforms** gradually
6. **Monitor and optimize** based on performance

---

**Ready to automate your marketing!** 🚀

Let me know if you need help with:

- Setting up specific platform APIs
- Creating the Google Sheets template
- Testing workflows
- Troubleshooting issues
