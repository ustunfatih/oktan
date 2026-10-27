import { useEffect, useState } from "react";
import { resolveTheme } from "../../shared/settings";

const DEVICE_KEY = "oktan:theme-device";
/** Last applied theme, read by public/theme-init.js before the first paint to avoid a flash. */
const APPLIED_KEY = "oktan:theme-applied";

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
  // The browser/OS chrome colour follows the theme's top bar.
  const bar = getComputedStyle(root).getPropertyValue("--bar").trim();
  document.querySelector('meta[name="theme-color"]')?.setAttribute("content", bar || "#0A0C0F");
  try {
    localStorage.setItem(APPLIED_KEY, JSON.stringify({ theme }));
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
