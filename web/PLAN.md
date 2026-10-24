# Oktan Web — evaluation & build plan

Status: **planning only** (no app code yet). **The build plan to approve is now [ROADMAP.md](ROADMAP.md)**;
this file keeps the original analysis. Mockups live in [`mockups/`](mockups/) and on the
"Oktan Web Mockups" canvas.

Target: `https://oktan.ustunfatih.com` · Data source: Google Sheet **"Qatar Fuel Tracking 2026"**
(tab `Data`) · Units: litres, km, L/100 km, km/L, QAR · Dates: `DD MMM YYYY`.

---

## 1. What I found

### The Google Sheet (read 2026-10-24)

Tabs: `Dashboard`, `Fuel Prices`, `Data`, `Calc_Data`. The app talks to `Data` and `Fuel Prices`.

`Data` columns:

| Col | Header | Entered or formula |
|---|---|---|
| A | Date | entered (date serial, shown `16-Apr-25`) |
| B | Odometer PRE | formula `=C{prev}` |
| C | Odometer POST | entered **on the next fill-up** (the odometer you read then) |
| D | Total L | entered |
| E | Price per L | entered |
| F | Total Fuel Cost | entered (you pay round amounts, e.g. QAR 91.01) |
| G | Full? | entered (checkbox) |
| H | Drive Mode | entered (Eco / Normal / Sport) |
| I | Gas Station | entered |
| J–O | Driven KM, Used FUEL, Tank PRE/POST, L/100 km, Cost per KM | formulas |

22 closed trips + 1 open trip (21 Oct 2026, odometer 8,774). Lifetime: 955.33 L, QAR 1,939.84,
8,761 km, **9.29 L/100 km**, **QAR 0.188/km**.

`Fuel Prices` tab: one row per month (`Apr-25 … Oct-26`) with the price you paid, plus
`F2` = tank capacity (47 L).

### WOQOD price automation: **possible**

`https://www.woqod.com/website/en/retail` is an Angular app that loads its prices from a JSON
endpoint you can call directly:

```
GET https://www.woqod.com/fo_api_website/api/RetailPage/GetFuelPrices
→ "[{\"fuelTypeEn\":\"Gasoline Super (95)\",\"price\":\"2.10\",\"dateFrom\":\"2026-10-01…\",\"dateTo\":\"2026-10-31…\"}, …]"
```

Tested 2026-10-24: Super 95 **2.10**, Premium 91 **1.95**, Diesel **2.05** (October 2026). Your sheet
prices match **Super 95**.

---

## 2. Issues and risks (and how the plan handles them)

### High

1. **A public URL would expose your data and let anyone write to your sheet.**
   → Put the whole subdomain behind **Cloudflare Access** (Zero Trust, free up to 50 users), allowing
   only `ustunfa@gmail.com` (Google login or a one-time email PIN). The Worker also checks the
   `Cf-Access-Jwt-Assertion` header, so the API can't be reached around Access.
2. **Each fill-up changes two rows, not one.** Odometer POST for the *previous* row is only known at the
   next fill-up, and columns K/O use the next row's litres. Saving a fill-up means:
   (a) write `C{last}` = today's odometer, (b) write A, D–I into the next empty row, (c) make sure
   B and J–O formulas exist on that row.
   → Done in one `spreadsheets.values.batchUpdate`, after re-reading the sheet to confirm the
   "last row" hasn't changed (stops double entries if you also typed into the sheet).
3. **Normal "append" will put rows in the wrong place.** Rows 25–28 already hold placeholder formulas
   (`FALSE`, `0`), so the Sheets `append` API sees them as data and writes below them.
   → The app finds the first row whose Date is empty and writes there. It doesn't use `append`.
4. **Your sheet's own dashboard will silently stop counting at row 29.** `Calc_Data` uses fixed
   ranges like `Data!$J$2:$J$29`. You're on row 24, so about 5 fill-ups (≈ 4 months) remain.
   → Fix this in the sheet (open-ended ranges `Data!$J$2:$J`) before or during phase 1. The web app
   computes its own metrics and isn't affected, but the sheet dashboard would go stale.

### Medium

5. **WOQOD's endpoint is undocumented and sits behind an F5 firewall.** Some paths already return
   "Request Rejected" (e.g. `/robots.txt`, `/api/...` without `fo_api_website`). Cloudflare's
   outbound IPs could be blocked, or the URL could change without notice.
   → Fetch from a **Cron Trigger** (daily on the 1st–3rd of each month, plus a manual "refresh" button).
   Fallback order: JSON endpoint → parse the JSON embedded in the retail page HTML → last known price.
   The price field is **always editable**. A 10-minute test from a deployed Worker is the first step
   of phase 3.
6. **WOQOD only returns the current month.** If you log a fill-up late (e.g. a September fill-up in
   October), you need September's price.
   → Each monthly fetch writes into the sheet's `Fuel Prices` tab (it's already the price history). The
   input form picks the price for the **fill-up date**, not today.
7. **The response is double-encoded JSON** (a JSON string that holds JSON) → parse twice and validate
   with a schema, failing safely.
