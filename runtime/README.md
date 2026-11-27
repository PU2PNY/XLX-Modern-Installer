# Live runtime recovery sources

The generic installer runs the bundled dashboard with PHP/Nginx. Live Core V2
(Rust/WebSocket) and Live Hub (Node.js/SSE) are optional recovery components for
installations with the corresponding web endpoints and runtime dependencies.

- `live-core-v2/` has the Cargo lockfile and source corresponding to XLX026 on 2026-11-27,
  with self-contained synthetic RadioID test data. Build with `cargo build --locked --release` from that
  directory. The `XLX026_BIND` default is `127.0.0.1:8092`.
- `live-hub/` uses only Node.js modules. Run `node server.js` with the upstream
  scheme, host, port, path and TLS name configured through `XLX_LIVE_SOURCE_*`.
  Keep the bind on loopback. Same-origin Nginx proxying is supported. For HTTPS,
  configure the hostname on the certificate via `XLX_LIVE_SOURCE_SERVERNAME`.
- For a full recovery, restore the private Nginx site, systemd service overrides,
  log and cache permissions, RadioID alias mapping and compatible dashboard
  integration. The Rust source consumes the site-specific runtime paths
  documented in its top-level constants. Configure the matching producers and
  file access before exposing the WebSocket or SSE proxy.
- Verify health and snapshot in isolation, then check connect, transmit, receive,
  multiple simultaneous transmissions, reconnect and PHP fallback through the
  site. See [the rollback procedure](../docs/RECOVERY.md).

Production source provenance before the Live Hub hostname, CORS and upstream TLS
adjustments is the recovery branch
`recovery/xlx026-prod-parity-20261017`, revision `69ea82b`.
