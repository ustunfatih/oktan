export interface Env {
  ACCESS_TEAM_DOMAIN: string;
  ACCESS_AUD: string;
  ALLOWED_EMAIL: string;
  SHEET_ID: string;
  /** Oktan DEV copy, selectable in the app as "test mode". */
  DEV_SHEET_ID?: string;
  /** "true" unlocks writing to the live sheet. Writes to any other sheet are always allowed. */
  LIVE_WRITES?: string;
  /** Service account key JSON (secret). */
  GOOGLE_SA_KEY?: string;
  /** Local development only: identity used for requests from localhost. */
  DEV_EMAIL?: string;
}

export const LIVE_SHEET_ID = "1Gk9BvaD4bYf9Q3ss-v09Ezr64XrFd9MCMPSMYUEh9P8";
export const MODE_COOKIE = "oktan_sheet";

export interface ActiveSheet {
  id: string;
  kind: "live" | "dev";
  canWrite: boolean;
  testModeAvailable: boolean;
}

/** Which spreadsheet this request works on: the live sheet, or the DEV copy when test mode is on. */
export function activeSheet(env: Env, cookie: string | undefined): ActiveSheet {
  const testModeAvailable = !!env.DEV_SHEET_ID && env.DEV_SHEET_ID !== env.SHEET_ID;
  const wantsDev = new RegExp(`(?:^|;\\s*)${MODE_COOKIE}=dev(?:;|$)`).test(cookie ?? "");
  const id = testModeAvailable && wantsDev ? env.DEV_SHEET_ID! : env.SHEET_ID;
  const live = id === LIVE_SHEET_ID;
  return { id, kind: live ? "live" : "dev", canWrite: !live || env.LIVE_WRITES === "true", testModeAvailable };
}
