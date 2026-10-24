import { SETTING_KEYS } from "../shared/parse";
import type { SettingsPatch, StationsPlan } from "../shared/settings";
import type { StationItem } from "../shared/types";
import type { Env } from "./env";
import { batchGet, batchUpdate, getMeta, SETTINGS_RANGE } from "./sheets";
import { appLogRequests, cell } from "./writes";

const normalize = (v: unknown) => String(v ?? "").replace(/\s+/g, " ").trim().toLowerCase();

async function settingsContext(env: Env, spreadsheetId: string) {
  const [[values = []], meta] = await Promise.all([batchGet(env, spreadsheetId, [SETTINGS_RANGE]), getMeta(env, spreadsheetId)]);
  const tab = meta.tabs.find((t) => t.title === "Settings");
  if (!tab) throw new Error("The sheet has no Settings tab.");
  return { values, meta, tabId: tab.sheetId };
}

/** Writes changed key/value settings into column B of the rows whose label matches (Settings tab). */
export async function writeSettings(env: Env, spreadsheetId: string, patch: SettingsPatch, by: string): Promise<string> {
  const { values, meta, tabId } = await settingsContext(env, spreadsheetId);
  const requests: unknown[] = [];
  const changed: string[] = [];
  for (const [key, value] of Object.entries(patch) as [keyof SettingsPatch, string | number][]) {
    const index = values.findIndex((r) => SETTING_KEYS[normalize(r[0])] === key);
    if (index < 1) throw new Error(`The Settings tab has no row for "${key}".`);
    if (String(values[index]![1] ?? "") === String(value)) continue;
    requests.push({
      updateCells: { range: { sheetId: tabId, startRowIndex: index, endRowIndex: index + 1, startColumnIndex: 1, endColumnIndex: 2 }, rows: [{ values: [cell(value)] }], fields: "userEnteredValue" },
    });
    changed.push(String(values[index]![0]));
  }
  if (!requests.length) return "Nothing changed.";
  requests.push(...appLogRequests(meta, ["settings", by, changed.join(", "), "", JSON.stringify(patch)]));
  await batchUpdate(env, spreadsheetId, requests);
  return `Saved: ${changed.join(", ")}.`;
}

/**
 * Rewrites the station list (Settings E2:F, F = archived) and, when asked, renames stations in past
 * fill-ups (exact matches in Data column I) — all in one batchUpdate.
 */
export async function writeStations(env: Env, spreadsheetId: string, plan: StationsPlan, before: StationItem[], by: string): Promise<string> {
  const { values, meta, tabId } = await settingsContext(env, spreadsheetId);
  const lastUsed = values.reduce((last, r, i) => (i > 0 && String(r[4] ?? "").trim() ? i : last), 0);
  const rowCount = Math.max(lastUsed, plan.list.length);
  const rows = Array.from({ length: rowCount }, (_, i) => {
    const s = plan.list[i];
    return { values: s ? [cell(s.name), cell(s.archived ? true : null)] : [cell(null), cell(null)] };
  });
  const requests: unknown[] = [
    { updateCells: { range: { sheetId: tabId, startRowIndex: 0, endRowIndex: 1, startColumnIndex: 5, endColumnIndex: 6 }, rows: [{ values: [cell("Archived")] }], fields: "userEnteredValue" } },
  ];
  if (rowCount) {
    requests.push({ updateCells: { range: { sheetId: tabId, startRowIndex: 1, endRowIndex: 1 + rowCount, startColumnIndex: 4, endColumnIndex: 6 }, rows, fields: "userEnteredValue" } });
  }

  const data = meta.tabs.find((t) => t.title === "Data");
  if (plan.renames.length && !data) throw new Error("The sheet has no Data tab.");
  for (const r of plan.renames) {
    requests.push({
      findReplace: {
        find: r.from,
        replacement: r.to,
        range: { sheetId: data!.sheetId, startRowIndex: 1, startColumnIndex: 8, endColumnIndex: 9 },
        matchCase: true,
        matchEntireCell: true,
      },
    });
  }
  requests.push(...appLogRequests(meta, ["stations", by, plan.renames.map((r) => `${r.from} → ${r.to}`).join("; "), JSON.stringify(before), JSON.stringify(plan.list)]));
  await batchUpdate(env, spreadsheetId, requests);
  const renamed = plan.renames.length ? ` Renamed in past fill-ups: ${plan.renames.map((r) => `${r.from} → ${r.to}`).join(", ")}.` : "";
  return `Station list saved.${renamed}`;
}
