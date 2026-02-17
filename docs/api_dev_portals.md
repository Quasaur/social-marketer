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

**Setup Process**:

1. Sign in with your Google account (<quasaur@gmail.com>)
2. Create a new **Google Cloud Project** → Project name: **Social Marketer**
3. Enable **YouTube Data API v3**:
   - Go to **APIs & Services** → **Library**
   - Search for "YouTube Data API v3"
   - Click **Enable**
4. Configure **OAuth consent screen**:
   - Go to **APIs & Services** → **OAuth consent screen**
   - User type: **External** (for testing)
   - App name: **Social Marketer**
   - User support email: <quasaur@gmail.com>
   - Developer contact: <quasaur@gmail.com>
   - **Scopes**: Add `https://www.googleapis.com/auth/youtube.upload`
   - **Test users**: Add <quasaur@gmail.com>
5. Create **OAuth 2.0 Client ID**:
   - Go to **APIs & Services** → **Credentials**
   - Click **Create Credentials** → **OAuth client ID**
   - Application type: **Desktop app** (or **Web application** with localhost redirect)
   - Authorized redirect URIs: `http://localhost:8989/oauth/callback`
   - Copy **Client ID** and **Client Secret**

**Required Scope**: `https://www.googleapis.com/auth/youtube.upload`

**Content Format**: YouTube requires video files. The app automatically converts static images into short videos (3-second MP4 at 30fps) using AVFoundation before upload.

**Upload Endpoint**: `POST https://www.googleapis.com/upload/youtube/v3/videos?uploadType=multipart&part=snippet,status`

**Redirect Flow**: Uses localhost HTTP server (port 8989), same as other OAuth 2.0 platforms.

**Approval Time**: Instant for testing mode with test users configured

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

---

## Next Steps

After obtaining credentials:

1. Store Client IDs/Secrets securely (do NOT commit to Git)
2. Use the **Platforms** tab in Social Marketer to connect each account
3. Test with a single post before enabling automated scheduling
