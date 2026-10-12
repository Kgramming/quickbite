# Screenshots

Drop real dashboard screenshots here from a live run (`docker compose up -d`,
then `http://127.0.0.1:8002/dashboard`). The README references these files:

| File | What to capture |
|---|---|
| `01-dashboard.png` | Full dashboard: health pills, order form, live orders, pipeline, event stream |
| `02-order-timeline.png` | Order timeline modal open on a `DRIVER_ASSIGNED` order |
| `03-chaos-lab.png` | Chaos Lab section after a poison + duplicate demo (DLQ counter visible) |
| `04-dark-mode.png` | Dashboard with the dark theme toggled on |

Tips:
- Use a real order flow (place an order, let it reach `DRIVER_ASSIGNED`) so the
  screenshots show live data, not empty states.
- 1440px-wide browser window works well.
- PNG format, keep each file under ~500 KB.
