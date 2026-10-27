import { reduceMotion } from "./motion";

/** How long the launch splash stays up: the sweep plus the wordmark, or a moment with Reduce Motion on. */
const MIN_MS = 1300;
const MIN_REDUCED_MS = 350;
/** Never longer than this, even if the first screen is slow (the app shows its own loading state). */
export const MAX_MS = 6000;

let hiding = false;

/** Fades the splash out once its animation has run, then removes it. Safe to call more than once. */
export function hideSplash() {
  const el = document.getElementById("splash");
  if (!el || hiding) return;
  hiding = true;
  const wait = Math.max(0, (reduceMotion() ? MIN_REDUCED_MS : MIN_MS) - performance.now());
  setTimeout(() => {
    el.classList.add("splash--done");
    setTimeout(() => el.remove(), 300);
  }, wait);
}
