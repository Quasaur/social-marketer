# Social Media API Developer Portals

Quick reference for obtaining API access for each V1 platform.

---

## X (Twitter)

**Portal**: <https://developer.twitter.com>

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

**Required Scopes**: `tweet.read`, `tweet.write`, `users.read`, `offline.access`

---

## Facebook & Instagram

**Portal**: <https://developers.facebook.com>

**Setup Process**:

1. Sign in with your Facebook account
2. Create a new App → Select **Business** type
3. Add Products:
   - **Facebook Login for Business**
   - **Instagram Graph API**
4. In Facebook Login Settings:
   - Valid OAuth Redirect URIs: `socialmarketer://oauth/callback`
5. Go to App Review → Request permissions:
   - `pages_manage_posts`
   - `pages_read_engagement`
   - `instagram_basic`
   - `instagram_content_publish`
6. Complete Business Verification (required for Instagram publishing)
7. Get **Page ID** from your Wisdom Book Facebook Page settings
8. Get **Instagram Business Account ID** by linking IG to the Page

**Note**: One Facebook app covers both Facebook and Instagram.

---

## LinkedIn

**Portal**: <https://developer.linkedin.com>

**Setup Process**:

1. Sign in with your LinkedIn account (@quasaur)
2. Create a new App
3. Fill in company details (can use personal page)
4. In **Auth** tab:
   - Add OAuth 2.0 Redirect URL: `socialmarketer://oauth/callback`
5. In **Products** tab:
   - Request access to **Share on LinkedIn**
   - This grants `w_member_social` scope
6. Copy **Client ID** and **Client Secret**
7. Get your **Person URN** via API call after first auth

**Required Scopes**: `w_member_social`, `openid`, `profile`

---

## Pinterest

**Portal**: <https://developers.pinterest.com>

**Setup Process**:

1. Sign in with your Pinterest account
2. Create a new App
3. Fill in app details and set:
   - Redirect URI: `socialmarketer://oauth/callback`
4. Request access to:
   - **pins:write** (create pins)
   - **boards:read** (list boards for selection)
5. Submit for review (Pinterest reviews all apps)
6. Copy **App ID** and **App Secret**
7. Get your **Board ID** from the board URL or API

**Required Scopes**: `pins:write`, `boards:read`

---

## Summary Table

| Platform | Portal | Key Credentials | Approval Time |
|:---------|:-------|:----------------|:--------------|
| X (Twitter) | developer.twitter.com | Client ID | Instant - 48h |
| Facebook/Instagram | developers.facebook.com | App ID, App Secret | 1-5 days |
| LinkedIn | developer.linkedin.com | Client ID, Client Secret | Instant - 24h |
| Pinterest | developers.pinterest.com | App ID, App Secret | 1-7 days |

---

## Next Steps

After obtaining credentials:

1. Store Client IDs/Secrets securely (do NOT commit to Git)
2. Use the **Platforms** tab in Social Marketer to connect each account
3. Test with a single post before enabling automated scheduling
