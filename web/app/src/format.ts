const nf = (digits: number) =>
  new Intl.NumberFormat("en-GB", { minimumFractionDigits: digits, maximumFractionDigits: digits });

export const fmt = (n: number | null | undefined, digits = 0) => (n == null ? "—" : nf(digits).format(n));

export const qar = (n: number | null | undefined, digits = 2) => (n == null ? "—" : `QAR ${fmt(n, digits)}`);

export const fmtDate = (iso: string) =>
  new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short", year: "numeric", timeZone: "UTC" }).format(
    new Date(`${iso}T00:00:00Z`),
  );
