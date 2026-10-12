# QuickBite Milestone 2 — Backend Reliability Improvements

**Commit:** (pending) | **Branch:** `main` | **Date:** 2026-10-13
**Owner:** Muse (backend) | **Coordinator:** ChatGPT

This document updates the Milestone 1 handoff (`docs/API_CONTRACT_V1.md`) with
the reliability changes. The API contract itself is unchanged; all changes are
in the messaging/reliability layer.

---

## 1. Retry policy — now spec-compliant (2s / 10s / 30s)

- `app/retry.py`: `RETRY_DELAYS_SECONDS = [2.0, 10.0, 30.0]` (was 5/10/20).
- `MAX_RETRIES = 3` unchanged: 1 initial attempt + 3 delayed retries.
- Per-message TTL on the retry copy; no broker plugins required.

## 2. Targeted retry routing

**Problem fixed:** retries used to republish through the `quickbite.orders`
topic exchange, re-fanning-out to unrelated subscribers (e.g. a failed
`order.paid` retry would also hit `notification.queue` via `order.#`).

**Now:** the retry copy is published with the **originating queue name** as the
routing key. `orders.retry.queue` dead-letters expired messages to the
**default exchange** (`""`), so each retry lands **only** in the failing
consumer's queue.

- `app/rabbitmq.py`: retry queue `x-dead-letter-exchange` changed from
  `quickbite.orders` to `""`.
- `app/retry.py`: `republish_for_retry(..., target_queue)` — routing key is
  now the queue name.
- `app/worker_common.py`: `settle_message(..., queue_name)` threads the queue
  name through from `run_worker`.

## 3. Dead-letter exchange — `quickbite.dead`

- `app/rabbitmq.py`: `DLX_EXCHANGE = "quickbite.dead"` (was
  `dlx.quickbite.orders`), now a **durable direct** exchange (was topic).
- Worker queues declare `x-dead-letter-exchange=quickbite.dead` with
  `x-dead-letter-routing-key=failed`.
- `orders.dead-letter.queue` bound to `quickbite.dead` with routing key
  `failed`. Quarantined envelopes are inspectable via the management UI.

## 4. Event envelope v2

All producers now emit via `app.events.build_envelope()`:

| Field | Notes |
|---|---|
| `event_id` | immutable UUID; doubles as outbox row id and AMQP `message_id` |
| `schema_version` | `1` |
| `event_type` | e.g. `order.paid` |
| `order_id` | order UUID |
| `order_version` | optimistic-concurrency version at emit time |
| `occurred_at` | ISO-8601 UTC |
| `correlation_id` | checkout `Idempotency-Key` for `order.created`; propagated downstream |
| `causation_id` | the incoming event's `event_id` (the direct cause) |
| `data` | event-specific payload |

Producers updated: legacy `POST /orders`, v1 `POST /api/v1/orders`,
payment/restaurant/delivery workers. Consumers still read top-level
`event_id` / `event_type` / `order_id`, so the envelope is backward compatible.
`order.failed` added to `OUTBOX_ROUTING_KEYS`.

## 5. Deterministic failure injection

New module `app/v1/failure_config.py` — env-driven, dev/test only:

| Variable | Modes |
|---|---|
| `QB_PAYMENT_FAILURE_MODE` | `success` (default), `fail_twice_then_succeed`, `always_fail`, `crash_after_charge` |
| `QB_RESTAURANT_FAILURE_MODE` | `success`, `always_fail` → terminal `FAILED` + `order.failed` |
| `QB_DELIVERY_FAILURE_MODE` | `success`, `always_fail` → terminal `FAILED` + `order.failed` |
| `QB_NOTIFICATION_FAILURE_MODE` | `success`, `always_fail` → retries then quarantine, **status untouched** |

- Injection is evaluated **before** the idempotency claim so injected
  transient failures actually exercise the retry loop.
- `fail_twice_then_succeed` uses an in-memory per-order counter (attempts 1–2
  return transient failure, attempt 3 runs the real logic exactly once).
- `crash_after_charge` calls `os._exit(1)` — hard crash; redelivery must be
  idempotent. Test-only; never enable in production.
- The legacy `999.99` amount-based decline is kept for dashboard demo
  compatibility; env injection is the primary deterministic mechanism.

## 6. Quarantine records + worker-aware exhaustion

`app/worker_common.py` now writes a `QuarantineRecord` (PostgreSQL) on every
dead-letter, in the same transaction as the terminal transition:

| Worker | On retry exhaustion |
|---|---|
| payment | `PENDING` → `PAYMENT_FAILED` + `order.payment.failed` outbox event |
| restaurant / delivery | `PAID`/`CONFIRMED` → `FAILED` + `order.failed` outbox event |
| notification | **no status change**; quarantine record only |

Poison messages (`NonRetryableError`) are quarantined immediately with
`failure_code="POISON_MESSAGE"` and no retry burned. Exhaustion uses
`failure_code="RETRY_EXHAUSTED"`. Terminal states are never overwritten.

## 7. Rubric gap review

| Requirement | Status |
|---|---|
| Bounded retries 1+3 @ 2/10/30s | ✅ implemented + tested |
| Targeted retry routing | ✅ implemented + tested |
| `quickbite.dead` direct exchange | ✅ implemented + tested |
| Quarantine with full envelope | ✅ implemented + tested |
| Manual acks / publisher confirms / prefetch=1 | ✅ (unchanged) |
| Atomic idempotency claims | ✅ (unchanged) |
| Outbox pattern | ✅ (unchanged) |
| `retry_jobs` table persistence | ➖ not populated — TTL retry queue is the spec's accepted alternative; retry state lives in `x-retry-count` headers + broker-held delayed messages |
| Crash recovery / broker outage live evidence | ➖ **not run** — needs live RabbitMQ; Mac-side validation pending |

## 8. Tests

```bash
python -m pytest -p no:warnings -p no:cacheprovider -q
# 87 passed, 4 skipped (live RabbitMQ/PostgreSQL; QUICKBITE_RUN_LIVE=1 not set)
```

New in this milestone (11 tests): spec delay values, targeted routing,
topology (DLX args, retry→default exchange, DLQ binding), quarantine writes,
worker-aware exhaustion (payment/notification/poison), envelope v2 fields,
injection config, `fail_twice_then_succeed` end-to-end at worker level.

## 9. Recommended next step

**ChatGPT:** review this milestone against rubric §7–8. If approved, authorize
**Kiro** to begin Flutter integration (API contract unchanged from M1), and
queue **Mac-side live validation**: broker running, `fail_twice_then_succeed`
demo, worker-kill recovery, and broker-outage evidence.
