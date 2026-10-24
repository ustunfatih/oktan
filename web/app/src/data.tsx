import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from "react";
import type { DataResponse, WoqodResponse } from "../../shared/types";

export type LoadError = { kind: "session" | "server" | "network"; message: string; detail?: string };

interface DataState {
  data: DataResponse | null;
  error: LoadError | null;
  /** True while a request is in flight (first load or refresh). */
  loading: boolean;
  refresh: () => void;
}

const CACHE_KEY = "oktan:data:v1";
const STALE_MS = 60_000;

// Per-device convenience only: shows the last known numbers instantly while the sheet is re-read.
function readCache(): DataResponse | null {
  try {
    const raw = localStorage.getItem(CACHE_KEY);
    return raw ? (JSON.parse(raw) as DataResponse) : null;
  } catch {
    return null;
  }
}
function writeCache(data: DataResponse) {
  try {
    localStorage.setItem(CACHE_KEY, JSON.stringify(data));
  } catch {
    /* storage unavailable (private mode): fine */
  }
}

/**
 * GET an API route. When the Cloudflare Access session has expired, Access answers with a redirect
 * to its login page; `redirect: "manual"` turns that into an opaque response we can recognise.
 */
export async function api<T>(path: string): Promise<T> {
  let res: Response;
  try {
    res = await fetch(path, { redirect: "manual", headers: { accept: "application/json" } });
  } catch (e) {
    throw { kind: "network", message: "Can't reach Oktan. Check your connection.", detail: String(e) } satisfies LoadError;
  }
  if (res.type === "opaqueredirect" || res.status === 401) {
    throw { kind: "session", message: "Your sign-in has expired." } satisfies LoadError;
  }
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw { kind: "server", message: body.error ?? `Error ${res.status}`, detail: body.detail } satisfies LoadError;
  }
  return body as T;
}

const DataContext = createContext<DataState | null>(null);

export function DataProvider({ children }: { children: ReactNode }) {
  const [data, setData] = useState<DataResponse | null>(readCache);
  const [error, setError] = useState<LoadError | null>(null);
  const [loading, setLoading] = useState(true);
  const lastLoad = useRef(0);

  const load = useCallback(async (fresh: boolean) => {
    setLoading(true);
    lastLoad.current = Date.now();
    try {
      const next = await api<DataResponse>(`/api/data${fresh ? "?fresh=1" : ""}`);
      setData(next);
      setError(null);
      writeCache(next);
    } catch (e) {
      setError(e as LoadError);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load(false);
    // Coming back to the app (e.g. after logging a fill-up in the sheet): re-read if stale.
    const onVisible = () => {
      if (document.visibilityState === "visible" && Date.now() - lastLoad.current > STALE_MS) load(true);
    };
    document.addEventListener("visibilitychange", onVisible);
    return () => document.removeEventListener("visibilitychange", onVisible);
  }, [load]);

  return (
    <DataContext.Provider value={{ data, error, loading, refresh: () => load(true) }}>{children}</DataContext.Provider>
  );
}

export function useData(): DataState {
  const ctx = useContext(DataContext);
  if (!ctx) throw new Error("useData outside DataProvider");
  return ctx;
}

/** Current WOQOD prices; failures are reported in the response, never thrown. */
export function useWoqod(): WoqodResponse | null {
  const [state, setState] = useState<WoqodResponse | null>(null);
  useEffect(() => {
    api<WoqodResponse>("/api/woqod")
      .then(setState)
      .catch((e: LoadError) => setState({ ok: false, error: e.message }));
  }, []);
  return state;
}
