# Oktan Web — your setup steps (phase 0)

About 30–40 minutes, done once. Do the parts **in order**: part 1 gives you the address that part 3 needs,
and part 3 produces the keys that part 4 needs.

**Never paste a password, client secret or JSON key into the chat.** Secrets go directly from Google into
Cloudflare (part 4), or from a file into a terminal command (later, phase 2). When you finish, you send me
four things, none of them secret (see "What to send me" at the end).

Menus get renamed now and then. If a label doesn't match exactly, use the search box at the top of the
Google Cloud or Cloudflare dashboard and type the name in **bold**.

Already done: ✅ `npx wrangler login` (Cloudflare account `161fc91b…`, the one that owns `ustunfatih.com`).

---

## Part 1 — Turn on Cloudflare Zero Trust and pick a team name (5 min)

This creates your private login page, `https://<team-name>.cloudflareaccess.com`.

1. Open <https://dash.cloudflare.com> and sign in as usual.
2. In the left sidebar click **Zero Trust**. If you don't see it, use the search box at the top and search
   "Zero Trust".
3. The first time, Cloudflare asks you to **choose a team name**. Type something short, lowercase, no
   spaces, e.g. `ustunfatih`. Your team domain becomes `ustunfatih.cloudflareaccess.com`.
   → **Write down the team domain.** Every place below that says `<team>` means this name.
4. Choose the **Free** plan (up to 50 users, $0). Cloudflare may ask for a payment method even for the
   free plan; that's normal, nothing is charged on Free.
5. Finish the onboarding wizard. You can skip the steps about installing the WARP device client: we don't
   need it. Access works in any browser.

✅ Done when: you're in the Zero Trust dashboard, and the team domain shows under **Settings → Team name
and domain** (or **Settings → Custom pages**, depending on the layout version).

---

## Part 2 — Google Cloud project, Sheets access and the service account (10–15 min)

The service account is a robot Google user that the web app uses to read and write your sheet. It never
logs in as you.

### 2a. Create a project

1. Open <https://console.cloud.google.com> signed in as **ustunfa@gmail.com**.
2. Click the project picker at the top left (next to "Google Cloud") → **New project**.
3. Project name: `oktan-web`. Location: *No organization*. Click **Create**.
4. Wait for the notification, then make sure `oktan-web` is selected in the project picker.

### 2b. Enable the Google Sheets API

1. Left menu (☰) → **APIs & Services** → **Library**.
2. Search **Google Sheets API** → open it → **Enable**.

### 2c. Create the service account

1. Left menu → **IAM & Admin** → **Service Accounts** → **+ Create service account**.
2. Service account name: `oktan-sheets`. The ID fills itself in. Description: `Oktan web app — reads and
   writes the fuel sheet`.
3. Click **Create and continue**. On "Grant this service account access to project", **skip** (no roles
   needed) → **Continue** → **Done**.
4. You're back on the list. **Copy the email** of the new account. It looks like
   `oktan-sheets@oktan-web.iam.gserviceaccount.com` (yours may have a number in it).
   → **Write it down.**

### 2d. Create its key (a JSON file)

1. Click the `oktan-sheets` account → **Keys** tab → **Add key** → **Create new key** → **JSON** →
   **Create**.
2. A `.json` file downloads. **This file is a password.** Move it somewhere **outside** the project
   folder, for example:
   ```bash
   mkdir -p ~/Secrets && mv ~/Downloads/oktan-web-*.json ~/Secrets/oktan-sa.json && chmod 600 ~/Secrets/oktan-sa.json
   ```
3. Don't email it, don't put it in iCloud/Drive/git, and don't paste it into the chat. In phase 2 you'll run
   one command that loads it into Cloudflare.

> If Google says key creation is disabled by an organization policy, tell me. That only happens on
> Workspace/organization accounts, not on a personal Gmail project.

### 2e. Share both sheets with the service account

