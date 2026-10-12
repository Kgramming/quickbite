# 07 — Dashboard

## What this covers
The live operations console: `app/static/dashboard.html` (single file, no
build step) served at `GET /dashboard`, backed by `app/ops.py`.

## Backend (`app/ops.py`)
Read-only endpoints over the same database the workers use — everything shown
is live, nothing is mocked or animated:

| Endpoint | Shows |
|---|---|
| `GET /api/orders` | Order list with statuses |
| `GET /api/orders/{id}/events` | Per-order event timeline |
| `GET /api/events/recent` | Outbox event stream |
| `GET /api/queues` | Queue depths + consumer counts via the RabbitMQ management API (fails soft to `[]`) |

Plus the Chaos Lab (demo-only, unauthenticated — do not expose publicly):
`POST /api/chaos/poison`, `POST /api/chaos/duplicate/{order_id}`.

## Frontend
Vanilla HTML/CSS/JS. Polls `/health` (3s), orders (1.5s), queues (2s), events
(2s). Features:

- **Order form** → `POST /orders`; `999.99` triggers the mock decline.
- **Order cards** → click opens the event-timeline modal. Closing the modal
  intentionally **preserves the selection** so Chaos Lab → DUP keeps its target.
- **Chaos Lab** → FAIL / POISON / DUP buttons described above.
- **Pipeline panel** → live queue depths, consumer counts, DLQ counter.
- **Theme switcher** → light/dark toggle in the header, persisted in
  `localStorage`; all colors are CSS variables under `:root` /
  `[data-theme="dark"]`.
