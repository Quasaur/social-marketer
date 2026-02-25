# Social Media API Developer Portals

Quick reference for obtaining API access for each V1 platform.

---

## X (Twitter)

**Portal**: <https://developer.x.com>

**Setup Process**:

1. Sign in with your X account (@Quasauthor)
2. Apply for developer access (if not already approved)
3. Create a **Project** → then create an **App** within it
4. In App Settings:
   - Enable **OAuth 2.0**
   - Set User Authentication:
     - Type: **Web App, Automated App or Bot**
     - Callback URL: `socialmarketer://oauth/callback`
     - Website URL: `https://wisdombook.life`
5. Copy **Client ID** (OAuth 2.0 uses this, not API Key)
6. Request elevated access if needed for media uploads

**Required Scopes**: `tweet.read`, `tweet.write`, `users.read`, `media.write`, `offline.access`

---

## Facebook

**Portal**: <https://developers.facebook.com>

**Setup Process**:

1. Sign in with your Facebook account (Quasauthor)
2. Create a new App → Select **Business** type → App name: **Social Marketer**
3. Add Products:
   - **Facebook Login for Business**
4. In Facebook Login Settings:
   - **Valid OAuth Redirect URIs**: `http://localhost:8989/oauth/callback`
   - ⚠️ Custom URL schemes (e.g. `socialmarketer://`) are **NOT SUPPORTED** by Facebook
   - Enable **Client OAuth login** and **Web OAuth login**
5. Use Cases → Add the **"Manage everything on your Page"** use case, which enables:
   - `pages_show_list` — required for `/me/accounts` to list pages
   - `pages_manage_posts`
   - `pages_read_engagement`
   - `business_management` — ⚠️ **CRITICAL**: required for pages managed via Meta Business Suite
6. Get **App ID** and **App Secret** from App Settings → Basic
7. After OAuth, the app **automatically** calls `/me/accounts` to discover your Facebook Page, retrieves the Page Access Token and Page ID, and stores them in Keychain

> ⚠️ During OAuth, Facebook will ask which **Businesses** to grant access to. You must select your business for `/me/accounts` to return your Pages.

**Graph API Version**: v24.0

**Required Scopes**: `pages_show_list`, `pages_manage_posts`, `pages_read_engagement`, `business_management`

**Redirect Flow**: Uses localhost HTTP server (same as LinkedIn) — the app starts a temporary server on port 8989 to receive the OAuth callback.

---

## Instagram

**Portal**: Same Meta app at <https://developers.facebook.com> → Use Cases

> ⚠️ **Key Discovery**: Although Instagram has its own App ID/Secret in the portal, in practice you should use the **same Facebook App credentials** for Instagram. The Instagram permissions are added as a use case on the same Facebook app.

| Field | Value |
| :---- | :---- |
| App ID | Same as Facebook App ID |
| App Secret | Same as Facebook App Secret |

**Setup Process**:

1. In the Facebook app on developers.facebook.com, go to Use Cases → Add **"Manage message & content on Instagram"**
2. Under Permissions & Features, add:
   - `instagram_basic` — read Instagram Business Account info
   - `instagram_content_publish` — **critical**: publish photos and videos
   - `pages_show_list` — list pages linked to the user
   - `pages_read_engagement` — read page engagement data
   - `business_management` — ⚠️ required for Business Suite pages
3. In Social Marketer: Setup Instagram → enter the **same App ID and App Secret** as Facebook
4. Click Connect → during OAuth, **select your Business** when prompted

**Required Scopes**: `instagram_basic`, `instagram_content_publish`, `pages_show_list`, `pages_read_engagement`, `business_management`

**Auto-Discovery**: After OAuth, the app automatically:

1. Calls `/me/accounts` to find the Facebook Page
2. Queries the Page's `instagram_business_account` edge to get the IG Business Account ID
3. Stores the Page Access Token and Business Account ID in Keychain

**Image Hosting**: Instagram API requires images at a public URL. The app handles this by uploading images to the Facebook Page as **unpublished photos** (hidden from feed) to get a Facebook CDN URL, then passes that URL to Instagram's container creation API.

**Redirect Flow**: Uses localhost HTTP server (port 8989), same as Facebook and LinkedIn.

