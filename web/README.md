# Oktan Web

A fuel tracker for one car, at **https://oktan.ustunfatih.com**. It reads and writes the Google Sheet
"Qatar Fuel Tracking 2026", and only `ustunfa@gmail.com` can open it (Google login through Cloudflare Access).

- [PLAN.md](PLAN.md): what the app does and why.
- [ROADMAP.md](ROADMAP.md): the phases and a log of what was built and tested in each.
- [SETUP-GUIDE.md](SETUP-GUIDE.md): the one-time Google and Cloudflare setup (phase 0).

## How it fits together

```
phone / browser ──► Cloudflare Access (Google login, one allowed email)
                        │
                        ▼
                 Worker "oktan" ─── static app (dist/, React)
                        │  /api/*  (checks the Access token again)
                        ▼
                 Google Sheets API  (service account oktan-sheets@oktan-512607.iam.gserviceaccount.com)
                        │
                 Live sheet  1Gk9BvaD4bYf9Q3ss-v09Ezr64XrFd9MCMPSMYUEh9P8
                 DEV copy    1MJUHs2YSOssKJBL3neTz7zXSvzrm2ll4dIMJtgvYf58  ("test mode" in the app)
```

| Folder | What's in it |
| --- | --- |
| `app/` | The React app (Vite). Pages: Dashboard, Analytics, Log, Settings. Themes are CSS tokens in `styles.css`. |
| `worker/` | The Cloudflare Worker: routes in `app.ts`, entry point in `index.ts`, Google auth, Sheets client, writes, service jobs (`service.ts`), web push (`push.ts`) and reminders (`reminders.ts`). |
| `shared/` | Code used by both: sheet parsing, metrics, analytics, write planning, validation, service jobs and due dates (`maintenance.ts`). Most tests live here. |
| `scripts/` | `load-secrets.sh` (loads the Google key into Cloudflare and `.dev.vars`) and `make-vapid.mjs` (makes the web push key pair). |
| `mockups/` | The design boards the themes came from. |

**The sheet is the only database.** The Worker keeps a 30-second in-memory copy per sheet to save quota.
Every write reads the sheet fresh, checks that nothing changed since the page loaded, and then applies all
cell changes in one atomic `batchUpdate`. Every write also adds a row to the hidden `App_Log` tab (time,
action, who, entry ID, before, after). That tab is the audit trail and the way to undo by hand.

## Everyday commands

Run these from `web/`.

| Command | What it does |
| --- | --- |
| `npm test` | Unit tests (`shared/`) and API tests (`worker/app.test.ts`, with Google faked). |
| `npm run typecheck` | TypeScript for the app and the Worker. |
| `npm run preview` | Builds, then runs the real Worker at http://localhost:8787 against the **DEV sheet**. |
| `npm run dev` | Vite only (fast UI work). The API calls need `npm run dev:worker` running alongside. |
| `npm run deploy` | Builds and deploys to oktan.ustunfatih.com. |

Local development always uses the DEV copy, because `.dev.vars` sets `SHEET_ID` to it. Requests from
`localhost` skip the Access check using `DEV_EMAIL`. That bypass is ignored on any other host.

After `vite build`, restart `wrangler dev`. Otherwise it keeps serving the old asset names and returns 500.

## Ops notes

### Rotating the Google service account key

Do this every year, or straight away if the key file might have leaked.

1. Google Cloud console → project **oktan-512607** → IAM & Admin → Service accounts →
   `oktan-sheets@…` → **Keys** → Add key → Create new key → JSON. The file downloads.
2. From `web/`, run:
   ```bash
   npm run setup:secrets -- ~/Downloads/<new-key-file>.json
   ```
   This stores the key as the Worker secret `GOOGLE_SA_KEY` and rewrites `.dev.vars`. Nothing is printed
   except the account email. Production picks it up within seconds; no deploy is needed.
3. Open the app and press refresh. When the numbers load, go back to **Keys** and delete the old key.
4. Delete or move the downloaded file. Never commit it, and never paste it into a chat.

The sheets are shared with the service account's **email**, not with the key, so rotating keeps access.

### Changing who can sign in

Two places must agree:

1. **Cloudflare Zero Trust** → Access → Applications → Oktan → Policies: the email list.
2. `ALLOWED_EMAIL` in `wrangler.jsonc`, then `npm run deploy`. The Worker re-checks this on every API call.

If you ever recreate the Access application, its **AUD tag** changes. Copy the new one into `ACCESS_AUD` in
`wrangler.jsonc` and deploy, otherwise every API call answers "Invalid sign-in token".

