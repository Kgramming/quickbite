"""Shared reliable-consumer helpers for all workers.

Settlement contract (explicit manual acks, no ``message.process()``):

  - ``process_fn`` returns True   -> all DB work committed -> ``ack()``
  - ``process_fn`` returns False  -> transient failure -> bounded retry
    (targeted at this queue only), or quarantine when retries are exhausted
  - ``process_fn`` raises NonRetryableError -> poison -> quarantine, no retry
  - any other exception           -> treated as transient failure

The ack is always the last step and is only issued after the worker's
database transaction has committed (and, on the retry path, after the
broker confirms the retry copy). A crash before ack therefore causes a
redelivery that the idempotent ``process_fn`` handles safely.

Terminal handling on exhaustion/quarantine is worker-aware:
  - payment      -> PENDING becomes PAYMENT_FAILED (+ order.payment.failed)
  - restaurant/delivery -> PAID/CONFIRMED becomes FAILED (+ order.failed)
  - notification -> business status untouched; quarantine record only
"""

import asyncio
import json
import logging
import uuid
from datetime import datetime
from typing import Awaitable, Callable

import aio_pika

from app.database import SessionLocal
from app.models import Order, OrderStatus, OutboxEvent
from app.rabbitmq import RETRY_EXCHANGE
from app.retry import (
    MAX_RETRIES,
    NonRetryableError,
    get_retry_count,
    republish_for_retry,
)
from app.v1.models import QuarantineRecord
from app.v1.worker_helpers import record_transition

logger = logging.getLogger(__name__)

# Order statuses after which no further automatic transition is attempted.
TERMINAL_STATUSES = {
    OrderStatus.PAYMENT_FAILED,
    OrderStatus.DRIVER_ASSIGNED,
    OrderStatus.CANCELLED,
    OrderStatus.FAILED,
}


def _extract_order_id(body: bytes) -> str | None:
    """Best-effort order_id extraction for failure bookkeeping."""
    try:
        data = json.loads(body.decode("utf-8"))
        return data.get("order_id")
    except Exception:
        return None


def write_quarantine_record(
    session,
    event_id: str,
    event_type: str,
    order_id: str | None,
    source: str,
    attempts: int,
    failure_code: str,
    payload: str,
) -> None:
    """Persist a quarantine record for a dead-lettered message.

    Called inside the caller's transaction; the record commits atomically
    with the terminal state transition (if any).
    """
    session.add(QuarantineRecord(
        event_id=event_id or f"unknown-{uuid.uuid4().hex[:8]}",
        event_type=event_type or "unknown",
        order_id=order_id,
        source=source,
        attempts=attempts,
        failure_code=failure_code,
        payload=payload,
    ))


def handle_terminal_failure(
    session,
    worker_name: str,
    order_id: str | None,
    event_id: str,
) -> None:
    """Apply the worker-aware terminal transition on retry exhaustion.

    Must be called inside an open transaction; caller commits.
    """
    if not order_id:
        return
    order = session.query(Order).filter(Order.id == order_id).first()
    if order is None or order.status in TERMINAL_STATUSES:
        return

    if worker_name == "payment":
        record_transition(session, order, OrderStatus.PAYMENT_FAILED)
        order.payment_status = "failed"
        order.failure_code = "PAYMENT_RETRY_EXHAUSTED"
        _emit_outbox(session, order_id, "order.payment.failed",
                      {"reason": "payment retries exhausted"})
    elif worker_name in ("restaurant", "delivery"):
        record_transition(session, order, OrderStatus.FAILED)
        order.failure_code = f"{worker_name.upper()}_RETRY_EXHAUSTED"
        _emit_outbox(session, order_id, "order.failed",
                      {"reason": f"{worker_name} retries exhausted"})
    # notification: business status untouched by design


def _emit_outbox(session, order_id: str, event_type: str, data: dict) -> None:
    event_id = str(uuid.uuid4())
    session.add(OutboxEvent(
        id=event_id,
        event_type=event_type,
        order_id=order_id,
        payload=json.dumps({
            "event_id": event_id,
            "schema_version": 1,
            "event_type": event_type,
            "order_id": order_id,
            "occurred_at": datetime.utcnow().isoformat() + "Z",
            "data": data,
        }),
    ))