---

## LinkedIn

**Portal**: <https://developer.linkedin.com>

**Setup Process**:

1. Sign in with your LinkedIn account (@quasaur)
2. Create a new App
3. Associate your **LinkedIn Page** (e.g. "The Book of Wisdom") → click **Verify** to confirm ownership
4. In **Auth** tab:
   - Add OAuth 2.0 Redirect URL: `http://localhost:8989/oauth/callback`
5. In **Products** tab:
   - Request access to **Share on LinkedIn** and **Sign In with LinkedIn using OpenID Connect**
   - This grants `w_member_social`, `openid`, `profile` scopes
6. Copy **Client ID** and **Client Secret**
7. Get your **Person URN** via API call after first auth

**Required Scopes**: `w_member_social`, `openid`, `profile`

**Redirect Flow**: Uses localhost HTTP server (same as Facebook) — the app starts a temporary server on port 8989 to receive the OAuth callback.

---

## Pinterest

**Portal**: <https://developers.pinterest.com>

**Setup Process**:

1. Sign in with your Pinterest account
2. Create a new App → App name: **Social Marketer**
3. In App Settings:
   - **Redirect URI**: `http://localhost:8989/oauth/callback`
   - ⚠️ Must use localhost - custom URL schemes not supported
4. Upgrade to Standard Access:
   - Click **"Upgrade access"** button
   - Select use cases:
     - ✅ **Pin creation & scheduling**
     - ✅ **Pinners**
     - ❌ Ad campaign management (uncheck this)
   - Upload demo video showing:
     - App interface
     - OAuth connection flow
     - Creating/scheduling a post
     - (Video can show trial access error with note "Pending approval")
   - Fill in app details
   - Submit for review
5. Copy **App ID** and **App Secret** from Settings

**Required Scopes**: `boards:read`, `boards:write`, `pins:read`, `pins:write`

> ⚠️ **OAuth Configuration**: Pinterest uses **Basic Authentication** for token exchange (not body parameters). Social Marketer automatically sends `Authorization: Basic [base64(client_id:client_secret)]` header.

**Trial Access Limitations**:

- Manual access tokens from "Generate Access Token" button only last 24 hours and have limited scopes
- Trial access can only use sandbox API (`api-sandbox.pinterest.com`), not production
- **OAuth flow works during trial**, but pins will fail with error about sandbox requirement
- After approval, OAuth automatically gets production access token

**Board Auto-Discovery**: After OAuth, the app automatically:

1. Fetches all boards from Pinterest API (`/v5/boards`)
2. Searches for boards containing "wisdom" (case-insensitive)
3. Falls back to boards containing "book"
4. Defaults to first available board
5. Stores Board ID and Name in Keychain

**Redirect Flow**: Uses localhost HTTP server (port 8989), same as Facebook, Instagram, and LinkedIn.

**Approval Time**: Typically 1-7 days after video demo submission

---

## YouTube

**Portal**: <https://console.cloud.google.com>

### Step-by-Step: Obtaining YouTube API Key for Video Shorts

Follow these detailed steps to enable Social Marketer to post Video Shorts to your YouTube channel.

#### Step 1: Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Sign in with your Google account (<devcalvinlm@gmail.com>)
3. Click the project selector dropdown at the top
4. Click **New Project**
5. Enter **Project name**: `Social Marketer`
6. Click **Create**
7. Wait for the project to be created, then select it from the dropdown

#### Step 2: Enable YouTube Data API v3

1. Go to **APIs & Services** → **Library** (left sidebar)
2. In the search bar, type: `YouTube Data API v3`
3. Click on **YouTube Data API v3** in the results
4. Click the **Enable** button
5. Wait for the API to be enabled (this may take a minute)

#### Step 3: Configure OAuth Consent Screen

1. Go to **APIs & Services** → **OAuth consent screen** (left sidebar)
2. Select **User type**: **External** (available to any test user)
3. Click **Create**
4. Fill in the **App information**:
   - **App name**: `Social Marketer`
   - **User support email**: <devcalvinlm@gmail.com>
   - **App logo** (optional): You can skip this
5. Fill in **Developer contact information**:
   - **Email addresses**: <quasaur@gmail.com>
