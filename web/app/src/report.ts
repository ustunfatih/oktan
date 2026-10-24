/** Sends a browser error to the Worker logs. Best effort: a failed report is dropped, never retried. */
let sent = 0;
const MAX_PER_PAGE = 5;

export function reportClientError(kind: string, error: unknown) {
  if (sent >= MAX_PER_PAGE) return;
  sent++;
  const e = error instanceof Error ? error : new Error(String(error));
  fetch("/api/client-error", {
    method: "POST",
    keepalive: true,
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ kind, message: e.message, stack: e.stack, url: location.pathname }),
  }).catch(() => {});
}