### New months and fuel prices

- **Nothing to do for a new month or a new year.** The Data tab is a Sheets table (`GasData`) whose formula
  columns are single array formulas, so new rows calculate on their own. The app grows the table when it
  adds a row. The app computes all its analytics from the Data tab itself.
- **Prices:** on the 1st–5th of each month at 06:00 Qatar time, a cron job reads WOQOD and saves your grade's
  price into the Fuel Prices tab (Source = WOQOD), for both the live sheet and the DEV copy. Re-running is
  harmless.
- **If WOQOD is down or changes its site,** enter the price by hand in **Log → Prices**. A manual price is
  locked: WOQOD never overwrites it. **Unlock** hands the month back to WOQOD.
- To run the price check now, use **Log → Prices → Fetch from WOQOD and save**.

### Locking the live sheet

Set `"LIVE_WRITES": "false"` in `wrangler.jsonc` and deploy. The app then refuses to save to the live sheet,
and the cron skips it. Test mode (the DEV copy) keeps working. Set it back to `"true"` to unlock.

### Service tabs (maintenance log)

Two tabs hold the car's service history. The app creates them on your first save, so nothing is added to the sheet
until you use the feature.

- **`Maintenance`**: one row per job. Columns: Date, Odometer km, Category, Description, Cost QAR, Workshop,
  Next due km, Next due date, Notes, and the hidden ID in column J. Edit by hand if you need to; a row without a
  date, category or odometer is skipped and counted on the Service page.
- **`Service plan`**: one row per category with **Every km** and **Every months**. Blank means that measure isn't
  used. The starting values are generic: check them against your car's service book and change them in the app
  (Service → Plan) or here.

Due dates come from the latest job in each category. A job's own "next due" values override the plan for that
job. The dashboard's "Next service" panel shows the four items due soonest, and the Analytics page totals service
spend for the chosen range.

Deleting rows in these tabs is safe (they have no formulas). Deletes made in the app go to `App_Log`.

### Fill-up reminders (web push)

The Worker sends a notification to each subscribed phone when it has been long enough since the last fill-up.
It checks once a day at 08:00 Qatar time. Each fill-up gets at most one reminder, and the gap (default 10 days)
is set in Settings.

**One-time setup (needed before reminders can be turned on):**

1. Make the key pair, saving the private half to a file outside the project:
   ```bash
   node scripts/make-vapid.mjs ~/Secrets/oktan-vapid.jwk.json
   ```
2. Put the printed public key in `wrangler.jsonc` as `VAPID_PUBLIC_KEY`, then deploy.
3. Load the private key as a secret, then delete the file:
   ```bash
   npx wrangler secret put VAPID_PRIVATE_JWK < ~/Secrets/oktan-vapid.jwk.json
   ```

The subscriptions live in the KV namespace `PUSH` (device credentials, not sheet data). On iPhone, reminders only
work for an app added to the Home Screen (iOS 16.4 or later).

**Key rotation notice:** `KEY_CREATED_ON` in `wrangler.jsonc` is the date the Google key was made. The daily check
sends a notice about 330 days after that date. After you rotate the key (above), update `KEY_CREATED_ON`.

### Logs and errors

Every failed request, every write, every browser crash and every price check is written as one JSON line
to the Worker logs:

| `event` | When |
| --- | --- |
| `api` | Any write, and any request that failed (method, path, status, duration). |
| `api_error` | A failure with its cause: `google_auth`, `sheet_layout`, `sheets_<status>`, `unexpected`. |
| `sheets_retry` | Google said "too many requests" or had a hiccup, and the Worker is retrying. |
| `push_failed` | A reminder couldn't be delivered (the status code, or that the VAPID key isn't set). |
| `daily_check` | The daily 08:00 check: reminders and the key notice that were sent. |
| `client_error` | A crash or unhandled error in the browser (message, stack, page, browser). |
| `price_check` | The monthly WOQOD job, per sheet: saved, unchanged, skipped or failed. |

To see them, go to **Cloudflare dashboard → Workers & Pages → oktan → Observability**, or stream them live:

```bash
npx wrangler tail oktan --format pretty
```

### Limits and security

- **Changes are rate-limited:** 60 a minute per account (the `WRITE_LIMITER` binding). Crash reports: 20 a minute.
  Access already restricts the app to one account, so a limit only trips on a runaway loop; the message says so.
- **Headers:** `app/public/_headers` sets the Content-Security-Policy, HSTS, frame and referrer rules. Built files
  are cached for a year (their names change when they change). Scripts come only from the app itself, so the theme
  script is a file (`theme-init.js`), not inline. Styles allow inline `style` attributes, which React uses.