6. Click **Save and Continue**
7. On **Scopes** screen, click **Add or Remove Scopes**
8. Find and select: `https://www.googleapis.com/auth/youtube.upload`
   - This scope allows uploading videos to YouTube
9. Click **Update**, then **Save and Continue**
10. On **Test users** screen, click **Add Users**
11. Add your email: <quasaur@gmail.com>
12. Click **Save and Continue**
13. Review the summary, then click **Back to Dashboard**

#### Step 4: Create OAuth 2.0 Client ID

1. Go to **APIs & Services** → **Credentials** (left sidebar)
2. Click **Create Credentials** (top button)
3. Select **OAuth client ID**
4. For **Application type**, select: **Desktop app**
5. Enter **Name**: `Social Marketer macOS App`
6. Click **Create**
7. A popup will show your **Client ID** and **Client Secret**
8. Click **Download JSON** to save the credentials file
9. Click **OK**

> ⚠️ **IMPORTANT**: You will only see the Client Secret once. If you lose it, you'll need to regenerate it.

#### Step 5: Configure Social Marketer

1. Open **Social Marketer** app
2. Go to **Platforms** tab
3. Find **YouTube** and click **Settings**
4. Enter:
   - **Client ID**: (from Step 4)
   - **Client Secret**: (from Step 4)
5. Click **Connect**
6. A browser window will open for OAuth authorization
7. Sign in with <quasaur@gmail.com>
8. Click **Allow** to grant permissions
9. The app will automatically receive the authorization code

> **Note on Connection State**: Once you've entered your YouTube API credentials, YouTube will show as "Connected" in the Platforms list. The button will display **"Disconnect"** to indicate the platform is ready for posting. OAuth tokens are managed automatically by the app when posting.

#### Step 6: Test YouTube Video Shorts Posting

1. In Social Marketer, ensure YouTube is **enabled** (toggle is ON)
2. Go to **Dashboard** → **Test Post** section
3. Click the **Test Post** button next to YouTube
4. The app will:
   - Fetch daily wisdom from RSS feed
   - Generate a quote graphic
   - Generate a video short using Social Effects
   - Upload the video to YouTube as a Short
5. Check your YouTube Studio to verify the Short was posted

### Video Shorts Specifications

When posting to YouTube, Social Marketer creates Shorts with these specifications:

| Property | Value |
|:---------|:------|
| **Aspect Ratio** | 9:16 (vertical) |
| **Resolution** | 1080 x 1920 pixels |
| **Duration** | 3 seconds (configurable) |
| **Frame Rate** | 30 fps |
| **Format** | MP4 (H.264) |
| **Hashtags** | #Shorts automatically added |

### Required Scope

`https://www.googleapis.com/auth/youtube.upload`

This scope allows the app to upload videos to your YouTube channel.

### Content Flow

```
RSS Feed → Wisdom Entry → Quote Graphic → Social Effects API → Video Short → YouTube Upload
```

The Social Effects service (running on localhost:5390) generates the video short, then YouTubeConnector uploads it via the YouTube Data API v3.

### API Endpoint

`POST https://www.googleapis.com/upload/youtube/v3/videos?uploadType=multipart&part=snippet,status`

### Redirect Flow

Uses localhost HTTP server (port 8989), same as other OAuth 2.0 platforms.

### Approval Time

- **Test Mode**: Instant (with test users configured)
- **Production**: Requires app verification for public use (not needed for personal use)

### Troubleshooting

| Issue | Solution |
|:------|:---------|
| "Access denied" error | Ensure <quasaur@gmail.com> is added as a test user in OAuth consent screen |
| "Invalid client" error | Verify Client ID and Client Secret are copied correctly |
| Video not appearing as Short | The #Shorts hashtag helps, but YouTube algorithm ultimately classifies it |
| Upload fails | Check that YouTube Data API v3 is enabled and not quota exceeded |

---

## TikTok

**Portal**: <https://developers.tiktok.com/>

> ⚠️ **Important**: TikTok requires **separate approval** for the Content Posting API. Standard developer access does NOT include video posting capabilities.

### Step-by-Step: Obtaining TikTok API Access

#### Step 1: Apply for TikTok for Developers Access

