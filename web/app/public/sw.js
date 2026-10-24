// Oktan service worker: lets the home-screen app open (with the last numbers) when offline.
// Data requests (/api) and Cloudflare Access (/cdn-cgi) always go to the network and are never cached.
const CACHE = "oktan-shell-v1";

self.addEventListener("install", () => self.skipWaiting());

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      for (const key of await caches.keys()) if (key !== CACHE) await caches.delete(key);
      await self.clients.claim();
    })(),
  );
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  const url = new URL(req.url);
  if (req.method !== "GET" || url.origin !== location.origin) return;
  if (url.pathname.startsWith("/api/") || url.pathname.startsWith("/cdn-cgi/")) return;

  // Pages: network first so updates and the Access sign-in redirect work; the cached shell is the offline fallback.
  if (req.mode === "navigate") {
    event.respondWith(
      (async () => {
        try {
          const res = await fetch(req);
          if (res.ok && res.type === "basic") (await caches.open(CACHE)).put("/", res.clone());
          return res;
        } catch {
          return (await caches.match("/")) || Response.error();
        }
      })(),
    );
    return;
  }

  // Built files have content hashes in their names, so a cached copy never goes stale.
  if (url.pathname.startsWith("/assets/") || url.pathname.startsWith("/icons/") || url.pathname === "/favicon.svg") {
    event.respondWith(
      (async () => {
        const hit = await caches.match(req);
        if (hit) return hit;
        const res = await fetch(req);
        if (res.ok && res.type === "basic") (await caches.open(CACHE)).put(req, res.clone());
        return res;
      })(),
    );
  }
});
