# 08 — End to End

## What this covers
One order's full journey through every component, with the code path for each hop.

## Happy path
1. `POST /orders` → `app/routes.py::create_order` inserts `orders(PENDING)` +
   `outbox_events(order.created, published='N')` in one transaction.
2. `app/outbox_publisher.py` picks up the row, publishes to `quickbite.orders`
   with key `order.created` (publisher confirm), marks `published='Y'`.
3. `app/workers/payment.py` consumes from `payment.queue`, claims the event,
   mock-approves, sets `PAID`, writes `order.paid` to the outbox, commits, acks.
4. Publisher relays `order.paid` → `restaurant.queue` →
   `app/workers/restaurant.py` sets `CONFIRMED`, writes `order.confirmed`.
5. Publisher relays `order.confirmed` → `delivery.queue` →
   `app/workers/delivery.py` sets `DRIVER_ASSIGNED`, writes
   `order.driver.assigned`.
6. `app/workers/notification.py` (bound to `order.#`) observes every event.

## Failure paths
- **Declined payment** (`total_amount = 999.99`): payment worker sets
  `PAYMENT_FAILED`, writes `order.payment.failed`, commits, acks. Terminal —
  no retries, no downstream events.
- **Transient failure** (e.g. DB error mid-transaction): worker returns
  `False` → retry loop (05) → after 3 attempts the order is marked `FAILED`
  and the message is dead-lettered.
- **Poison** (unparseable body): `NonRetryableError` → reject → DLQ, no retries.

## Verification
- `tests/test_reliability.py` — 24 mocked unit tests over the real settlement,
  retry, and idempotency code.
- `tests/test_integration_live.py` — 4 tests against real RabbitMQ 3.12 +
  PostgreSQL 16 (topology, outbox→broker→worker, poison→DLQ, exhaustion→FAILED).
- `docs/DEMO.md` — the 5-minute live demonstration script.
