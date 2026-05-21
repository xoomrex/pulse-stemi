// Pulse — STEMI Coordination service worker.
// Strategy: network-first for everything, but cache the app shell so the
// app still opens (and shows a friendly offline screen) when there's no signal.

const VERSION = "pulse-v1";
const APP_SHELL = [
  "/",
  "/manifest.webmanifest",
  "/icon-192.png",
  "/icon-512.png"
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(VERSION).then((cache) => cache.addAll(APP_SHELL).catch(() => {}))
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  const req = event.request;

  // Never intercept LiveView websocket / longpoll / live_reload / non-GET.
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.pathname.startsWith("/live") || url.pathname.startsWith("/phoenix")) return;

  // Network-first; fall back to cache; finally, the cached root for navigations.
  event.respondWith(
    fetch(req)
      .then((res) => {
        // Only cache successful, same-origin, basic responses.
        if (res && res.status === 200 && res.type === "basic" && url.origin === self.location.origin) {
          const copy = res.clone();
          caches.open(VERSION).then((cache) => cache.put(req, copy)).catch(() => {});
        }
        return res;
      })
      .catch(() =>
        caches.match(req).then((cached) => {
          if (cached) return cached;
          if (req.mode === "navigate") return caches.match("/");
          return new Response("Offline", { status: 503, statusText: "Offline" });
        })
      )
  );
});
