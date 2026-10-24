import { Hono } from "hono";
import { requireAccess } from "./access";
import { LIVE_SHEET_ID, type Env } from "./env";
import { GoogleAuthError } from "./google";
import { getValues, SheetsApiError } from "./sheets";
import { lastClosedEntry, latestEntry, summarize } from "../shared/metrics";
import { parseEntries, SheetLayoutError } from "../shared/parse";
import type { SummaryResponse } from "../shared/types";

const app = new Hono<{ Bindings: Env; Variables: { email: string } }>();

app.use("/api/*", requireAccess);

app.get("/api/me", (c) => c.json({ email: c.get("email") }));

app.get("/api/summary", async (c) => {
  const entries = parseEntries(await getValues(c.env, "Data!A1:P"));
  const body: SummaryResponse = {
    email: c.get("email"),
    sheet: c.env.SHEET_ID === LIVE_SHEET_ID ? "live" : "dev",
    summary: summarize(entries),
    latest: latestEntry(entries),
    lastClosed: lastClosedEntry(entries),
  };
  return c.json(body);
});

app.notFound((c) => c.json({ error: "Not found" }, 404));

app.onError((err, c) => {
  if (err instanceof GoogleAuthError) return c.json({ error: "Google connection is not set up", detail: err.message }, 503);
  if (err instanceof SheetLayoutError) return c.json({ error: "The sheet's layout changed", detail: err.message }, 409);
  if (err instanceof SheetsApiError) return c.json({ error: "Could not read the sheet", detail: err.message }, 502);
  console.error(err);
  return c.json({ error: "Unexpected error" }, 500);
});

export default app;
