import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from "react";
import type { DataResponse, WoqodResponse } from "../../shared/types";
import type { FieldErrors } from "../../shared/writes";

export type LoadError = { kind: "session" | "server" | "network"; message: string; detail?: string };
/** A refused write: the message, any per-field errors, and the fresh sheet when the server sent it. */
export type WriteError = LoadError & { fields?: FieldErrors; data?: DataResponse };

interface DataState {
  data: DataResponse | null;
  error: LoadError | null;
  /** True while a request is in flight (first load or refresh). */
  loading: boolean;
  refresh: () => void;
  /** Replace the data with what a write returned. */
  setData: (data: DataResponse) => void;
  /** Switch between the live sheet and the DEV copy (test mode). */
  setSheet: (sheet: "live" | "dev") => Promise<void>;
}

// Bump the version whenever DataResponse changes shape, so an older saved copy is ignored.
const CACHE_KEY = "oktan:data:v2";
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
 * Calls an API route. When the Cloudflare Access session has expired, Access answers with a redirect
 * to its login page; `redirect: "manual"` turns that into an opaque response we can recognise.
 */
export async function api<T>(path: string, init?: { method: string; body: unknown }): Promise<T> {
  let res: Response;
  try {
    res = await fetch(path, {
      method: init?.method ?? "GET",
      redirect: "manual",
      headers: { accept: "application/json", ...(init ? { "content-type": "application/json" } : {}) },
      body: init ? JSON.stringify(init.body) : undefined,
    });
  } catch (e) {
    throw { kind: "network", message: "Can't reach Oktan. Check your connection.", detail: String(e) } satisfies LoadError;
  }
  if (res.type === "opaqueredirect" || res.status === 401) {
    throw { kind: "session", message: "Your sign-in has expired." } satisfies LoadError;
  }
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw {
      kind: "server",
      message: body.error ?? `Error ${res.status}`,
      detail: body.detail,
      fields: body.fields,
      data: body.data,
    } satisfies WriteError;
  }
  return body as T;
}

const DataContext = createContext<DataState | null>(null);

export function DataProvider({ children }: { children: ReactNode }) {
  const [data, setDataState] = useState<DataResponse | null>(readCache);
  const [error, setError] = useState<LoadError | null>(null);
  const [loading, setLoading] = useState(true);
  const lastLoad = useRef(0);

  const setData = useCallback((next: DataResponse) => {
    setDataState(next);
    setError(null);
    writeCache(next);
    lastLoad.current = Date.now();
  }, []);

  const load = useCallback(
    async (fresh: boolean) => {
      setLoading(true);
      lastLoad.current = Date.now();
      try {
        setData(await api<DataResponse>(`/api/data${fresh ? "?fresh=1" : ""}`));
      } catch (e) {
        setError(e as LoadError);
      } finally {
        setLoading(false);
      }
    },
    [setData],
  );

  const setSheet = useCallback(
    async (sheet: "live" | "dev") => {
      setLoading(true);
      try {
        setData(await api<DataResponse>("/api/mode", { method: "POST", body: { sheet } }));
      } catch (e) {
        setError(e as LoadError);
      } finally {
        setLoading(false);
      }
    },
    [setData],
  );

  useEffect(() => {
    load(false);
    // Coming back to the app (e.g. after typing into the sheet directly): re-read if stale.
    const onVisible = () => {
      if (document.visibilityState === "visible" && Date.now() - lastLoad.current > STALE_MS) load(true);
    };
    document.addEventListener("visibilitychange", onVisible);
    return () => document.removeEventListener("visibilitychange", onVisible);
  }, [load]);

  return (
    <DataContext.Provider value={{ data, error, loading, refresh: () => load(true), setData, setSheet }}>
      {children}
    </DataContext.Provider>
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
