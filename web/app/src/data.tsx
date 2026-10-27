import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from "react";
import type { DataResponse, WriteResponse, WoqodResponse } from "../../shared/types";
import type { Entry } from "../../shared/types";
import type { EntryInput, FieldErrors } from "../../shared/writes";
import { loadQueue, removeQueued, saveQueued, type QueuedEntry } from "./outbox";

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
  /** Fill-ups saved on this phone that haven't reached the sheet yet. */
  pending: QueuedEntry[];
  /** Keep a fill-up for when the phone is back online. */
  queueEntry: (entry: EntryInput, lastIdSeen: string | null) => Promise<void>;
  /** Try to send the waiting fill-ups now. */
  sendPending: () => void;
  discardPending: (id: string) => Promise<void>;
}

// Bump the version whenever DataResponse changes shape, so an older saved copy is ignored.
const CACHE_KEY = "oktan:data:v3";
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

/** A saved fill-up that matches a queued one: the same day, odometer and litres. Used after a lost reply. */
const sameFillUp = (entry: EntryInput) => (e: Entry) => e.date === entry.date && e.odometer === entry.odometer && Math.abs(e.liters - entry.liters) < 0.005;

export function DataProvider({ children }: { children: ReactNode }) {
  const [data, setDataState] = useState<DataResponse | null>(readCache);
  const [error, setError] = useState<LoadError | null>(null);
  const [loading, setLoading] = useState(true);
  const lastLoad = useRef(0);
  const [pending, setPending] = useState<QueuedEntry[]>([]);
  const flushing = useRef(false);

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

  /**
   * Sends the waiting fill-ups in the order they were saved. Stops at the first sign of no connection, so
   * nothing is lost. A fill-up the sheet already has (its reply was lost on the way) is dropped quietly.
   */
  const flushOutbox = useCallback(async () => {
    if (flushing.current) return;
    flushing.current = true;
    try {
      for (const q of await loadQueue()) {
        try {
          const res = await api<WriteResponse>("/api/entries", { method: "POST", body: { entry: q.entry, lastIdSeen: q.lastIdSeen } });
          await removeQueued(q.id);
          setData(res.data);
        } catch (e) {
          const w = e as WriteError;
          if (w.kind === "network") break;
          if (w.data?.entries.some(sameFillUp(q.entry))) {
            await removeQueued(q.id);
            setData(w.data);
          } else {
            await saveQueued({ ...q, error: w.message });
          }
        }
      }
    } finally {
      flushing.current = false;
      setPending(await loadQueue());
    }
  }, [setData]);

  const queueEntry = useCallback(async (entry: EntryInput, lastIdSeen: string | null) => {
    await saveQueued({ id: crypto.randomUUID(), entry, lastIdSeen, queuedAt: new Date().toISOString() });
    setPending(await loadQueue());
  }, []);

  const discardPending = useCallback(async (id: string) => {
    await removeQueued(id);
    setPending(await loadQueue());
  }, []);

  useEffect(() => {
    loadQueue().then(setPending);
    const onOnline = () => flushOutbox();
    addEventListener("online", onOnline);
    flushOutbox();
    return () => removeEventListener("online", onOnline);
  }, [flushOutbox]);

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
    <DataContext.Provider
      value={{
        data,
        error,
        loading,
        refresh: () => load(true),
        setData,
        setSheet,
        pending,
        queueEntry,
        sendPending: () => void flushOutbox(),
        discardPending,
      }}
    >
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
