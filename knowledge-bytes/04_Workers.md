# 04 — Workers

## What this covers
The four consumers in `app/workers/`: payment, restaurant, delivery, notification.

## Shared settlement protocol (`app/worker_common.py::run_worker` / `settle_message`)
Every worker follows the same steps per message:
1. Parse the body → unparseable raises `NonRetryableError` (poison).
2. `claim_event(event_id, worker_type)` inside the DB transaction — atomic
   `INSERT … ON CONFLICT DO NOTHING`. `False` means duplicate → ack, no work.
3. Business logic + state transition + next outbox row, one commit.
4. `settle_message`:
   - success → commit, then `message.ack()`
   - transient failure → republish to the retry exchange, then ack the original
   - poison / retries exhausted → `message.reject(requeue=False)` → DLQ

The consumer stays alive after `queue.consume()` via `await asyncio.Future()`
(a previous bug let it exit immediately).

## Worker responsibilities

| Worker | Consumes | On success | Emits |
|---|---|---|---|
| payment | `order.created` | `PENDING → PAID` (mock approves unless total is `999.99`) | `order.paid` / `order.payment.failed` |
| restaurant | `order.paid` | `PAID → CONFIRMED` | `order.confirmed` |
| delivery | `order.confirmed` | `CONFIRMED → DRIVER_ASSIGNED` | `order.driver.assigned` |
| notification | `order.#` | logs / terminal side effects only | — |

State guards: a worker only transitions an order out of its expected state
(e.g. payment requires `PENDING`); anything else is claimed and acked as a no-op.

## Scaling
`python -m app.worker_service --workers payment` runs one type;
`docker compose up -d --scale worker-payment=3` runs three. Competing
consumers are safe: the atomic claim guarantees exactly-once effect.
