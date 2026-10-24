export interface Env {
  ACCESS_TEAM_DOMAIN: string;
  ACCESS_AUD: string;
  ALLOWED_EMAIL: string;
  SHEET_ID: string;
  /** Service account key JSON (secret). */
  GOOGLE_SA_KEY?: string;
  /** Local development only: identity used for requests from localhost. */
  DEV_EMAIL?: string;
}

export const LIVE_SHEET_ID = "1Gk9BvaD4bYf9Q3ss-v09Ezr64XrFd9MCMPSMYUEh9P8";
