# 10 — Phone Demo (ngrok)

## What this covers
How the Flutter web build + FastAPI backend are served on one public URL so
the demo works on a phone.

## Architecture
One ngrok tunnel on the account's static domain → `localhost:8080`, where a
tiny Python reverse proxy (`proxy.py`, repo root) routes:
- `/api/*` → `localhost:8002` (FastAPI backend)
- everything else → `localhost:8091` (threaded static server `serve.py`
  serving `flutter_app/build/web`)

Single origin ⇒ **no CORS changes needed**. The Flutter app is built with the
public backend URL baked in:
`flutter build web --release --dart-define=API_BASE_URL=https://<domain>`.

## The ngrok quirk this works around
On this ngrok account (free plan), every new tunnel is assigned the
account's reserved static domain — two tunnels cannot hold two different
public URLs (the second tunnel steals the domain, or the agent refuses with
`ERR_NGROK_334`). The single-tunnel + proxy design sidesteps this entirely,
and the static domain keeps the demo link stable across restarts.

## Performance notes
- Both Python servers use `ThreadingHTTPServer` — the stdlib
  `python3 -m http.server` is single-threaded and makes Flutter's parallel
  asset loading crawl.
- First load is ~5–10s (multi-MB `main.dart.js` over ngrok free); navigation
  after that is smooth.

## Restart recipe (Mac)
1. `ngrok start quickbite-demo` (tunnel `quickbite-demo` → `:8080`)
2. `python3 ~/Documents/quickbite/serve.py` (Flutter build on `:8091`)
3. `python3 ~/Documents/quickbite/proxy.py` (proxy on `:8080`)
4. Open `https://<static-domain>` → "Visit Site" on the ngrok warning page.

Rebuild Flutter only if the backend's public URL changes (static, so rarely).
