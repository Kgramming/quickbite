# QuickBite API Reference

Base URL (Docker Compose): `http://127.0.0.1:8002`

## Orders

### `POST /orders`
Create an order. Writes the order row **and** an `order.created` outbox row in a single database transaction.

```json
{
  "customer_name": "Aarav Sharma",
  "customer_email": "aarav@example.com",
  "customer_phone": "9876543210",
  "restaurant_id": "rest-001",
  "items": [{ "name": "Paneer Tikka Pizza", "quantity": 1, "price": "249.99" }],
  "total_amount": "249.99",
  "delivery_address": "42, MG Road, Mumbai"
}
```

- `total_amount` of exactly `"999.99"` triggers the mock payment decline (demo).
- Returns `201` with the created order (`status: PENDING`).

### `GET /orders/{order_id}`
Returns the order including `status` (`PENDING → PAID → CONFIRMED → DRIVER_ASSIGNED`, or `PAYMENT_FAILED` / `FAILED`) and `payment_status`.

### `GET /health`
```json
{ "status": "ok", "database": "healthy", "rabbitmq": "healthy", "version": "0.1.0" }
```
`status` is `ok` only when both dependencies are healthy, otherwise `degraded` (HTTP 200 in both cases).

## Dashboard & Ops (`/api`)

| Method | Path | Description |
|---|---|---|
| `GET` | `/dashboard` | Live operations console (single HTML file, no build step) |
| `GET` | `/api/orders?limit=` | Recent orders, newest first |
| `GET` | `/api/orders/{id}/events` | Event timeline for one order |
| `GET` | `/api/events/recent?limit=` | Recent outbox events across all orders |
| `GET` | `/api/queues` | Live RabbitMQ queue depths + consumer counts (via management API; fails soft to `[]`) |

## Chaos Lab (demo only — no auth, do not expose publicly)

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/chaos/poison` | Publishes an unparseable message → routed straight to the DLQ |
| `POST` | `/api/chaos/duplicate/{order_id}` | Republishes the order's original `order.created` with the same event ID → idempotency absorbs it |
| `GET` | `/api/chaos/payment-fail-hint` | Hint text for the payment-failure demo |

## Events (AMQP routing keys on `quickbite.orders`)

| Routing key | Producer | Consumer |
|---|---|---|
| `order.created` | outbox publisher | payment worker |
| `order.paid` | payment worker | restaurant worker |
| `order.payment.failed` | payment worker | — (terminal) |
| `order.confirmed` | restaurant worker | delivery worker |
| `order.driver.assigned` | delivery worker | — (terminal) |
| `order.#` | — | notification worker (all events) |
