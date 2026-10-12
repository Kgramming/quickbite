# QuickBite Demo Guide

A 5-minute live demonstration of the reliable order pipeline. All steps use the
dashboard at `http://127.0.0.1:8002/dashboard` (or your mapped port).

## Prerequisites

```bash
docker compose up -d
# wait ~20s for postgres + rabbitmq health checks
curl http://127.0.0.1:8002/health   # {"status":"ok",...}
```

## Act 1 — Happy path (90 seconds)

1. Open the dashboard. Health pills (API / Database / RabbitMQ) should be green.
2. Fill the order form and submit.
3. Watch the order card progress: `PENDING → PAID → CONFIRMED → DRIVER_ASSIGNED`.
4. Click the card → the event timeline shows all four events with timestamps.

**Say:** *"One database transaction writes the order and the outbox event; the
publisher relays it to RabbitMQ; four independent workers advance the order."*

## Act 2 — Payment failure (30 seconds)

1. Chaos Lab → **FAIL** (places a ₹999.99 order).
2. The order lands on `PAYMENT_FAILED` and never advances.

**Say:** *"A business failure is terminal — no retries, no downstream events."*

## Act 3 — Poison → DLQ (30 seconds)

1. Chaos Lab → **POISON**.
2. Watch the dead-letter counter jump by 2 (payment + notification consumers each
   reject the unparseable message with no retries).

**Say:** *"Poison messages can never wedge the pipeline — they go straight to
the dead-letter queue."*

Optionally open the RabbitMQ management UI (`http://127.0.0.1:15672`,
`quickbite` / `quickbite_password`) → Queues → `orders.dead-letter.queue`.

## Act 4 — Duplicate delivery (30 seconds)

1. Click any `DRIVER_ASSIGNED` order card to select it.
2. Chaos Lab → **DUP**.
3. Nothing changes: same status, same timeline, no new outbox rows.

**Say:** *"The same event delivered twice is absorbed by the atomic idempotency
claim — exactly-once effect."*

## Act 5 — Scale (optional, 60 seconds)

```bash
docker compose up -d --scale worker-payment=2
```

The pipeline panel shows 2 consumers on `payment.queue`. Place another order —
it still processes exactly once (one `processed_events` claim).

## Cleanup

Chaos actions only create demo orders and one poison message per click. To reset:

```bash
docker compose down -v   # ⚠️ deletes the demo database and all messages
docker compose up -d
```
