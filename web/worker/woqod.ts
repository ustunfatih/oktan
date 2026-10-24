import type { WoqodPrice, WoqodResponse } from "../shared/types";

const ENDPOINT = "https://www.woqod.com/fo_api_website/api/RetailPage/GetFuelPrices";
const CACHE_KEY = "https://oktan.internal/woqod/prices";
const CACHE_SECONDS = 6 * 60 * 60;

interface RawPrice {
  fuelTypeEn?: string;
  price?: string | number;
  dateFrom?: string;
}

/**
 * WOQOD's retail page loads its prices from this endpoint. The body is a JSON string that itself
 * contains JSON, so it is parsed twice. Only the current month is returned.
 */
export function parseWoqod(body: unknown): WoqodPrice[] {
  const list = typeof body === "string" ? JSON.parse(body) : body;
  if (!Array.isArray(list)) throw new Error("Unexpected WOQOD response shape");
  return (list as RawPrice[]).flatMap((p) => {
    const price = Number(p.price);
    const month = p.dateFrom?.slice(0, 7);
    if (!p.fuelTypeEn || !Number.isFinite(price) || !month || !/^\d{4}-\d{2}$/.test(month)) return [];
    return [{ grade: p.fuelTypeEn.trim(), price, month }];
  });
}

export async function fetchWoqod(fresh = false): Promise<WoqodResponse> {
  const result = await fetchWoqodUncached(fresh);
  if (!result.ok) console.warn(`WOQOD price fetch failed: ${result.error}`);
  return result;
}

async function fetchWoqodUncached(fresh: boolean): Promise<WoqodResponse> {
  const cache = caches.default;
  if (!fresh) {
    const hit = await cache.match(CACHE_KEY);
    if (hit) return hit.json();
  }
  try {
    const res = await fetch(ENDPOINT, {
      headers: {
        accept: "application/json",
        "user-agent": "Mozilla/5.0 (compatible; OktanFuelTracker/1.0; +https://oktan.ustunfatih.com)",
      },
    });
    const text = await res.text();
    if (!res.ok) return { ok: false, error: `WOQOD answered ${res.status}` };
    if (text.trimStart().startsWith("<")) return { ok: false, error: "WOQOD returned a web page instead of prices (likely blocked)" };
    const prices = parseWoqod(JSON.parse(text));
    if (!prices.length) return { ok: false, error: "WOQOD returned no prices" };
    const body: WoqodResponse = { ok: true, prices, fetchedAt: new Date().toISOString() };
    await cache.put(
      CACHE_KEY,
      new Response(JSON.stringify(body), {
        headers: { "content-type": "application/json", "cache-control": `max-age=${CACHE_SECONDS}` },
      }),
    );
    return body;
  } catch (e) {
    return { ok: false, error: `Could not reach WOQOD: ${e instanceof Error ? e.message : String(e)}` };
  }
}
