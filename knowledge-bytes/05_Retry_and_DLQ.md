# 05 — Retry and Dead-Letter Routing

## What this covers
Bounded retries and poison handling: `app/retry.py`, `app/worker_common.py`,
topology in `app/rabbitmq.py`.

## Topology
- `quickbite.retry` (fanout, durable) → `orders.retry.queue`
- `orders.retry.queue`: durable, `x-dead-letter-exchange = quickbite.orders`
  (expired messages route back to the main exchange with their original key)
- `dlx.quickbite.orders` (topic, durable) → `orders.dead-letter.queue`
  (bound with `#`)
- Every worker queue declares `x-dead-letter-exchange = dlx.quickbite.orders`

## Retry flow (transient failure)
1. Worker returns `False` → `settle_message` reads `x-retry-count` (default 0).
2. If count < `MAX_RETRIES` (3): republish the message to `quickbite.retry`
   with the count incremented and a per-message TTL of 5s / 10s / 20s
   (`RETRY_DELAYS_SECONDS`), then ack the original.
3. TTL expiry dead-letters the copy back to `quickbite.orders` → redelivered
   to the worker queue with the higher count.
4. If count ≥ 3: mark a non-terminal order `FAILED`, then
   `reject(requeue=False)` → the message lands in `orders.dead-letter.queue`.

## Poison flow
Unparseable bodies or missing `order_id`/`event_id` raise `NonRetryableError`
immediately — no retries, straight to the DLQ via reject.

## No plugin needed
Delayed retries use standard per-message TTL + DLX, so no RabbitMQ
delayed-message plugin is required.
