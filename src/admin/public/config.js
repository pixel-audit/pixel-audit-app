// Runtime configuration of the admin panel.
//
// Loaded by index.html before the app bundle, so these values are read at
// page load rather than baked in at build time — one build of the panel can
// point at any API. The values below are the development defaults (the
// local stack from docker-compose.yml); the Docker image's entrypoint
// (docker/40-runtime-config.sh) overrides them from environment variables on
// every container start. src/lib/config.ts is the typed reader, and falls
// back to the same development defaults for anything missing here.
window.PIXELAUDIT_CONFIG = {
  // Base URL of the PixelAudit API.
  apiUrl: "http://localhost:16000",
  // Where this program's source is offered (AGPL §13): the footer links there.
  sourceUrl: "https://github.com/pixel-audit/pixel-audit-app",
};
