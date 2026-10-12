# Screenshots

Live captures from the QuickBite operations console
(`http://127.0.0.1:8002/dashboard`).

| File | Shows |
|---|---|
| `01-dashboard.png` | Full console: health pills, order form, live orders, pipeline, event stream |
| `02-order-timeline.png` | Order timeline modal on a `DRIVER_ASSIGNED` order |
| `03-chaos-lab.png` | Dead-letter queue counter after poison-message demos |
| `04-dark-mode.png` | Full console with the dark theme toggled on |

To refresh them: run `docker compose up -d`, place a few orders, trigger the
Chaos Lab actions, and capture at 1440px width.
