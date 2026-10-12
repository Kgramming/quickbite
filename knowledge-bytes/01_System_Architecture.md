# 01 — System Architecture

## What this covers
How QuickBite's services fit together: FastAPI, PostgreSQL, the outbox publisher,
RabbitMQ, and four independent workers.

## Components (`docker-compose.yml`)

| Service | Command | Role |
|---|---|---|
| `api` | `uvicorn app.main:app --port 8002` | REST API + dashboard |
| `publisher` | `python -m app.outbox_publisher` | Relays outbox rows → RabbitMQ |
| `worker-payment` / `worker-restaurant` / `worker-delivery` / `worker-notification` | `python -m app.worker_service --workers <name>` | One consumer per queue; independently scalable |
| `postgres` / `rabbitmq` | — | State and transport |

## Data flow
1. `POST /orders` (`app/routes.py`) writes the `orders` row **and** an
   `order.created` outbox row in one transaction.
2. The publisher (`app/outbox_publisher.py`) polls unpublished rows and publishes
   each to the `quickbite.orders` topic exchange **with publisher confirms** —
   the row is marked `published='Y'` only after the broker acks.
3. Workers (`app/workers/*.py`) consume from their queues, claim the event
   atomically (`app/idempotency.py::claim_event`), apply the state transition,
   write the next outbox row, commit, then ack.

## Key files
- `app/main.py` — app wiring, `/dashboard` + `/static` mounts
- `app/rabbitmq.py` — topology: 3 exchanges, 6 queues, all durable
- `app/worker_service.py` — `--workers` selector, runs any subset
- `docker-compose.yml` — 8 services, `restart: unless-stopped`
