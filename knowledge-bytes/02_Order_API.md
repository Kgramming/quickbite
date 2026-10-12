# 02 — Order API

## What this covers
Order creation and retrieval: `app/routes.py`, `app/schemas.py`, `app/models.py`.

## `POST /orders`
- Validates the payload with Pydantic (`CreateOrderRequest`): customer fields,
  items, `total_amount` as a decimal string, delivery address.
- **Single transaction**: inserts the `Order` row (`status=PENDING`) and an
  `OutboxEvent` row (`event_type="order.created"`, `published="N"`).
- Either both rows commit or neither does — an order can never exist without
  its creation event, and an event can never exist without its order.

## `GET /orders/{order_id}`
Returns the order with `status` and `payment_status`. Terminal states:
`DRIVER_ASSIGNED` (success), `PAYMENT_FAILED` (declined), `FAILED`
(retries exhausted), `CANCELLED`.

## `GET /health`
Returns `ok` only when **both** PostgreSQL (DB ping) and RabbitMQ (AMQP
handshake via `app/routes.py::_check_rabbitmq`) are healthy; otherwise
`degraded`. HTTP 200 in both cases — the `status` field carries the signal.

## OrderStatus (`app/models.py`)
`PENDING → PAID → CONFIRMED → DRIVER_ASSIGNED`, plus `PAYMENT_FAILED`,
`FAILED`, `CANCELLED`. Adding `FAILED` to the Postgres enum is covered by
`docs/migrations/001_add_failed_to_orderstatus.sql` (idempotent).