async def settle_message(
    message: aio_pika.IncomingMessage,
    retry_exchange: aio_pika.Exchange,
    process_fn: Callable[[bytes], Awaitable[bool]],
    worker_name: str,
    queue_name: str,
) -> str:
    """Process one message and settle it according to the contract above.

    Returns one of: "acked", "retried", "dlq".
    """
    headers = message.headers or {}
    order_id = headers.get("order_id", "unknown")
    logger.info(f"{worker_name} worker received message for order {order_id}")

    try:
        outcome = await process_fn(message.body)
    except NonRetryableError as e:
        logger.warning(f"{worker_name}: non-retryable message: {e} -> quarantine")
        _quarantine_and_reject(message, worker_name, queue_name,
                               failure_code="POISON_MESSAGE")
        await message.reject(requeue=False)
        return "dlq"
    except Exception:
        logger.exception(f"{worker_name}: transient error processing message")
        outcome = False

    if outcome is True:
        # DB transaction committed inside process_fn; safe to ack.
        await message.ack()
        logger.info(f"{worker_name} worker acknowledged message for order {order_id}")
        return "acked"

    # Transient failure -> bounded targeted retry, else quarantine.
    count = get_retry_count(message)
    if count < MAX_RETRIES:
        # Publish retry copy targeted at this queue only; ack original after.
        await republish_for_retry(retry_exchange, message, queue_name)
        await message.ack()
        logger.warning(
            f"{worker_name} worker scheduled retry for order {order_id} "
            f"(attempt {count + 1}/{MAX_RETRIES})"
        )
        return "retried"

    real_order_id = _extract_order_id(message.body)
    _quarantine_and_reject(message, worker_name, queue_name,
                           failure_code="RETRY_EXHAUSTED",
                           order_id=real_order_id)
    await message.reject(requeue=False)  # DLX -> orders.dead-letter.queue
    logger.warning(
        f"{worker_name} worker exhausted retries for order {order_id} -> quarantine"
    )
    return "dlq"


def _quarantine_and_reject(message: aio_pika.IncomingMessage,
                           worker_name: str, queue_name: str,
                           failure_code: str, order_id: str | None = None) -> None:
    """Write quarantine record + terminal transition in one DB transaction."""
    session = SessionLocal()
    try:
        body_text = message.body.decode("utf-8", errors="replace")
        try:
            data = json.loads(body_text)
        except Exception:
            data = {}
        oid = order_id or data.get("order_id")
        eid = data.get("event_id") or message.message_id
        etype = data.get("event_type") or "unknown"
        attempts = get_retry_count(message)

        write_quarantine_record(
            session, event_id=eid, event_type=etype, order_id=oid,
            source=f"{worker_name}:{queue_name}", attempts=attempts,
            failure_code=failure_code, payload=body_text,
        )
        handle_terminal_failure(session, worker_name, oid, eid)
        session.commit()
    except Exception:
        session.rollback()
        logger.exception("Failed to write quarantine record")
    finally:
        session.close()


async def run_worker(
    channel: aio_pika.Channel,
    queue_name: str,
    process_fn: Callable[[bytes], Awaitable[bool]],
    worker_name: str,
) -> None:
    """Start a consumer on ``queue_name`` with reliable settlement.

    Declaring the retry exchange here is idempotent; the retry queue and
    its dead-letter routing are declared once at startup by
    ``declare_application_topology``.
    """
    retry_exchange = await channel.declare_exchange(
        name=RETRY_EXCHANGE,
        type=aio_pika.ExchangeType.FANOUT,
        durable=True,
    )
    queue = await channel.get_queue(queue_name)
    logger.info(f"{worker_name} worker started, listening on {queue_name}")

    async def callback(message: aio_pika.IncomingMessage):
        await settle_message(message, retry_exchange, process_fn,
                             worker_name, queue_name)

    await queue.consume(callback)
    # Keep the consumer task alive for the lifetime of the service.
    # Without this the coroutine returns after registering the consumer,
    # asyncio.gather() completes, and the whole worker process exits.
    await asyncio.Future()