1. Go to [TikTok for Developers](https://developers.tiktok.com/)
2. Sign in with your TikTok account
3. Click **"My Apps"** → **"Connect an app"**
4. Fill out the application form:
   - **App Name**: Social Marketer
   - **App Category**: Content Management / Social Media
   - **Use Case**: Content Publishing Automation
   - **Website**: https://wisdombook.life
   - **Privacy Policy**: https://wisdombook.life/privacy
   - **Terms of Service**: https://wisdombook.life/terms
5. Submit the application and wait for approval (typically 1-3 business days)

> **Platform Selection**: When configuring your app, select **Desktop** as the platform type (Social Marketer is a macOS desktop application).

#### Step 2: Request Content Posting API Access

Once your basic app is approved, you must apply separately for video posting:

1. In your app dashboard, go to **"Products"**
2. Find **"Content Posting"** and click **"Apply"**
3. Provide detailed information:
   - **Business Justification**: Automated distribution of educational/inspirational content
   - **Expected Volume**: ~1-5 videos per day (be conservative)
   - **Content Types**: Educational videos, inspirational quotes, wisdom content
   - **Use Case Description**: "Social Marketer automatically posts daily wisdom content from The Book of Wisdom to help users share meaningful insights with their audience"
4. Submit and wait for approval (1-5 business days)

#### Step 3: Configure Platform Settings (Desktop)

Since you selected **Desktop** as the platform, configure these required URLs:

| Field | Value | Description |
|:------|:------|:------------|
| **Desktop URL** | `https://wisdombook.life` | Your app's website/landing page |
| **Privacy Policy URL** | `https://wisdombook.life/privacy` | Required for all apps |
| **Terms of Service URL** | `https://wisdombook.life/terms` | Required for all apps |

> ⚠️ **Note**: The Desktop URL is required even though this is a native macOS app. Use your primary website (wisdombook.life) as the Desktop URL.

#### Step 4: Verify URL Ownership (CRITICAL)

TikTok requires you to **prove ownership** of all URLs before they can be used. You must complete this step or the URLs will show "This URL is not verified" error.

**Recommended: Domain Verification (verifies all URLs at once)**

1. Click the **"URL properties"** button at the top of your app page
2. Ensure you're in **Production mode**
3. Click **"Verify properties"**
4. Select **"Domain"** as Property Type
5. Enter: `wisdombook.life` (just the domain, no https://)
6. Click **Verify** — TikTok will generate a DNS TXT record for you

**Add the DNS TXT Record to GoDaddy:**

1. Log in to your [GoDaddy Account](https://account.godaddy.com/)
2. Go to **"My Products"** → Find your domain (wisdombook.life)
3. Click **"DNS"** (or "Manage DNS")
4. Click **"Add"** or **"Add Record"**
5. Fill in the record details:
   | Field | Value |
   |:------|:------|
   | **Type** | TXT |
   | **Name** | @ (or leave blank) |
   | **Value** | (paste the TXT value from TikTok, e.g., `tiktok-verification=abc123xyz`) |
   | **TTL** | 1 Hour (or default) |
6. Click **"Save"**
7. Wait 5-30 minutes for DNS propagation
8. Return to TikTok portal and click **"Verify"**

**Alternative: URL Prefix Verification**

If you prefer not to modify DNS:
1. Select **"URL prefix"** in TikTok
2. Enter the full URL (e.g., `https://wisdombook.life`)
3. Download the signature file
4. Upload to your website's root directory
5. Repeat for each URL path (/privacy, /terms)

> ✅ **Domain verification is recommended** — one DNS record verifies ALL three URLs (Desktop, Privacy Policy, Terms of Service) simultaneously.

#### Step 5: Configure OAuth Settings

1. In your app dashboard, go to **"Auth"** tab
2. Add OAuth 2.0 Redirect URI:
   ```
   http://localhost:9095/oauth/callback
   ```
3. Enable PKCE (Proof Key for Code Exchange) - TikTok requires this for security
4. Save your **Client Key** and **Client Secret**

#### Step 6: Configure Social Marketer

1. Open **Social Marketer** app
2. Go to **Platforms** tab
3. Find **TikTok** and click **Settings**
4. Enter:
   - **Client Key**: (from Step 5)
   - **Client Secret**: (from Step 5)
5. Click **Connect**
6. A browser window will open for OAuth authorization
7. Sign in with your TikTok account
8. Click **Allow** to grant permissions
9. The app will automatically receive the authorization code and complete authentication

#### Step 7: Test TikTok Video Posting

1. In Social Marketer, ensure TikTok is **enabled** (toggle is ON)
2. Go to **Platform Settings** → **TikTok**
3. Click the **Test Video** button
4. The app will:
   - Fetch daily wisdom from the Post Queue
   - Generate a video short using Social Effects
   - Upload the video to TikTok
5. Check your TikTok profile to verify the video was posted

### TikTok Video Specifications

| Property | Value |
|:---------|:------|
| **Aspect Ratio** | 9:16 (vertical) |
| **Resolution** | 1080 x 1920 pixels |
| **Duration** | 15-60 seconds recommended |
| **Format** | MP4 (H.264) |
| **Max File Size** | 287.6 MB (iOS), 72 MB (Android) |
| **Hashtags** | Auto-generated based on content |

### Required Scopes

- `video.upload` - Upload videos to TikTok
- `video.publish` - Publish videos to TikTok
- `user.info.basic` - Access basic user information

### API Endpoint

`POST https://open.tiktokapis.com/v2/post/publish/video/init/`

### Content Flow

```
RSS Feed → Wisdom Entry → Social Effects API → Video Short → TikTok Upload API → TikTok
```

### Redirect Flow

Uses localhost HTTP server on port 9095 with PKCE (Proof Key for Code Exchange) for enhanced security.

### Approval Time

| Stage | Time |
|:------|:-----|
| Basic Developer Access | 1-3 business days |
| Content Posting API Access | 1-5 business days |
| **Total** | **2-8 business days** |

### Known Limitations

| Feature | Status | Notes |
|:--------|:-------|:------|
| Video Upload | ✅ Available | Via Content Posting API |
| Photo Upload | ❌ Not Available | TikTok is video-first platform |
| Text Posts | ❌ Not Available | Not supported |
| Scheduling | ⚠️ Partial | Post immediately only |
| Caption Length | ⚠️ Limited | 2200 characters max (recommend <1000) |

### Media Type Preference

TikTok respects Social Marketer's **Platform Media Preferences** setting:

| Preference | Behavior |
|:-----------|:---------|
| **Video** (default) | ✅ Posts video content to TikTok |
| **Image** | ⏭️ TikTok is **skipped** during posting (logged as "video only") |

> **Note**: TikTok currently only supports video uploads. If you set the media preference to "Image" in Settings → Platform Media Preferences → TikTok, the platform will be automatically skipped during scheduled posting and the Post Queue processing will continue with other enabled platforms.

### Troubleshooting

| Issue | Solution |
|:------|:---------|
| "Content Posting API not approved" | Apply separately for Content Posting product |
| "Invalid redirect URI" | Ensure exact match including trailing slash |
| "PKCE verification failed" | This is handled automatically by Social Marketer |
| Video stuck processing | Known Meta-side issue - see community forums |
| "Access denied" | Ensure your TikTok account is in good standing |

---

## Summary Table

| Platform | Portal | Key Credentials | Approval Time |
|:---------|:-------|:----------------|:--------------|
| X (Twitter) | developer.twitter.com | Client ID | Instant - 48h |
| Facebook | developers.facebook.com | App ID, App Secret | 1-5 days |
| Instagram | developers.facebook.com (Instagram API) | Instagram App ID, Instagram App Secret | Requires app review |
| LinkedIn | developer.linkedin.com | Client ID, Client Secret | Instant - 24h |
| Pinterest | developers.pinterest.com | App ID, App Secret | 1-7 days |
| YouTube | console.cloud.google.com | Client ID, Client Secret | Instant (test mode) |
| TikTok | developers.tiktok.com | Client Key, Client Secret | 2-8 days (Content Posting API) |

---

## Next Steps

After obtaining credentials:

1. Store Client IDs/Secrets securely (do NOT commit to Git)
2. Use the **Platforms** tab in Social Marketer to connect each account
3. Test with a single post before enabling automated scheduling