8. **Columns are found by header text and position.** If you rename or move a column, writes would go
   to the wrong cell.
   → On every load, check the headers against the expected layout. On a mismatch, writes are
   blocked and a clear banner shows.
9. **Two separate data stores.** The iOS Oktan app keeps its own SwiftData store, and the web app uses
   the sheet. They won't sync unless the iOS app also reads the sheet (out of scope; noted for later).

### Low

10. Sheets API quota (60 reads/min per user) — cache reads in the Worker for about 60 s, and clear
    the cache on write.
11. Header quirk: column N says "100 KM/L", but the values are **L/100 km**. The app labels it correctly.
12. The last row's metrics are blank until the next fill-up (open trip). Charts leave it out and show
    it as "in progress".
13. Tank capacity 47 L is hard-coded in column M's formula. The app reads `Fuel Prices!F2`.
14. Repo: the web app lives in `web/` inside the iOS repo. That's fine, but it should go on its own
    branch from `main`, not on `feat/analytics-2`.

---

## 3. Proposed architecture

```
Browser (SPA)  ──►  oktan.ustunfatih.com  (Cloudflare Access: only you)
                         │
                   Cloudflare Worker (static assets + /api)
                    ├─ GET  /api/entries        → Sheets API (read Data, cached 60 s)
                    ├─ POST /api/entries        → Sheets API batchUpdate (2-row write)
                    ├─ GET  /api/prices         → Fuel Prices tab (+ current WOQOD)
                    ├─ POST /api/prices/refresh → fetch WOQOD now
                    └─ Cron (1st–3rd, 06:00 AST) → WOQOD → write Fuel Prices tab
```

- **One Cloudflare Worker** with static assets (Pages is being merged into Workers). Free plan is enough.
- **Frontend:** Vite + React + TypeScript; Apache ECharts for charts; tab routes `/`, `/analytics`, `/log`;
  installable as a PWA so you can log at the pump from your phone's home screen.
- **API:** Hono on the Worker, Zod validation, Vitest tests.
- **Google auth:** a **service account**. You share the sheet with its e-mail as *Editor*. Its private
  key is stored as a Worker secret, and the Worker signs a JWT with WebCrypto (no heavy `googleapis`
  package). No OAuth screen.
- **Metrics** are computed in one shared TS module (same formulas as the sheet), so the dashboard
  doesn't depend on `Calc_Data`.

Folder layout (to be created in phase 1):

```
web/
  PLAN.md
  mockups/            ← design canvas files
  app/                ← Vite React SPA
  worker/             ← Hono API, cron, Sheets client, WOQOD client
  shared/             ← types + metric calculations used by both
  wrangler.jsonc
```

---

## 4. Cloudflare setup for oktan.ustunfatih.com (you do these; I'll guide)

1. **Google Cloud:** create a project → enable *Google Sheets API* → create a service account →
   add a JSON key. Share "Qatar Fuel Tracking 2026" with the service-account e-mail (Editor).
2. **Cloudflare Worker:** `wrangler deploy` (or connect the GitHub repo with Workers Builds, root
   dir `web/`). Add secrets: `GOOGLE_SA_EMAIL`, `GOOGLE_SA_KEY`, `SHEET_ID`.
3. **Custom domain:** Worker → Settings → Domains & Routes → *Add Custom Domain* →
   `oktan.ustunfatih.com`. Cloudflare creates the DNS record and certificate. No manual CNAME needed,
   because the zone is already on Cloudflare.
4. **Cloudflare Access:** Zero Trust → Access → Applications → *Self-hosted* →
   `oktan.ustunfatih.com` → policy *Allow* → *Emails* = `ustunfa@gmail.com`. Identity: Google or
   One-time PIN. Session length: 1 month.
5. **Cron Trigger:** in `wrangler.jsonc`, `"triggers": { "crons": ["0 3 1-3 * *"] }` (03:00 UTC =
   06:00 Qatar).

---

## 5. Phases

| Phase | Scope | Done when |
|---|---|---|
| 0 | Pick a mockup style; answer open questions; fix `Calc_Data` ranges | style chosen |
| 1 | Scaffold `web/`, Worker + SPA, service-account read of `Data`, header validation, deploy behind Access on the subdomain | dashboard shows live sheet data at oktan.ustunfatih.com |
| 2 | Dashboard + Analytics tabs (KPIs, trend, monthly spend, mode/station breakdown, price history, trip table, date-range filter) | charts match sheet numbers |
| 3 | WOQOD client + cron + `Fuel Prices` write-back; test run from a deployed Worker | October price auto-appears; fallback tested |
| 4 | Log tab: form, live preview of both row writes, conflict check, optimistic UI, PWA | a test fill-up round-trips to the sheet |
| 5 | Polish: phone layout, dark/light, empty and error states, accessibility pass | — |

## 6. Open questions

1. Which mockup (or mix) do you want?
2. Keep the sheet as the only store (recommended), or add a Cloudflare D1 copy for speed/offline use?
3. Should the Log form also let you **edit or delete** past rows, or only add new ones?
4. Only one car, or should the web app plan for several (like the iOS app)?
