/**
 * Axis helpers for the charts. One bad value must never stretch an axis until its labels are unreadable,
 * so the scale ignores outliers (Tukey fences) and shows them at the edge, marked as off scale.
 */

/** A "nice" step (1, 2, 2.5, 5 or 10 times a power of ten) that gives at most `maxTicks` intervals across `span`. */
export function niceStep(span: number, maxTicks: number): number {
  const raw = Math.max(span, 1e-9) / Math.max(1, maxTicks);
  const pow = 10 ** Math.floor(Math.log10(raw));
  for (const m of [1, 2, 2.5, 5, 10]) if (m * pow >= raw - 1e-12) return m * pow;
  return 10 * pow;
}

/** Tick values from lo to hi (inclusive) on a nice step, at most `maxTicks` intervals. */
export function ticks(lo: number, hi: number, maxTicks = 5): number[] {
  const step = niceStep(hi - lo, maxTicks);
  const out: number[] = [];
  const first = Math.ceil(lo / step - 1e-9) * step;
  for (let v = first; v <= hi + step * 1e-9; v += step) out.push(Number((Math.round(v / step) * step).toFixed(10)));
  return out;
}

/** Linear-interpolated quantile of an already sorted array. */
function quantile(sorted: number[], q: number): number {
  const pos = (sorted.length - 1) * q;
  const base = Math.floor(pos);
  const rest = pos - base;
  return sorted[base + 1] !== undefined ? sorted[base]! + rest * (sorted[base + 1]! - sorted[base]!) : sorted[base]!;
}

/**
 * The axis range for a set of values: from the lowest to the highest value that isn't an outlier, rounded out to
 * nice ticks. Outliers are the values outside Tukey's fences (1.5 × the interquartile range beyond the quartiles).
 * `minSpan` keeps very flat data from being stretched.
 */
export function robustRange(values: number[], minSpan = 1, maxTicks = 5): { lo: number; hi: number; outliers: Set<number> } {
  if (!values.length) return { lo: 0, hi: 1, outliers: new Set() };
  const sorted = [...values].sort((a, b) => a - b);
  const q1 = quantile(sorted, 0.25);
  const q3 = quantile(sorted, 0.75);
  const iqr = q3 - q1;
  const fenceLo = q1 - 1.5 * iqr;
  const fenceHi = q3 + 1.5 * iqr;
  const inside = sorted.filter((v) => v >= fenceLo && v <= fenceHi);
  const outliers = new Set(values.filter((v) => v < fenceLo || v > fenceHi));
  let lo = inside.length ? inside[0]! : sorted[0]!;
  let hi = inside.length ? inside[inside.length - 1]! : sorted[sorted.length - 1]!;
  if (hi - lo < minSpan) {
    const mid = (hi + lo) / 2;
    lo = mid - minSpan / 2;
    hi = mid + minSpan / 2;
  }
  const step = niceStep(hi - lo, maxTicks);
  lo = Math.floor(lo / step - 1e-9) * step;
  hi = Math.ceil(hi / step - 1e-9) * step;
  if (hi === lo) hi = lo + step;
  return { lo, hi, outliers };
}