Do this for **both** files:

- [Qatar Fuel Tracking 2026](https://docs.google.com/spreadsheets/d/1Gk9BvaD4bYf9Q3ss-v09Ezr64XrFd9MCMPSMYUEh9P8/edit) (the real one)
- [Oktan DEV](https://docs.google.com/spreadsheets/d/1MJUHs2YSOssKJBL3neTz7zXSvzrm2ll4dIMJtgvYf58/edit) (the copy I build and test against)

1. Open the sheet → **Share** (top right).
2. Paste the service account email from 2c.
3. Set the role to **Editor**.
4. **Untick "Notify people"** (the robot has no inbox) → **Share**. If Google warns that the address is
   outside your organization or can't receive mail, click **Share anyway**.

✅ Done when: both sheets list `oktan-sheets@…` as Editor under Share.

---

## Part 3 — Google login for the website: OAuth client (5–10 min)

This lets Cloudflare show "Sign in with Google" and tells it who you are. Still in the `oktan-web`
project.

### 3a. Consent screen (what Google shows when you log in)

1. Left menu → **APIs & Services** → **OAuth consent screen**. Newer consoles call this section
   **Google Auth Platform**; click **Get started** if asked.
2. **App information:** App name `Oktan`; User support email `ustunfa@gmail.com` → **Next**.
3. **Audience:** **External** → **Next**.
4. **Contact information:** `ustunfa@gmail.com` → **Next** → tick "I agree…" → **Continue / Create**.
5. Don't add any scopes. Cloudflare only asks for your basic profile and email, which need no Google
   review.
6. Go to **Audience** (Google Auth Platform) or the consent screen summary → **Publish app** →
   **Confirm**, so the status says **In production**.
   *Why:* in "Testing" status Google adds warnings and limits; with only basic sign-in scopes, publishing
   needs no verification.

### 3b. Create the OAuth client

1. **APIs & Services** → **Credentials** → **+ Create credentials** → **OAuth client ID**
   (Google Auth Platform: **Clients** → **+ Create client**).
2. Application type: **Web application**. Name: `Cloudflare Access`.
3. **Authorized JavaScript origins** → **+ Add URI** →
   `https://<team>.cloudflareaccess.com` (e.g. `https://ustunfatih.cloudflareaccess.com`)
4. **Authorized redirect URIs** → **+ Add URI** →
   `https://<team>.cloudflareaccess.com/cdn-cgi/access/callback`
5. **Create**. A dialog shows the **Client ID** and **Client secret**.
   - Keep this tab open for part 4, or click **Download JSON** and store it in `~/Secrets/`.
   - New Google consoles show the secret **only once**. If you lose it, open the client and **Add
     secret** to get a new one.

✅ Done when: you have a Client ID (ends in `.apps.googleusercontent.com`) and a Client secret.

---

## Part 4 — Add Google as a login method in Cloudflare (3 min)

1. Back in **Cloudflare Zero Trust** → **Integrations** → **Identity providers**. Older layout:
   **Settings → Authentication → Login methods**.
2. **Add new** (or **Add an identity provider**) → **Google**.
3. Name: `Google`.
   **App ID** ← paste the **Client ID** from 3b.
   **Client secret** ← paste the **Client secret** from 3b.
   Leave PKCE and the other options at their defaults.
4. **Save**.
5. Next to the new Google entry, click **Test**. A Google sign-in opens: choose `ustunfa@gmail.com`. You
   should see a green **"Your connection works!"** page that lists your email.
   - Error `redirect_uri_mismatch` → the redirect URI in 3b has a typo or a different team name. Fix it
     in Google, wait a minute, test again.
   - Error `access_denied` / "app not verified" → go back to 3a step 6 and make sure the app is **In
     production**.

✅ Done when: the Test page shows your email.

---

## Part 5 — Protect `oktan.ustunfatih.com` (5 min)

This puts the login wall in front of the site **before** the site exists, so it's protected from its
first second online.

1. Zero Trust → **Access controls** → **Applications**. Older layout: **Access → Applications**.
2. **Add an application** → **Self-hosted**.
3. **Basic information**
   - Application name: `Oktan`
   - Session duration: **1 month** (so you aren't asked to log in again at the pump)
4. **Destinations / Public hostname** → **+ Add public hostname**:
   - Subdomain: `oktan`
   - Domain: pick `ustunfatih.com` from the list
   - Path: leave empty (protects the whole site, API included)
5. **Access policies** → **Create new policy** (or **Add a policy**):
   - Policy name: `Only Fatih`
   - Action: **Allow**
   - Session duration: *Same as application session timeout*
   - **Add include** → Selector **Emails** → Value `ustunfa@gmail.com`
   - Leave "Require" and "Exclude" empty → **Save** the policy, then make sure it's attached to the
     application.
6. **Login methods**
   - Untick **Accept all available identity providers**.
   - Tick **Google** only. If "Cloudflare" or "One-time PIN" appear, leave them unticked.
   - Turn on **Instant Auth** ("Skip identity provider selection when only one login method is
     available"). The Google sign-in then opens straight away.
7. Leave the other sections at their defaults (App Launcher, Block page, CORS, cookie settings).
   **Save** / **Add application**.
8. Open the new **Oktan** application → **Overview** (or **Settings → Additional settings**) → copy the
   **Application Audience (AUD) Tag**, a long hex string. It isn't a secret. The app uses it to check that
   every request really came through your login wall.

✅ Done when: the Applications list shows `Oktan` for `oktan.ustunfatih.com`, with the policy "Only
Fatih" and Google as the only login method.

Note: visiting `oktan.ustunfatih.com` now will just fail with "server not found". That's expected: the
address only comes online when I deploy in phase 2. At that point it will go straight to Google login.

---

## What to send me (no secrets)

Copy this, fill it in, and paste it in the chat:

```
Team domain:            <team>.cloudflareaccess.com
Access AUD tag:         <long hex string from part 5, step 8>
Service account email:  oktan-sheets@....iam.gserviceaccount.com
Key file saved at:      ~/Secrets/oktan-sa.json   (just the path. Don't paste the contents)
Both sheets shared:     yes / no
Google Test passed:     yes / no
```

## What happens next (phase 2, me)

1. Create branch `feat/web-app` from `main` and scaffold `web/` (worker + app + shared code).
2. Configure `wrangler.jsonc` with the custom domain `oktan.ustunfatih.com`, and deploy the skeleton.
3. Ask you to run **one** command in your terminal to load the key (I never see it):
   ```bash
   cd /Volumes/Mini/vibecoded/oktan/web && npx wrangler secret put GOOGLE_SA_KEY < ~/Secrets/oktan-sa.json
   ```
4. You open `https://oktan.ustunfatih.com` on your phone → Google login → "Hello, Fatih" plus your
   latest fill-up read live from the sheet. A private window logged into another Google account gets
   blocked.

## Troubleshooting

| Symptom | Fix |
|---|---|
| No "Zero Trust" in the Cloudflare sidebar | Use the dashboard search, or go to <https://one.dash.cloudflare.com> |
| Zero Trust insists on a card for the Free plan | Normal. Free plan is $0, and the card is only used if you upgrade |
| `redirect_uri_mismatch` on Google Test | The URI must be exactly `https://<team>.cloudflareaccess.com/cdn-cgi/access/callback` |
| "This app is blocked" / not verified | Consent screen not published, or you added sensitive scopes. Publish it, with no extra scopes |
| Can't create the JSON key | Tell me; we'd switch to a different auth method |
| You lost the client secret | Google console → Clients → `Cloudflare Access` → **Add secret** → update it in Cloudflare (Part 4) |
| Someone else needs access later | Edit the policy "Only Fatih" → add their email |
