# 09 — Flutter App

## What this covers
The customer + admin Flutter app: structure, state, API integration, and the UX decisions that make it feel like a real product.

## Structure
- `flutter_app/lib/screens/` — home, restaurant menu, cart, checkout, order
  tracking, order history, admin dashboard, auth.
- `flutter_app/lib/widgets/` — shared components (`qb_widgets.dart`).
- `flutter_app/lib/providers/` — state: cart, auth, orders, theme.
- `flutter_app/lib/services/` — typed API client (`api_client.dart`) against
  `GET/POST /api/v1/...`; base URL from `--dart-define=API_BASE_URL`.

## Features (all backed by real backend data)
- **8 restaurants × 10 dishes** from the seed (`app/v1/seed.py`); restaurant
  images keyed by stable restaurant ID, not name matching.
- **Smart cart** — quantity steppers; adding from a second restaurant shows a
  "Start a new order?" dialog (`CartState.restaurantName`); "Continue
  shopping at \<name\>" deep-links back to the same menu.
- **Idempotent checkout** — safe retries; confetti on confirmation.
- **Tracking v2** — honest 3-stage journey (Placed → Preparing → On the way;
  no fake "Delivered" since the backend has no delivered status);
  `driverAssigned` maps to 100%; real timeline, driver card, notifications
  feed with event icons + relative timestamps.
- **Order history + "Order again"** — rebuilds the cart from recorded items.
- **🎰 Surprise Me** — slot-machine random-dish picker over real menus;
  respects the single-restaurant cart rule via shared helper logic.
- **Admin** — live order-distribution stacked bar from backend `byStatus`;
  tappable status cards filter the order list.
- **Login quick-fill chips** — Customer/Admin chips fill seeded credentials
  (`customer@example.com`/`customer123`, `admin@example.com`/`admin123`);
  chips fill only, they never bypass auth.

## Performance
- Shared `ResizeImage`-backed image provider (`cacheWidth` 600/200/800),
  first-6 card images precached, lighter shadows, pull-to-refresh on home.
- `flutter analyze`: 0 errors. `flutter test`: 7/7. Release web build passes.

## Verification
- Widget QA: 18/18 zero layout overflows (1440×900 + 390×844).
- Live phone demo via ngrok — see `10_Phone_Demo.md`.
