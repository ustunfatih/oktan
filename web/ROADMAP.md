# Oktan Web — build roadmap (for approval)

Date: 24 Oct 2026 · Status: **in progress — phase 1 done, phase 0 (your accounts) underway** ·
Earlier analysis: [PLAN.md](PLAN.md) · Setup steps for you: [SETUP-GUIDE.md](SETUP-GUIDE.md) ·
Mockups: [canvas](https://claude.ai/artifact/HRtPMgnVWjxorb9BbipZB5) (5 themes × desktop + mobile)

Progress log:

- 24 Oct — `wrangler login` done (account `161fc91b…`). `ustunfatih.com` is on Cloudflare; `oktan.` is free.
- 24 Oct — **Sheet hardening done** (§2). Backup:
  [Qatar Fuel Tracking 2026 — backup 2026-10-24](https://docs.google.com/spreadsheets/d/1XqyIP3iT-wg1RyqgYOa-bRValaGFHnAbmC-WGjovDMY/edit).
  Dev copy for building against:
  [Oktan DEV](https://docs.google.com/spreadsheets/d/1MJUHs2YSOssKJBL3neTz7zXSvzrm2ll4dIMJtgvYf58/edit). It was tested
  by adding two fill-ups, and every calculation, summary and chart range extended by itself.
- 24 Oct — Decisions: Google login only (no Apple, no email PIN). A **Settings page** was added (§4b).
- 24 Oct — Phase 0 done on your side (Zero Trust team `ustunfatih`, Google login tested, Access app with
  your email only, service account `oktan-sheets@oktan-512607` shared on both sheets).
- 24 Oct — **Phase 2 skeleton deployed** on branch `feat/web-app` (not committed yet).
  `oktan.ustunfatih.com` is live and every path redirects to the Access login. workers.dev and preview URLs
  are off. The Worker also verifies the Access JWT, audience and email on every `/api` call.
- 24 Oct — **Phase 2 ✅ done.** Key loaded. You confirmed live data on the phone. Local dev reads the Oktan DEV
  sheet with identical numbers (23 fill-ups, 8,761 km, 9.29 L/100 km, QAR 0.188/km). Secrets and build
  output are git-ignored. Committed as `42f2f63`.
- 24 Oct — **Phase 3 (Dashboard) deployed** in the Instrument Cluster theme (your default for now).
  - `/api/data` reads the Data, Fuel Prices and Settings tabs in one request, cached for 30 s; the refresh
    button skips the cache.
  - `/api/woqod` fetches WOQOD's prices, cached for 6 h.
  - Dashboard: gauge, 6 figures, tappable efficiency trend, tappable monthly spend, WOQOD price card,
    recent fill-ups, next fill-up estimate.
  - Phone layout with a bottom tab bar; a "sign-in expired" state.
  - Charts are hand-drawn SVG instead of ECharts: far lighter, and they match the mockups exactly.
  - 20 unit tests. Checked in the browser at desktop and phone sizes.
- 24 Oct — Phase 3 confirmed on your phone, including live WOQOD prices from Cloudflare. Committed as `fdf992a`.
- 24 Oct — **Phase 4 (Analytics) deployed.**
  - Filters: period (3M / 6M / 12M / year to date / all), drive mode and station, with a totals strip that
    follows the filters.
  - Charts and tables: drive mode comparison, auto-generated insights (best mode, summer vs winter, price
    change), monthly price step chart with your average paid, km per tank, cumulative spend, stations with
    share of spend, L/100 km by month heat table, consistency histogram, records board, sortable list of
    all fill-ups.
  - 31 unit tests. Checked at desktop and phone sizes; nothing scrolls sideways on a phone.
  - Committed as `0e2c235`.
- 24 Oct — **Phase 5 (Log: add / edit / delete) deployed, with saving to the live sheet locked** (`LIVE_WRITES`
  "false").
  - **Test mode** is a switch in the app: you read and write the Oktan DEV copy, and a strip at the top of
    every page says so.
  - **Writing:** each save is one atomic sheet update, re-checked against the rows you saw. Deletes shift
    rows up instead of removing them (rows 2–3 hold the column formulas) and re-link the trips either
    side. The GasData table grows by itself. A hidden `App_Log` tab records every change.
  - **Form:** price pre-filled for the fill-up's date (Fuel Prices tab → WOQOD → last known), litres or
    amount paid, live trip preview, field validation. Undo for adds and edits.
  - **Tested:** 49 unit tests; a 14-step API run against the DEV sheet (add, conflict, bad odometer, edit,
    middle delete, growing to row 31, cleanup to identical rows); the full flow in the browser at phone
    size; the live lock, the test-mode switch and the cross-site/non-JSON refusals locally.
  - **Known effect:** deleting a fill-up between two others makes the merged trip's L/100 km read low
    (that fill-up's litres disappear). The delete confirmation explains this and suggests Edit.
- 24 Oct — You tested add, edit, undo and delete in test mode on your phone. **Live saving unlocked**
  (`LIVE_WRITES` "true", version `772961ee`); the DEV copy was left clean. Test mode stays available. Phase 5 ✅
  (`cefc543`).
- 24 Oct — **Phase 6 (prices) deployed** (version `846f5de5`, uncommitted).
  - **Monthly check:** a Cloudflare cron at 03:00 UTC (06:00 Qatar) on the 1st–5th fetches WOQOD and saves
    your grade's price into the Fuel Prices tab (live sheet and DEV copy), with Source = WOQOD. Unchanged
    values aren't rewritten. Results go to the Worker logs.
  - **Log → Prices:** shows WOQOD's current price and whether it's in your sheet, and has a "Fetch from WOQOD
    and save" button. You can set any month's price by hand, up to next month. A manual price is **locked**:
    WOQOD never overwrites it, and Unlock hands the month back to WOQOD.
  - Every price change is recorded in App_Log.
  - **Tested:** 57 unit tests; a 9-step API run on the DEV sheet (save, no-op, manual, lock, unlock, restore,
    bad month, bad price); the cron triggered locally; the screen at phone size. DEV cleaned up afterwards.
  - Committed as `752b2a2`.
- 24 Oct — **Phase 6b (Settings page) deployed** (version `141a4bee`, uncommitted).
  - **Theme picker** saved to Settings!B2, plus a per-device override. Only Instrument Cluster is selectable
    until phase 7; the others are shown as "Arrives in phase 7".
  - **Car & fuel:** tank capacity (warns that the sheet recalculates history), fuel grade for WOQOD prices,
    default drive mode.
  - **Stations editor:** rename, reorder, add, archive/restore (archived = column F, hidden from the Log
    form). Deleting is allowed only for unused stations. Renaming a used station requires "also rename in
    past fill-ups", which does an exact-match find-and-replace in the Data tab in the same atomic update.
  - **Data & sync:** sheet link, last read, refresh, CSV export, Fuel prices shortcut, test-mode switch.
  - **Account:** signed-in email, sign out.
  - Committed as `b5b1bea`.
- 24 Oct — **Phase 7 (themes and home-screen app) deployed** (version `cfab78f2`, uncommitted).
  - **All 5 themes work:** Instrument Cluster, Swiss Ledger, Doha Editorial, Soft Fintech and Pump Brutalist.
    Each is a set of colour, font, border and shadow tokens, plus a few signature details (cluster glow,
    Doha serif headings, brutalist hard shadows and yellow efficiency block). Only the active theme's fonts load.
  - **Auto** (the default, D4): Instrument Cluster when the phone is in dark mode, Soft Fintech in light mode.
    It follows the phone live. The sheet's choice applies everywhere, and "On this device" overrides it per device.
  - **No flash:** the last theme is applied before the first paint, and the browser bar colour follows the theme.
  - **Home-screen app:** manifest, icons (amber drop), apple-touch-icon and a service worker. The worker caches
    the app shell only, never `/api`, so data is always read live. Everything, the manifest included, stays
    behind the Google login.
  - **Fixed:** the fuel-grade and drive-mode pickers in Settings overflowed at phone width. They now take the full row.
  - **Tested:** 64 unit tests, typecheck, colour-contrast check of every text/background pair in all 5 themes,
    screenshots of each theme at desktop and phone size, an overflow sweep of every page at 375 px in all 5 themes.
  - Committed as `a7a22c9`.
- 24 Oct — **Phase 8 (hardening) deployed** (version `26090273`), committed as `80331c8`.
  - **Google quota:** a 429 is retried up to 3 times (about 6 s, honouring Retry-After). Read errors from Google
    (5xx) are retried too; write errors are not, because the write may have landed. A rejected access token is
    dropped and fetched again once.
  - **Clear messages:** "Google Sheets is busy", "refused access (check sharing)", "can't find the spreadsheet",
    and "had a problem", instead of one generic error.
  - **Error reporting:** one JSON log line per write, per failure, per retry and per price check. Browser crashes
    and unhandled errors are posted to `/api/client-error` (max 5 per page) and land in the same Worker logs. A crash
    on one screen shows "This screen hit a problem" while the top bar and tabs keep working, and retries when
    fresh data arrives.
  - **API tests:** `worker/app.test.ts` runs 21 tests through the real routes with Google faked: sign-in, cache,
    live lock, write guards, an atomic add with App_Log, validation and conflict refusals, every quota/failure path,
    client-error logging, the cron skip. A deliberate bug in the retry rule was caught by the tests.
  - **README.md:** architecture, commands, and ops notes (rotating the Google key, changing who can sign in,
    months and prices, locking the live sheet, logs, quota, a troubleshooting table, backups, sheet editing rules).
  - **Tested:** 85 tests and typecheck; local run against the DEV sheet (data read, log lines, browser error and
    promise reports, crash screen and its recovery).
- 27 Oct — **Next round** (branch `feat/web-next`, from `main`; deployed 27 Oct as version `430abc35`, not committed).
  - **Merge:** PR #21 had already been merged into `main` by you on 24 Oct. Nothing was left to merge.
  - **Phase 0 status:** the table row now shows done.
  - **Performance:** fonts are self-hosted (`@fontsource`), so nothing loads from Google. Analytics, Log, Service and
    Settings load on first open. The shared read cache uses the Workers Cache API (shared across Worker instances in a
    data centre) instead of per-instance memory. The main bundle is 256 kB (80 kB gzipped), down from 306 kB.
  - **Security:** a Content-Security-Policy and the other headers (`_headers` for the app, the Worker for the API).
    The theme script moved to a file so no inline script runs. Changes are rate-limited (60 a minute), and crash
    reports too (20 a minute).
  - **Accessibility:** checked with axe-core in all seven themes, on every page and sub-tab: no violations.
    Fixes: invalid ARIA on the Log sub-tabs and the theme picker; focusable, named table regions; a "View as a table"
    option under every chart (the text form of the picture); a skip link; 44 px touch targets; reduced motion
    honoured everywhere (also for smooth scrolling); 3:1 contrast for input and button outlines and comparison bars.
    Text contrast passes in every theme (script in the session's scratchpad).
  - **Dark themes:** "Doha Editorial (dark)" and "Swiss Ledger (dark)" are now choices in Settings (seven themes).
  - **Maintenance log (phase 9):** the Service tab with New, History and Plan; the dashboard's "Next service" panel;
    the Analytics "Service costs" panel. Shared rules and due dates are unit-tested (25 tests); the routes are
    API-tested. Tested on the DEV sheet: added a job (the tab was created), read it back on the dashboard and in
    history, saved a plan, deleted the job. The live sheet is still locked until live writes are on.
  - **Offline fill-ups:** a fill-up saved with no connection waits on the phone (IndexedDB), shows in "Waiting to
    send" and in the top bar, and goes up when the phone reconnects. A reply lost after the sheet saved is detected
    and not duplicated. Tested by blocking the request, then restoring it.
  - **Fill-up reminders (web push):** subscription on the phone, encrypted messages (RFC 8291) with a signed VAPID
    header, a daily check at 08:00 Qatar time, one reminder per fill-up, and a key-rotation notice ~330 days after
    `KEY_CREATED_ON`. Unit-tested (encryption round-trip, the VAPID signature, the daily rules). **Not live yet:** the
    VAPID private key still needs to be loaded as a secret (see README, "Fill-up reminders").
  - **Launch and splash:** you picked Option B, the gauge sweep. The in-app splash sweeps in the app's theme colours
    and shows only on Home Screen launches. There are 20 static launch images (10 iPhone sizes, in light and dark),
    generated by `scripts/make-launch-images.mjs`, with the gauge in the same place so the hand-over is seamless.
    Checked in the browser; not yet seen on an iPhone.
  - **Charts (fix):** a single outlier (a 28.84 L/100 km tank) had stretched the trend chart's axis to 30, which
    put about 60 labels on it. The axis now ignores outliers (Tukey fences): the outlier is drawn at the edge, marked
    ▲/▼ and "off the scale" in the readout. Every chart's y-axis has at most about five labels. Unit-tested
    (`shared/scale.ts`). The live sheet has no 26 Oct row now, so that value came from an entry changed later.
  - **Tested:** 64 unit tests; an 11-step API run on the DEV sheet (tank size flows into the sheet's
    formulas; invalid grade refused; add/archive/reorder; rename refused without history and applied with
    it; deleting a used station refused; full restore); the screen at desktop and phone sizes.
  - **Bug found and fixed:** a copy of the data saved on the device by the previous version (no station
    list) crashed the page. The saved-copy key is now versioned (`oktan:data:v2`).

What you've decided so far:

- One car only, permanently. Nothing in the data model handles multiple cars.
- Google Sheet "Qatar Fuel Tracking 2026" stays the only data store. The sheet is fixed so it keeps counting.
- The Log tab supports **add, edit and delete** for fill-ups, plus **manual monthly fuel prices**.
- iOS app is out of scope. All work stays in `web/`.
- Used mostly on the phone. It is mobile-first and installable to the home screen.
- Login is required: only you can see or change anything.

---

## 1. Answers to your questions

### "Can you set Cloudflare up for me with the MCP?"

**Mostly yes, but not with an MCP.** No Cloudflare MCP is connected to this session. The one available in
the directory ("Cloudflare Developer Platform") only covers Workers/KV/D1/R2 listings. It can't do custom
domains or login protection. Here is how the setup splits:

| Task | Who | How |
|---|---|---|
| Install `wrangler` (Cloudflare's CLI) in `web/` | me | npm dev dependency |
| Log wrangler into your Cloudflare account | **you, once** | run `npx wrangler login` and click *Allow* in the browser |
| Create the Worker, deploy, set secrets, add the cron | me | wrangler |
| Attach `oktan.ustunfatih.com` (DNS record + certificate) | me | wrangler `custom_domain` route. Cloudflare creates DNS + certificate automatically |
| Set up the login wall (Cloudflare Access app + policy) | me **or** you | **Option A:** you create a scoped API token (I give exact permissions) and I script it. **Option B:** I walk you through about 6 clicks in the dashboard |
| Google Cloud: service account + key (lets the app read and write the sheet) | **you**, guided | Google Cloud Console. I can't create credentials in your Google account |
| Google Cloud: OAuth client (for "Sign in with Google") | **you**, guided | same console, about 3 minutes |

I'll never ask you to paste a password or secret into chat. Keys go straight into `wrangler secret put` in your
terminal, or into the Cloudflare dashboard.

### "Can I log in with Google or Apple?"

- **Google: yes.** Cloudflare Access supports it natively. We allow exactly `ustunfa@gmail.com`;
  everyone else is refused before any page or data loads.
- **Apple: not natively.** Cloudflare Access has no built-in Apple login. It could be wired in as a
  "generic OIDC" provider, but that's fragile and costly:
  - Apple requires a paid **Apple Developer Program** membership ($99/yr).
  - Apple's client secret is a signed token that expires at least every 6 months, so it needs rotating.
  - Apple returns the login result in a way generic connectors often don't handle.
- **Recommended:** Google as the main login, plus **email one-time PIN** as a backup. The PIN is sent to
  your email address and needs zero setup. If your Apple ID uses an iCloud address, the PIN option covers
  that too.
- Optional extra: Cloudflare now also offers "Sign in with Cloudflare". Your Cloudflare account login can
  itself use Apple, so it's an indirect Apple route at no cost.
- Session length: 30 days, so you won't be re-logging in at the pump.

### "Keep all of these themes"

I'm reading this as: **all 5 themes ship in the app, with a theme switcher** (like the iOS app's theme
system). See decision D1. If you meant "keep them on the canvas for now, I'll pick one", tell me.
That makes phase 7 smaller.

---

## 2. Sheet fixes (phase 1 — ✅ done 24 Oct 2026)

What was actually changed (verified: every existing number is unchanged):

- **Data** (it's a Sheets table, `GasData`): columns B, J, K, L, M, N, O are now **one formula per column**
  that calculates every row, current and future. You only type A, C–I (or the app does).
  The open trip now shows a blank "Driven KM" instead of −8,774.
- **Price lookup** in column E now reads the whole `Fuel Prices` list (it stopped at Dec 2026 before).
- **Hidden column P "ID"**: a stable ID per fill-up, used by the app for edit and delete.
- **Calc_Data**: all ranges are open-ended. The station list and month list are generated from the data,
  so new stations and months appear by themselves. Added "Total Fuel Bought" and "Number of Fill-ups".
- **Dashboard charts**: all 4 now read to the end of the data.
- **Fuel Prices**: new "Source" column; months added through Dec 2027. Tank capacity now comes from
  `Settings`.
- **New Settings tab**: theme, fuel grade, tank capacity, default drive mode, currency, station list,
  drive modes. Data's Gas Station column has a dropdown from the station list (other names still allowed).

The original plan for this phase is kept below for reference.

While scoping the fix I found the sheet is **already** missing data in places, not just at row 29:

| Problem found | Effect today | Fix |
|---|---|---|
| `Calc_Data` monthly table uses `Data!…$2:$24` | the **next** fill-up (row 25) won't show in monthly km/spend | open-ended ranges (`Data!$J$2:$J`) |
| `Calc_Data` totals/mode/station use `…$2:$29` | stops counting after 5 more fill-ups | open-ended ranges |
| Monthly list is 16 typed-in dates (missing Jun-25, Aug-25, May-26; ends Oct-26) | November 2026 onwards never appears | month list generated from the data (`SEQUENCE` from first month to current month) |
| Station list is typed in (Pearl, Dafna, Onaiza, Fox Hills) | a new station's spend is silently dropped | station list generated with `UNIQUE(FILTER(...))` |
| Dashboard "Fuel Consumption Trend" chart reads `Data!A1:A23` / `N1:N23` | the 10 Sep 2026 tank already isn't plotted | widen all 4 chart ranges to row 1000 |
| `Data` formulas copied row by row only to row 29, with placeholder rows (FALSE/0) | new rows have no formulas; placeholders confuse "next empty row" | one formula per column for all rows (B, J–O) and remove the placeholder rows |
| Column M has `47` typed into the formula | changing tank size in `Fuel Prices!F2` is ignored | point it at `'Fuel Prices'!$F$2` |
| No stable row identity | editing or deleting from the app could hit the wrong row if rows shift | add column **P "ID"** (hidden, app-managed) |
| `Fuel Prices` has no source info | can't tell WOQOD from manual entries | add column **D "Source"** (`WOQOD` / `Manual` / `Sheet`) |

How I'll do it safely:

1. **Back up first:** make a full Drive copy "Qatar Fuel Tracking 2026 — backup 2026-10-xx".
2. Write down every current `Calc_Data` value, apply the changes, then check the numbers match exactly
   (except where the old formulas were already wrong).
3. Report what changed, cell by cell.
4. You keep typing into the sheet by hand exactly as before. The new formulas fill in automatically.

---

## 3. How add, edit and delete work against the sheet

The sheet stores the odometer reading *at a fill-up* in the **previous** row's "Odometer POST". The app
hides this; you just see one odometer field per fill-up.

| Action | Sheet writes (one atomic `batchUpdate`) |
|---|---|
| **Add** fill-up | previous row `C` ← odometer; next free row `A, D–I, P` ← date, litres, price, cost, full, mode, station, new ID |
| **Edit** odometer | previous row `C` ← new value (this row's `B` updates by formula) |
| **Edit** any other field | that row's cells |
| **Delete** latest fill-up | previous row `C` ← empty (its trip becomes "open" again); delete the row |
| **Delete** a middle fill-up | previous row `C` ← deleted row's `C` (the two trips merge); delete the row |
| **Delete** the first fill-up | delete the row; the new first row's `B` gets the real value |

Safety:

- The app re-reads the sheet just before writing and checks the row IDs. If something changed (e.g. you
  typed in the sheet), nothing is written and you're asked to review.
- Every delete needs confirmation, and the confirmation says what happens to neighbouring trips.
- Every write is logged to a hidden `App_Log` tab (time, action, before → after) so any change can be undone
  by hand.

## 4. Fuel prices (auto + manual)

- **Auto:** a Cloudflare cron runs at 06:00 Qatar time on the 1st–3rd of every month and calls WOQOD's
  JSON endpoint. It writes Super 95 for the month into `Fuel Prices` with Source = `WOQOD`. Fallbacks:
  parse the retail page HTML, then leave the month empty and show a banner.
- **Manual:** Log → Prices lets you set or edit any month's price. A **manual price is locked**: the cron
  never overwrites it. There's also a "Fetch from WOQOD now" button.
- **When logging:** the price field is pre-filled with the price for the *fill-up's date* (so backdated
  entries are right), marked with its source, and always editable. Total cost = litres × price, or type
  the amount paid and litres is calculated.

## 4b. Settings page

A fourth screen, reached from a gear icon in the header on desktop and on phones (the bottom bar keeps
3 tabs). Everything except the theme is stored in the sheet's `Settings` tab, so it's the same on every
device and still editable in the sheet.

| Setting | Stored in | Notes |
|---|---|---|
| **Theme** | `Settings!B2` + a per-device override | Auto / Cluster / Swiss / Doha / Fintech / Brutalist, with a live preview card for each. "Auto" picks dark or light from the phone's setting. A device can override, e.g. Cluster on the phone and Swiss on the laptop |
| **Tank capacity (L)** | `Settings!B4` | Drives the Used Fuel / L/100 km formulas. A warning explains that changing it recalculates history |
| **Stations** | `Settings!E2:E` | Add, rename, reorder, delete. Renaming offers "also rename it in past fill-ups". Deleting a station still used in the log is blocked (archive instead, which hides it from the Log chips) |
| **Fuel grade** | `Settings!B3` | Super 95 / Premium 91 / Diesel: which WOQOD price is fetched and pre-filled |
| **Default drive mode** | `Settings!B5` | Pre-selected on the Log form |
| **Fuel prices** | `Fuel Prices` tab | Shortcut to Log → Prices (manual monthly prices, lock status, "fetch now") |
| **Data & sync** | — | Last sync time, link to the Google Sheet, "Refresh now", CSV export |
| **Account** | — | Who is signed in, Sign out (ends the Cloudflare Access session) |

Mockups for this screen (5 themes × phone + desktop) will be added to the canvas at the start of phase 7,
or earlier if you want to see them first.

---

## 5. Architecture (unchanged from PLAN.md, confirmed)

- One **Cloudflare Worker** serves the app and `/api/*`, plus the cron. Free plan.
- **Frontend:** Vite + React + TypeScript; ECharts for charts; mobile-first; **PWA**, so it's installable
  on the iPhone home screen.
- **API:** Hono, Zod validation. Google Sheets REST via a service account, with JWT signed in the Worker.
- **Login:** Cloudflare Access in front of everything. The Worker also verifies the Access token on every
  API call.
- **Metrics:** one shared TypeScript module, unit-tested to reproduce the sheet (9.29 L/100 km, QAR
  0.188/km, …).
- **Development** runs against a **copy** of the sheet ("Oktan DEV"). Your real sheet is only connected once
  the write paths pass their tests.

Cost: Workers free tier, Access free (≤50 users), Sheets API free → **QAR 0/month** (Apple login would add
$99/yr).

---

## 6. Phases

Each phase ends with something you can see. I'll stop after phases 2, 5 and 7 for a check-in.

| # | Phase | What's included | Done when | Size |
|---|---|---|---|---|
| 0 | **Accounts & access** — ✅ *done* | You: ~~`wrangler login`~~ ✅; Zero Trust team; Google Cloud service account + key; Google OAuth client; Access app. Me: [SETUP-GUIDE.md](SETUP-GUIDE.md), verify each piece | all credentials stored as secrets, nothing in git | S |
| 1 | **Sheet hardening** — ✅ *done* | Backup, then the fixes in §2; dev copy of the sheet | Calc_Data numbers verified, new rows calculate automatically | S |
| 2 | **Skeleton live behind login** | Scaffold `web/` (app, worker, shared); deploy to `oktan.ustunfatih.com`; Access with Google login; "Hello, Fatih" page reading 1 cell from the sheet | you can log in on phone + desktop; a private/incognito window is blocked | M |
| 3 | **Dashboard** | Read path + caching; KPIs, efficiency trend, monthly spend, prices card, recent fill-ups, next-fill estimate; empty/error states | numbers match the sheet | M |
| 4 | **Analytics** | Date range + mode + station filters; mode comparison, price history, km per tank, stations, monthly heat-table, distribution, records; full trip list | every chart in the chosen mockups works with filters | M |
| 5 | **Log: add / edit / delete** | Mobile-first form with live calculations; history list with edit and delete; conflict check; `App_Log` tab; optimistic UI with undo | test fill-up added, edited, deleted on the dev sheet, then on the real sheet with you watching | L |
| 6 | **Prices** | WOQOD client + monthly cron + fallbacks; manual price screen; price-for-date lookup | November 2026 price appears on 1 Nov automatically; manual lock tested | S |
| 6b | **Settings page** | §4b: theme picker with previews, tank capacity, station list editor (add/rename/archive), fuel grade, default mode, sync info, sign out | changing a station or tank size in the app shows up in the sheet and vice versa | M |
| 7 | **Themes & mobile polish** | All 5 themes behind a switcher (D1); bottom tab bar on phone; PWA install + icon; light/dark where the theme allows; accessibility pass | app passes a phone walkthrough in all 5 themes | L |
| 8 | **Hardening** | Unit + API tests, Sheets quota handling, error reporting, README with ops notes (rotating keys, adding months) | test suite green; handover doc written | S |
| 9 | **Maintenance log** — ✅ *built* | Service, repair and parts history for the car; intervals and "next due" on the dashboard; cost totals on Analytics | a service added on the phone shows as due on the dashboard, and the sheet has the matching row | L |

Order is strict up to 2, then 3–6 can overlap.

---

## 9. Maintenance log (phase 9 — built and deployed, awaiting your phone test)

**Goal.** Record every service, repair and part for the car, see what's due next, and keep it all in the sheet,
like fill-ups.

**Decisions taken for this phase** (tell me if you want any of them different):

- **Two new tabs in the sheet.** `Maintenance` holds one row per job. `Service plan` holds the intervals and the
  category list. The sheet stays the only store. Each job has a hidden ID column, as fill-ups do.
- **One car, so no vehicle column.**
- **Categories are rows in `Service plan`.** The default list is: Oil and filter, Air filter, Tyres, Brakes,
  Battery, Coolant, Spark plugs, Inspection, Other. You can add or remove categories in the app or in the sheet.
- **Every job has** a date, an odometer reading, a category, and optional cost (QAR), description, workshop
  and notes. It can also carry its own next-due km and/or date, which overrides the plan for that job.
- **Due rule.** For each category, next due = the latest job in that category + the plan's interval (km, months,
  or both). Whichever comes first counts. A job with its own next-due values overrides the plan.
- **Status.** Overdue when km left ≤ 0 or the date has passed. Due soon at ≤ 1,000 km or ≤ 30 days. Otherwise
  OK. Km are measured from the highest odometer reading in the sheet, fill-ups or jobs.
- **Tabs appear on first use.** The app reads them only when they exist. The first save creates `Maintenance`,
  and the first change to the plan creates `Service plan` (with the defaults). Until then the app shows the
  defaults and an empty history. Nothing is created on the live sheet until you save a job, and saving stays
  locked until live writes are on.

**Screens.**

- **Service tab** (new bottom tab, wrench icon) with three sections:
  - *New:* the form. Date defaults to today; odometer defaults to the latest reading; category; cost; description;
    workshop (tap a recent one); next due, pre-filled from the plan.
  - *History:* jobs newest first, with edit and delete (delete asks for confirmation and is logged to `App_Log`),
    plus totals: jobs, total spend, and spend per 1,000 km since the first record.
  - *Plan:* each category's interval in km and months, add and remove categories.
- **Dashboard:** a "Next service" panel listing the four items due soonest, each with its status colour and
  km or date left.
- **Analytics:** a "Service costs" panel for the selected date range: total, cost per 1,000 km, and spend by
  category (drawn with the existing column chart, with its table alternative).

**Validation.**

- Date: required, not in the future.
- Odometer: required, 0 or more, and not more than 2,000 km above the highest reading in the sheet.
- Category: required.
- Cost: optional, 0 or more, at most QAR 100,000.
- Next due km: must be above the job's odometer. Next due date: must be after the job's date.
- Descriptions and notes: up to 200 and 500 characters.

**Build steps.**

| Step | What | Done when |
| --- | --- | --- |
| M1 | `shared/maintenance.ts`: types, default plan, parsing, validation, due and status rules. Unit tests with a fixture. | tests cover every due rule and both status thresholds |
| M2 | Worker: cached sheet tab list (5 min), reads of both tabs when present, `POST/PUT/DELETE /api/service/:id`, `PUT /api/service-plan`, tab creation on first write (ids 7000 and 7001), `App_Log` entries, conflict checks, live lock. | API tests pass for add, edit, delete, conflicts, missing tabs and the live lock |
| M3 | UI: the Service tab (New, History, Plan), validation messages, empty states, keyboard and screen-reader labels. | every field validated on the phone; axe finds nothing |
| M4 | Dashboard "Next service" panel and Analytics "Service costs" panel. | numbers match a hand calculation on the DEV sheet |
| M5 | DEV test, phone walkthrough, deploy, README section (adding a category, changing intervals, what the tabs contain). | you add, edit and delete a job on the phone |

**Risks.**

- Someone edits the new tabs by hand. The app reads them tolerantly: blank cells are ignored, and a row with no date
  or category is skipped, with a note in the log.
- Deleting rows in these tabs is safe, because they have no formulas (unlike `Data`).
- Adding a tab to the live sheet is a visible change. It happens only on your first save, and only after you
  switch live writes on.

## 7. Decisions I need from you

- **D1 — Themes.** ✅ Taken as decided: all 5 themes, picked on the Settings page. Assumed shared layout
  as recommended below. Original note: Recommended: all 5 share one layout skeleton (same screens, same components). Each
  theme changes colours, fonts, borders, shadows, the nav style and a few signature details. Examples:
  the cluster gauge, the Doha sentence-style form, the brutalist pump display. That keeps 5 themes
  maintainable.
  - Alternative 1: fully separate layouts per theme (≈2× the phase 7 work).
  - Alternative 2: pick 1 theme now, add others later.
- **D2 — Login wall setup.** ✅ Decided: you click through the dashboard with [SETUP-GUIDE.md](SETUP-GUIDE.md).
  That way the Google client secret goes straight from Google into Cloudflare, and no API token is needed.
- **D3 — Logins.** ✅ Decided: Google only.
- **D4 — Default theme** on first load (you can switch any time). Suggestion: 1 Instrument Cluster on dark
  phones, 4 Soft Fintech on light.
- **D5 — Repo.** Recommended: create branch `feat/web-app` from `main` and keep everything in `web/`;
  commits only when you say so.

## 8. What I'll do the moment you approve

1. Phase 1 sheet backup + fixes (I have edit access to the sheet through the Google Sheets connector).
2. Write the phase 0 guide for the three Google/Cloudflare credentials, and wait for you to finish those.
3. Scaffold and deploy phase 2.

Reply with "approved", plus your answers to D1–D5, or with any changes to this plan.
