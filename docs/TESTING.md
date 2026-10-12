# QuickBite — Testing Guide

## Test layers (honest separation)

### 1. Unit tests — mocked broker, in-memory SQLite (default `pytest` run)

- `tests/test_routes.py`, `tests/test_models.py`, `tests/test_schemas.py`
- `tests/test_integration.py` — worker *business logic* via direct
  `process_*_event()` calls against SQLite. Verifies state transitions,
  outbox rows, idempotency, and the atomic API transaction. Does **not**
  touch a broker.
- `tests/test_reliability.py` — reliability *mechanisms* with fake
  AMQP objects: routing-key contract, retry policy math, topology
  declaration arguments (DLX args, retry-queue args, DLQ binding),
  `settle_message` ack/retry/DLQ paths, atomic `claim_event`, and the
  `connect()` returns-manager regression test.

Run: `python -m pytest` (from the repo root, venv active).

### 2. Live integration tests — real PostgreSQL + RabbitMQ (`-m live`)

`tests/test_integration_live.py` is marked `live` and **skipped** unless
`QUICKBITE_RUN_LIVE=1` is set. It requires:

```bash
docker compose up -d postgres rabbitmq
QUICKBITE_RUN_LIVE=1 python -m pytest -m live
```

Connection defaults match `docker-compose.yml` host ports
(`127.0.0.1:5434`, `127.0.0.1:5672`); override with
`QUICKBITE_TEST_DATABASE_URL` / `QUICKBITE_TEST_RABBITMQ_URL`.

Covers: real topology declaration, outbox → broker → payment worker
end-to-end slice, poison message → DLQ (proves DLX wiring), retry
exhaustion → DLQ + order marked `FAILED`. Tables are truncated after
the module run; the broker keeps its (durable) topology.

### 3. Manual demo — `demo.sh`

`demo.sh` drives the running Compose stack through the assignment's
demo scenarios: happy-path status progression, payment failure,
poison → DLQ inspection via the management API, duplicate delivery,
notification-worker downtime, and `--scale worker-payment=3`. See the
script header for prerequisites.

## What was verified where (fix environment, 2026-10-12)

- `64 passed` (full suite with `QUICKBITE_RUN_LIVE=1`): all
  unit/mocked/SQLite/TestClient tests green **and** the 4 live tests green
  against **real RabbitMQ 3.12.1** (installed via apt) and **real
  PostgreSQL 16** (throwaway cluster). Stable across 3 consecutive
  runs.
- 17/17 checks against **real PostgreSQL 16**: schema creation incl.
  the new `FAILED` enum value, `claim_event` atomicity incl. an
  8-thread concurrent-claim race (exactly one winner), the full
  PENDING → PAID → CONFIRMED → DRIVER_ASSIGNED worker chain,
  payment-failure path, duplicate-event idempotency, and poison →
  `NonRetryableError`.
- Genuine end-to-end run (real API + publisher + worker processes,
  real broker + PG): happy path → `DRIVER_ASSIGNED`; payment failure
  → `PAYMENT_FAILED`; duplicate `order.created` → no extra effects;
  poison → DLQ; notification downtime → pipeline completes, backlog
  drains on recovery; two payment-worker instances competing →
  normal completion.
- The migration `docs/migrations/001_add_failed_to_orderstatus.sql`
  was verified against a simulated pre-fix schema (adds the label,
  preserves rows, idempotent).
