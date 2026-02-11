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

**Redirect Flow**: Uses localhost HTTP server (same as LinkedIn) — the app starts a temporary server on port 8989 to receive the OAuth callback.

---

## Instagram

**Portal**: Same Meta app at <https://developers.facebook.com> → Use Cases → **Instagram API**

**Key Discovery**: Instagram has its **own separate App ID & Secret**, distinct from the Facebook App credentials.

| Field | Value |
|:------|:------|
| Instagram app name | Social Marketer-IG |
| Instagram app ID | `924177070063303` |
| Instagram app secret | *(stored in Keychain)* |

**Setup Process**:

1. In the same Meta app, go to Use Cases → Add **Instagram API**
2. Choose **API setup with Instagram login**
3. Required permissions:
   - `instagram_business_basic`
   - `instagram_manage_comments`
   - `instagram_business_manage_messages`
4. Generate access tokens → Add your Instagram account (assign **Instagram Tester** role in Roles tab first)
5. Optionally set up **Instagram business login** (step 4 in the portal)
6. Submit for **App review** before accessing live data

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
| Facebook | developers.facebook.com | App ID, App Secret | 1-5 days |
| Instagram | developers.facebook.com (Instagram API) | Instagram App ID, Instagram App Secret | Requires app review |
| LinkedIn | developer.linkedin.com | Client ID, Client Secret | Instant - 24h |
| Pinterest | developers.pinterest.com | App ID, App Secret | 1-7 days |

---

## Next Steps

After obtaining credentials:

1. Store Client IDs/Secrets securely (do NOT commit to Git)
2. Use the **Platforms** tab in Social Marketer to connect each account
3. Test with a single post before enabling automated scheduling
