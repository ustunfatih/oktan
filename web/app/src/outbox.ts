import type { EntryInput } from "../../shared/writes";

/**
 * Fill-ups saved while the phone had no connection. They wait here, on this phone, and go to the sheet as
 * soon as Oktan can be reached. Stored in IndexedDB so they survive closing the app; if the browser won't
 * give us storage, they're kept in memory for this visit only.
 */
export interface QueuedEntry {
  id: string;
  entry: EntryInput;
  /** The last fill-up the form was based on; the server uses it to spot a changed sheet. */
  lastIdSeen: string | null;
  queuedAt: string;
  /** Why the last send was refused, if it was (cleared once it goes through). */
  error?: string;
}

const DB_NAME = "oktan";
const STORE = "outbox";
let memory = new Map<string, QueuedEntry>();
let db: Promise<IDBDatabase> | null = null;

function open(): Promise<IDBDatabase> {
  db ??= new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => req.result.createObjectStore(STORE, { keyPath: "id" });
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
  return db;
}

async function run<T>(mode: IDBTransactionMode, op: (store: IDBObjectStore) => IDBRequest<T>): Promise<T> {
  const tx = (await open()).transaction(STORE, mode);
  const req = op(tx.objectStore(STORE));
  return new Promise<T>((resolve, reject) => {
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

export async function loadQueue(): Promise<QueuedEntry[]> {
  try {
    const rows = await run<QueuedEntry[]>("readonly", (s) => s.getAll());
    return rows.sort((a, b) => a.queuedAt.localeCompare(b.queuedAt));
  } catch {
    return [...memory.values()].sort((a, b) => a.queuedAt.localeCompare(b.queuedAt));
  }
}

export async function saveQueued(q: QueuedEntry): Promise<void> {
  memory.set(q.id, q);
  try {
    await run("readwrite", (s) => s.put(q));
  } catch {
    /* kept in memory above */
  }
}

export async function removeQueued(id: string): Promise<void> {
  memory.delete(id);
  try {
    await run("readwrite", (s) => s.delete(id));
  } catch {
    /* gone from memory above */
  }
}

/** Test-only reset of the in-memory copy. */
export const _resetMemory = () => {
  memory = new Map();
};
