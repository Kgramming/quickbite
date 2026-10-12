# 03 — Outbox Publisher

## What this covers
The relay that moves events from PostgreSQL to RabbitMQ: `app/outbox_publisher.py`.

## Why it exists
The API never publishes to RabbitMQ directly. Publishing inside the request
transaction would couple HTTP latency to the broker and risk losing events on
crash. Instead the API writes an outbox row, and this separate process relays it.

## How it works
1. Polls `outbox_events` for rows with `published='N'`, oldest first
   (`OutboxPublisher.publish_events`, default 2s interval).
2. Resolves the routing key from the explicit allow-list
   (`app/events.py::OUTBOX_ROUTING_KEYS`) — unknown event types are **never**
   published silently; the row stays unpublished and gets logged.
3. Publishes with **publisher confirms** enabled on the channel. The row is
   marked `published='Y'` only after the broker confirms receipt.
4. Crash between publish and mark → the row stays `'N'` → republished on the
   next poll → the duplicate is absorbed by the workers' idempotency claim.

## Guarantees
- At-least-once delivery, never silent loss.
- Ordering per worker queue is oldest-first (single publisher process).