- **Fonts are self-hosted** from the `@fontsource` packages, so nothing loads from Google at runtime. The build keeps
  fonts as files (`assetsInlineLimit: 0`), because the content policy blocks inlined `data:` fonts. Adding a font
  means adding its `@fontsource` package and CSS import in `app/src/main.tsx`.
- **Access session:** in Cloudflare Zero Trust, check the session duration of the Oktan application (Access →
  Applications → Oktan → Session duration). Shorter is safer on a shared phone.

### Google quota

The Sheets API allows about 60 reads and 60 writes per minute for this service account. The app uses
1–3 calls per screen load and about 4 per save, so normal use is far below that.

- When Google answers 429 (too many requests), the Worker waits and retries up to 3 times, about 6 seconds
  in total. It follows Google's `Retry-After` when Google sends one.
- If Google still refuses, the app shows "Google Sheets is busy" and keeps showing the last numbers it had.
- A **write** that fails with a Google server error is **not** retried, because it might have been saved.
  Refresh to see whether it landed before trying again. `App_Log` shows every save that happened.

### When something breaks

| The app says | Likely cause | Fix |
| --- | --- | --- |
| Google connection is not set up | `GOOGLE_SA_KEY` missing or malformed. | Run `npm run setup:secrets -- <key.json>` (see rotating the key above). |
| Google Sheets refused access | The sheet is no longer shared with `oktan-sheets@…`. | Share the sheet with that email as **Editor**. |
| Google Sheets can't find the spreadsheet | The sheet was deleted or replaced, so its ID changed. | Restore it from Drive's trash, or put the new ID in `SHEET_ID` and deploy. |
| The sheet's layout changed | A Data tab header was renamed, or columns were moved. | Restore the headers (expected names: `shared/parse.ts`, `EXPECTED_HEADERS`). |
| Google Sheets is busy | Quota burst. | Wait a minute. |
| Invalid sign-in token / This account is not allowed | `ACCESS_AUD` or `ALLOWED_EMAIL` doesn't match Access. | See "Changing who can sign in" above. |
| This screen hit a problem | A bug in the app. It has been reported to the logs. | Reload. Look for the `client_error` line in the logs. |

### Launch screen and splash

Home Screen launches show two things, both the "gauge sweep" design:

- **Launch image** (static, shown by iOS before the app starts): the gauge at its final reading, in light or dark
  to match the phone's setting. iOS can't read the app's theme at this point, so light uses Soft Fintech colours and
  dark uses Instrument Cluster colours (the Auto pair). There's one PNG per iPhone screen size in `app/public/splash/`,
  linked from `app/index.html`. To change the colours or the gauge, edit `scripts/make-launch-images.mjs` and run
  `node scripts/make-launch-images.mjs`.
- **In-app splash** (animated): the gauge sweeps up to the same reading in the app's own theme colours, and the
  wordmark fades in. It stays about 1.3 seconds, or until the first screen is ready, and never more than 6 seconds.
  With Reduce Motion on, it shows the final frame briefly. Markup in `app/index.html`, styles in `styles.css`
  (`.splash`), timing in `app/src/splash.ts`.

In an ordinary browser tab neither appears. To see them, add Oktan to the Home Screen and open it from there.

### Offline fill-ups

A fill-up saved with no connection is kept on the phone (IndexedDB) under **Waiting to send** on the Log page, and
the top bar shows how many are waiting. They go to the sheet when the phone is back online, or with **Send now**.
If the sheet already has a fill-up with the same date, odometer and litres (the reply was lost, not the save), the
queued copy is dropped instead of added twice. Edits and deletes need a connection.

### Backups and undo

- A full copy of the sheet from before the app went live: `1XqyIP3iT-wg1RyqgYOa-bRValaGFHnAbmC-WGjovDMY`.
- Google Sheets' own **File → Version history** can restore any earlier state.
- `App_Log` has the before and after values of every change the app made, so a single bad edit can be
  copied back by hand.

### Rules for editing the sheet by hand

You can keep typing into the sheet directly; the app re-reads it when you come back to it. Keep these intact:

- The tab names `Data`, `Fuel Prices` and `Settings`, and the Data tab's header row.
- Columns B and J–O (array formulas) and the hidden column P (entry IDs; leave it blank on rows you add by hand).
- `Settings`: B2 theme, B3 fuel grade, B4 tank capacity, B5 default drive mode; stations in column E
  (archived flag in F); drive modes in column G.
