import { Hono } from "hono";
import { requireAccess } from "./access";
import { LIVE_SHEET_ID, type Env } from "./env";
import { GoogleAuthError } from "./google";
import { readWorkbook, SheetsApiError } from "./sheets";
import { fetchWoqod } from "./woqod";
import { parseEntries, parsePrices, parseSettings, SheetLayoutError } from "../shared/parse";
import type { DataResponse } from "../shared/types";

const app = new Hono<{ Bindings: Env; Variables: { email: string } }>();

app.use("/api/*", requireAccess);
app.use("/api/*", async (c, next) => {
  await next();
  c.header("cache-control", "no-store");
});

app.get("/api/me", (c) => c.json({ email: c.get("email") }));

app.get("/api/data", async (c) => {
  const wb = await readWorkbook(c.env, c.req.query("fresh") === "1");
  const body: DataResponse = {
    email: c.get("email"),
    sheet: c.env.SHEET_ID === LIVE_SHEET_ID ? "live" : "dev",
    fetchedAt: wb.fetchedAt,
    entries: parseEntries(wb.data),
    prices: parsePrices(wb.prices),
    settings: parseSettings(wb.settings),
  };
  return c.json(body);
});

app.get("/api/woqod", async (c) => c.json(await fetchWoqod(c.req.query("fresh") === "1")));

app.notFound((c) => c.json({ error: "Not found" }, 404));

app.onError((err, c) => {
  if (err instanceof GoogleAuthError) return c.json({ error: "Google connection is not set up", detail: err.message }, 503);
  if (err instanceof SheetLayoutError) return c.json({ error: "The sheet's layout changed", detail: err.message }, 409);
  if (err instanceof SheetsApiError) return c.json({ error: "Could not read the sheet", detail: err.message }, 502);
  console.error(err);
  return c.json({ error: "Unexpected error" }, 500);
});

export default app;
