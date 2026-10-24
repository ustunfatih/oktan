import { useEffect, useState } from "react";
import { resolveTheme } from "../../shared/settings";

const DEVICE_KEY = "oktan:theme-device";
/** Last applied theme and its font URL, read by the inline script in index.html to avoid a flash. */
const APPLIED_KEY = "oktan:theme-applied";

/** Each theme's two Google Fonts families; only the active theme's fonts are loaded. */
export const THEME_FONTS: Record<string, string> = {
  cluster: "family=Chakra+Petch:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700",
  swiss: "family=Inter+Tight:wght@400;500;600;800&family=IBM+Plex+Mono:wght@400;500",
  doha: "family=Fraunces:opsz,wght@9..144,400;9..144,600;9..144,700&family=Work+Sans:wght@400;500;600",
  fintech: "family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=DM+Mono:wght@400;500",
  brutalist: "family=Space+Grotesk:wght@500;700&family=Space+Mono:wght@400;700",
};
export const fontsUrl = (theme: string) => `https://fonts.googleapis.com/css2?${THEME_FONTS[theme] ?? THEME_FONTS.cluster}&display=swap`;

// Browser storage is fine for these: losing them just means the sheet's theme applies.
export function readDeviceTheme(): string | null {
  try {
    return localStorage.getItem(DEVICE_KEY);
  } catch {
    return null;
  }
}

export function writeDeviceTheme(theme: string | null) {
  try {
    if (theme) localStorage.setItem(DEVICE_KEY, theme);
    else localStorage.removeItem(DEVICE_KEY);
  } catch {
    /* storage unavailable: the sheet's theme still applies */
  }
  dispatchEvent(new Event("oktan-theme"));
}

const darkQuery = () => matchMedia("(prefers-color-scheme: dark)");

function applyTheme(theme: string) {
  const root = document.documentElement;
  root.dataset.theme = theme;
  const link = document.getElementById("theme-fonts") as HTMLLinkElement | null;
  const href = fontsUrl(theme);
  if (link && link.href !== href) link.href = href;
  // The browser/OS chrome colour follows the theme's top bar.
  const bar = getComputedStyle(root).getPropertyValue("--bar").trim();
  document.querySelector('meta[name="theme-color"]')?.setAttribute("content", bar || "#0A0C0F");
  try {
    localStorage.setItem(APPLIED_KEY, JSON.stringify({ theme, href }));
  } catch {
    /* fine */
  }
}

/** Applies the resolved theme and re-applies when the sheet setting, the device override or dark/light changes. */
export function useAppliedTheme(sheetTheme: string | undefined) {
  const [device, setDevice] = useState(readDeviceTheme);
  const [prefersDark, setPrefersDark] = useState(() => darkQuery().matches);
  useEffect(() => {
    const onTheme = () => setDevice(readDeviceTheme());
    const mq = darkQuery();
    const onScheme = () => setPrefersDark(mq.matches);
    addEventListener("oktan-theme", onTheme);
    mq.addEventListener("change", onScheme);
    return () => {
      removeEventListener("oktan-theme", onTheme);
      mq.removeEventListener("change", onScheme);
    };
  }, []);
  const resolved = resolveTheme(sheetTheme ?? "auto", device, prefersDark);
  useEffect(() => applyTheme(resolved), [resolved]);
  return resolved;
}
