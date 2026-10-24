const nf = (digits: number) =>
  new Intl.NumberFormat("en-GB", { minimumFractionDigits: digits, maximumFractionDigits: digits });

export const fmt = (n: number | null | undefined, digits = 0) => (n == null ? "—" : nf(digits).format(n));

export const qar = (n: number | null | undefined, digits = 2) => (n == null ? "—" : `QAR ${fmt(n, digits)}`);

const utc = (iso: string) => new Date(`${iso.length === 7 ? `${iso}-01` : iso}T00:00:00Z`);

/** 21 Oct 2026 */
export const fmtDate = (iso: string) =>
  `${Number(iso.slice(8, 10))} ${monthOf(iso).charAt(0)}${monthOf(iso).slice(1).toLowerCase()} ${iso.slice(0, 4)}`;

// Fixed three-letter months: en-GB's Intl output says "Sept", which breaks the column rhythm.
const MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
const monthOf = (iso: string) => MONTHS[Number(iso.slice(5, 7)) - 1]!;

/** 21 OCT */
export const fmtDayMonth = (iso: string) => `${iso.slice(8, 10)} ${monthOf(iso)}`;

/** OCT 26, from YYYY-MM or a full date */
export const fmtMonth = (iso: string) => `${monthOf(iso)} ${iso.slice(2, 4)}`;

/** October 2026 */
export const fmtMonthLong = (iso: string) =>
  new Intl.DateTimeFormat("en-GB", { month: "long", year: "numeric", timeZone: "UTC" }).format(utc(iso));

/** "just now", "4 min ago", "2 h ago" */
export function fmtAgo(iso: string, now = Date.now()) {
  const min = Math.round((now - Date.parse(iso)) / 60_000);
  if (min < 1) return "just now";
  if (min < 60) return `${min} min ago`;
  const h = Math.round(min / 60);
  return h < 24 ? `${h} h ago` : fmtDate(iso.slice(0, 10));
}

/** Today's date in Qatar as YYYY-MM-DD, whatever the device's time zone. */
export const qatarToday = () => new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Qatar" }).format(new Date());
