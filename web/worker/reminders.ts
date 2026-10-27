import { daysBetween } from "../shared/maintenance";
import { parseEntries } from "../shared/parse";
import type { Env } from "./env";
import { PushNotConfigured, sendPush, type PushSubscription } from "./push";
import { readWorkbook } from "./sheets";

/** Subscriptions and reminder settings live in KV: device credentials, kept out of the sheet. */

export interface Prefs {
  /** Remind after this many days without a fill-up. */
  afterDays: number;
  /** The fill-up the last reminder was about, so one fill-up gives one reminder. */
  notifiedFor?: string;
  /** The key-creation date the rotation notice was sent for. */
  keyNoticeFor?: string;
}

const PREFS = "prefs";
const SUB = "sub:";
const DEFAULT_PREFS: Prefs = { afterDays: 10 };
/** Google suggests rotating service account keys about yearly; the notice comes a little before a year. */
export const KEY_NOTICE_DAYS = 330;

const enc = new TextEncoder();
const hex = (buf: ArrayBuffer) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");

async function subKey(endpoint: string) {
  return SUB + hex(await crypto.subtle.digest("SHA-256", enc.encode(endpoint)));
}

export async function getPrefs(kv: KVNamespace): Promise<Prefs> {
  return { ...DEFAULT_PREFS, ...((await kv.get<Prefs>(PREFS, "json")) ?? {}) };
}

export async function savePrefs(kv: KVNamespace, prefs: Prefs) {
  await kv.put(PREFS, JSON.stringify(prefs));
}

export async function countSubscriptions(kv: KVNamespace): Promise<number> {
  return (await kv.list({ prefix: SUB })).keys.length;
}

export async function addSubscription(kv: KVNamespace, sub: PushSubscription) {
  await kv.put(await subKey(sub.endpoint), JSON.stringify({ endpoint: sub.endpoint, keys: sub.keys, createdAt: new Date().toISOString() }));
}

export async function removeSubscription(kv: KVNamespace, endpoint: string) {
  await kv.delete(await subKey(endpoint));
}

/** Sends to every subscribed browser. Subscriptions the push service says are gone are forgotten. */
export async function broadcast(env: Env, message: { title: string; body: string; url?: string; tag?: string }) {
  const kv = env.PUSH;
  const result = { sent: 0, removed: 0, failed: 0 };
  if (!kv) return result;
  const list = await kv.list({ prefix: SUB });
  for (const k of list.keys) {
    const sub = await kv.get<PushSubscription>(k.name, "json");
    if (!sub) continue;
    try {
      const status = await sendPush(env, sub, message);
      if (status === 201) result.sent++;
      else if (status === 404 || status === 410) {
        await kv.delete(k.name);
        result.removed++;
      } else {
        result.failed++;
        console.error(JSON.stringify({ event: "push_failed", status }));
      }
    } catch (e) {
      result.failed++;
      console.error(JSON.stringify({ event: "push_failed", message: e instanceof PushNotConfigured ? e.message : String(e).slice(0, 300) }));
    }
  }
  return result;
}

/** Adds `days` to a YYYY-MM-DD date. */
export const addDays = (iso: string, days: number) => new Date(Date.parse(`${iso}T00:00:00Z`) + days * 86_400_000).toISOString().slice(0, 10);

/**
 * Runs once a day. Sends a fill-up reminder when it's been long enough since the last one, and a key-rotation
 * notice once the Google key is about a year old. Each is sent once per fill-up or per key.
 */
export async function dailyCheck(env: Env, today: string) {
  if (!env.PUSH) return { skipped: "no subscriptions store" };
  const prefs = await getPrefs(env.PUSH);
  const out: Record<string, unknown> = {};

  const wb = await readWorkbook(env, env.SHEET_ID, true);
  const entries = parseEntries(wb.data);
  const last = entries.reduce<(typeof entries)[number] | null>((a, e) => (!a || e.date > a.date ? e : a), null);
  if (last && last.id !== prefs.notifiedFor) {
    const days = daysBetween(last.date, today);
    if (days >= prefs.afterDays) {
      out.reminder = await broadcast(env, {
        title: "Time for a fill-up?",
        body: `${days} days since your last fill-up. Log it while it's fresh.`,
        url: "/log",
        tag: "fill-up-reminder",
      });
      prefs.notifiedFor = last.id;
    }
  }

  const created = env.KEY_CREATED_ON;
  if (created && today >= addDays(created, KEY_NOTICE_DAYS) && prefs.keyNoticeFor !== created) {
    out.keyNotice = await broadcast(env, {
      title: "Rotate the Google key",
      body: `The service account key is from ${created}. Make a new one and load it. The README has the steps.`,
      url: "/settings",
      tag: "key-rotation",
    });
    prefs.keyNoticeFor = created;
  }

  await savePrefs(env.PUSH, prefs);
  return out;
}
