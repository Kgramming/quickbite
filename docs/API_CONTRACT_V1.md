# QuickBite API v1 — Contract Handoff for Flutter (Kiro)

**Status:** Implemented and tested. Base for Flutter integration.
**Repo:** `https://github.com/Kgramming/quickbite` (branch `main`)
**Backend code:** `app/v1/` (models, auth, schemas, routes, seed, worker_helpers)

## Base URL / configuration

Configure via build parameter (public config, not a secret):

```
--dart-define=API_BASE_URL=http://localhost:8002        # iOS simulator / desktop web
--dart-define=API_BASE_URL=http://10.0.2.2:8002         # Android emulator
--dart-define=API_BASE_URL=https://<prod-host>          # production (HTTPS)
```

All domain endpoints are under `/api/v1`. CORS allows explicit origins only
(`http://localhost:3000,5173,8080` by default — see `CORS_ORIGINS` env);
`Authorization`, `Content-Type`, `Idempotency-Key` headers permitted;
`Location` exposed.

## Auth flow

Passwords are bcrypt-hashed. JWT (HS256, 24h expiry).

```
POST /api/v1/auth/login
{"email": "customer@example.com", "password": "customer123"}
→ 200 {"access_token": "eyJ...", "token_type": "bearer",
       "expires_in": 86400,
       "user": {"id": "...", "email": "...", "name": "...", "role": "customer"}}
→ 401 {"code": "invalid_credentials", ...} on bad credentials
```

All other endpoints: `Authorization: Bearer <access_token>`.
Missing/invalid/expired token → `401`. Wrong role → `403`.

**Seed accounts** (via `python -m app.v1.seed`, idempotent):
- customer: `customer@example.com` / `customer123`
- admin: `admin@example.com` / `admin123`

**Token storage:** mobile → secure storage; web → in-memory (re-login after reload).

## Endpoints

| Method | Route | Auth | Notes |
|---|---|---|---|
| POST | `/api/v1/auth/login` | public | email+password → token |
| GET | `/api/v1/me` | user | profile + role |
| GET | `/api/v1/restaurants?page=&page_size=` | user | paginated |
| GET | `/api/v1/restaurants/{id}/menu?page=&page_size=` | user | paginated, `price_minor` (int) |
| POST | `/api/v1/orders` | customer | **Idempotency-Key required** → `202` + `Location` |
| GET | `/api/v1/orders?page=&page_size=&status=` | customer | own orders only |
| GET | `/api/v1/orders/{id}` | owner/admin | full detail |
| GET | `/api/v1/orders/{id}/history` | owner/admin | status timeline |
| GET | `/api/v1/orders/{id}/notifications` | owner/admin | paginated |
| GET | `/api/v1/admin/orders?page=&page_size=&status=` | admin | all orders |
| GET | `/api/v1/admin/summary` | admin | counts by status + backlogs |
| GET | `/health/live` | public | `{"status":"ok"}` |
| GET | `/health/ready` | public | `200` ok / `503` degraded + dependency detail |

## Checkout (idempotent)

```
POST /api/v1/orders
Authorization: Bearer <token>
Idempotency-Key: <client-generated UUID>     ← REQUIRED, persist until outcome known

{
  "restaurant_id": "rest_biryani",
  "delivery_address": "12 Lake Road, Bengaluru",
  "items": [
    {"menu_item_id": "item_chicken_biryani", "quantity": 2},
    {"menu_item_id": "item_raita", "quantity": 1}
  ]
}
```

Rules: max 20 distinct items, quantity 1–20, single restaurant, items must
exist + be available. **Totals computed server-side from menu prices.**
Client never sends prices.

```
→ 202 Accepted
Location: /api/v1/orders/<order_id>
{"order_id": "...", "status": "PENDING", "currency": "INR",
 "total_amount_minor": 54997, "version": 1,
 "message": "Order accepted for asynchronous processing."}
```

Idempotency: same key + same payload → same `202` + same `order_id`
(no new order). Same key + different payload → `409`. Missing key → `422`.

**Client guidance:** disable the pay button while the request is in flight.
On timeout, retry with the **same** key (never generate a new one).
Poll `GET /api/v1/orders/{id}` ~every 2s while the detail screen is visible;
stop when status is terminal.

## Order detail

```
GET /api/v1/orders/<id>
→ 200 {
  "id": "...", "restaurant_id": "rest_biryani", "status": "DRIVER_ASSIGNED",
  "currency": "INR", "total_amount_minor": 54997, "version": 4,
  "failure_code": null,                       ← set on PAYMENT_FAILED/FAILED
  "driver": {"name": "Driver a1b2c3d4"},      ← when assigned
  "items": [{"menu_item_id": "...", "name": "Chicken Dum Biryani",
             "quantity": 2, "price_minor": 24999}],
  "delivery_address": "...",
  "created_at": "2026-10-13T...", "updated_at": "2026-10-13T..."
}
```

Status machine: `PENDING → PAID → CONFIRMED → DRIVER_ASSIGNED`
(terminals: `PAYMENT_FAILED`, `FAILED`, `CANCELLED`).

## Pagination

`?page=1&page_size=20` (max 100). Response:
`{"items": [...], "page": 1, "page_size": 20, "total": 42}`.

## Error envelope

All errors: `{"code": "...", "message": "...", "details": {...}, "request_id": "..."}`

| HTTP | Meaning |
|---|---|
| 401 | missing/invalid/expired token (`invalid_credentials`, `Token expired`) |
| 403 | authenticated but wrong role (`Admin access required`) |
| 404 | unknown id **or another customer's order** (indistinguishable by design) |
| 409 | idempotency key reused with different payload |
| 422 | validation (`missing_idempotency_key`, `invalid_item`, `mixed_restaurants`, `item_unavailable`) |

## Money

Integer minor units: `24999` = INR 24
...[truncated 1416 chars]