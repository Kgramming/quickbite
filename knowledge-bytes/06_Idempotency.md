# 06 — Idempotency

## What this covers
Exactly-once effect under at-least-once delivery: `app/idempotency.py`.

## Mechanism
`claim_event(session, event_id, worker_type) -> bool` executes a single
`INSERT INTO processed_events … ON CONFLICT DO NOTHING` (Postgres and SQLite
dialects) and returns whether the row was inserted.

- `True` → this worker instance claimed the event; proceed.
- `False` → another instance (or a redelivery) already claimed it; ack as a
  duplicate without touching business state.

The check-and-record is one atomic statement, so two racing consumers cannot
both win — verified with an 8-thread concurrent-claim race in
`tests/test_integration_live.py`.

## Where duplicates come from
- **Redelivery**: a worker crashes after committing but before acking.
- **Retry copies**: the original is acked only after the retry copy is
  confirmed published; a crash in between yields both.
- **Publisher crash**: an outbox row marked unpublished is republished.
- **Chaos Lab**: `/api/chaos/duplicate/{order_id}` republishes the original
  `order.created` with the same event ID on purpose.

All four are absorbed: the second claim returns `False` and the message is
acked with no state change.

## Table
`processed_events(event_id, worker_type, status, …)` with a unique constraint
on `(event_id, worker_type)` — the constraint *is* the correctness mechanism.
