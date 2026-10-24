import { useEffect, useState } from "react";
import { resolveTheme } from "../../shared/settings";

const KEY = "oktan:theme-device";

// Per-device override (e.g. a different theme on the phone). Browser storage is fine here: losing it
// just means falling back to the theme saved in the sheet.
export function readDeviceTheme(): string | null {
  try {
    return localStorage.getItem(KEY);
  } catch {
    return null;
  }
}

export function writeDeviceTheme(theme: string | null) {
  try {
    if (theme) localStorage.setItem(KEY, theme);
    else localStorage.removeItem(KEY);
  } catch {
    /* storage unavailable: the sheet's theme still applies */
  }
  dispatchEvent(new Event("oktan-theme"));
}

/** Applies the resolved theme to <html data-theme> and re-applies when either source changes. */
export function useAppliedTheme(sheetTheme: string | undefined) {
  const [device, setDevice] = useState(readDeviceTheme);
  useEffect(() => {
    const on = () => setDevice(readDeviceTheme());
    addEventListener("oktan-theme", on);
    return () => removeEventListener("oktan-theme", on);
  }, []);
  const resolved = resolveTheme(sheetTheme ?? "auto", device);
  useEffect(() => {
    document.documentElement.dataset.theme = resolved;
  }, [resolved]);
  return resolved;
}
