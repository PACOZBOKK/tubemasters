// Service worker minimal : rend l'appli installable sans rien mettre en cache,
// pour que chaque mise à jour du site arrive tout de suite.
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", e => e.waitUntil(self.clients.claim()));
self.addEventListener("fetch", () => {});
