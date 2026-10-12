"""Payment worker: processes payments and transitions orders.

Consumes ``order.created`` from ``payment.queue`` and emits
``order.paid`` or ``order.payment.failed`` via the outbox table.

Reliability: idempotency is enforced by an atomic ``claim_event`` at the
start of the database transaction; the message is acked only after that
transaction commits. Transient failures return False (bounded retry via
``worker_common.settle_message``); poison messages raise
``NonRetryableError`` (straight to the DLQ).
"""

import asyncio
import json
import logging
import uuid
from typing import Optional

import aio_pika
from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.events import build_envelope
from app.idempotency import claim_event
from app.models import Order, OrderStatus, OutboxEvent
from app.retry import NonRetryableError
from app.v1.failure_config import get_failure_mode
from app.v1.models import SimulatedPayment
from app.v1.worker_helpers import record_transition
from app.worker_common import run_worker

logger = logging.getLogger(__name__)

WORKER_TYPE = "payment"

# In-memory per-order attempt counters for deterministic failure injection.
# Reset on process restart; injection is a dev/test tool, not durable state.
_injection_attempts: dict[str, int] = {}


def _track_injection_attempt(order_id: str) -> int:
    """Increment and return the injection attempt count for an order."""
    _injection_attempts[order_id] = _injection_attempts.get(order_id, 0) + 1
    return _injection_attempts[order_id]


def _reset_injection_attempts(order_id: str) -> None:
    _injection_attempts.pop(order_id, None)


async def process_payment_event(body: bytes, session: Optional[Session] = None) -> bool:
    """
    Process a payment event from the queue.

    This is called when an order.created event arrives in payment.queue.
    Charges the payment and emits either order.paid or order.payment.failed
    (as outbox rows; the outbox publisher relays them to the broker).

    Args:
        body: Message body (JSON)
        session: Optional existing DB session (used by tests)

    Returns:
        True if fully processed and committed (safe to ack),
        False on transient failure (caller should retry with bounds).

    Raises:
        NonRetryableError: message can never succeed (poison -> DLQ).
    """
    try:
        data = json.loads(body.decode("utf-8"))
    except Exception as e:
        raise NonRetryableError(f"unparseable payment event body: {e}")

    order_id = data.get("order_id")
    event_id = data.get("event_id")
    if not order_id or not event_id:
        raise NonRetryableError("missing order_id or event_id in payment event")

    # Deterministic failure injection runs BEFORE the idempotency claim so
    # that injected transient failures actually exercise the retry loop
    # (a claimed event would be absorbed as a duplicate on redelivery).
    # See app/v1/failure_config.py; dev/test only, never in production.
    injection = get_failure_mode("payment", order_id)
    if injection == "always_fail":
        logger.warning(f"Failure injection: payment always_fail for {order_id}")
        return False  # transient -> bounded retries -> PAYMENT_FAILED
    if injection == "fail_twice_then_succeed":
        if _track_injection_attempt(order_id) <= 2:
            logger.warning(f"Failure injection: fail_twice_then_succeed "
                           f"(attempt {_injection_attempts[order_id]}/3) for {order_id}")
            return False
    if injection == "crash_after_charge":
        logger.warning(f"Failure injection: crash_after_charge for {order_id}")
        import os
        os._exit(1)  # hard crash: redelivery must be idempotent

    own_session = session is None
    if own_session:
        session = SessionLocal()
    try:
        # Atomic idempotency claim: exactly one claimer processes the event,
        # even with concurrent worker instances or redeliveries.
        if not claim_event(session, event_id, WORKER_TYPE):
            logger.info(f"Event {event_id} already claimed by payment worker (duplicate)")
            session.rollback()
            return True

        # Extract v2 envelope correlation chain
        correlation_id = data.get("correlation_id")
        causation_id = event_id

        # Fetch order
        order = session.query(Order).filter(Order.id == order_id).first()
        if not order:
            logger.error(f"Order {order_id} not found; claiming without state change")
            session.commit()
            return True

        # State guard: only PENDING orders can be charged.
        if order.status != OrderStatus.PENDING:
            logger.warning(
                f"Order {order_id} is not in PENDING state (current: {order.status}). "
                "Payment already processed or order in unexpected state."
            )
            session.commit()
            return True

        # Simulate payment processing (uses minor units when available)
        payment_success = await _charge_payment(order)

        amount_minor = order.total_amount_minor
        if amount_minor is None:
            # Legacy order: derive minor units from decimal string
            amount_minor = int(round(float(order.total_amount) * 100))

        if payment_success:
            # Versioned transition to PAID + history
            record_transition(session, order, OrderStatus.PAID)
            order.payment_status = "success"
            session.add(order)
            session.add(SimulatedPayment(
                order_id=order.id, amount_minor=amount_minor,
                currency=order.currency or "INR", status="success",
            ))

            # Create order.paid outbox event (v2 envelope)
            envelope = build_envelope(
                event_type="order.paid",
                order_id=order.id,
                order_version=order.version,
                correlation_id=correlation_id,
                causation_id=causation_id,
                data={
                    "amount_minor": amount_minor,
                    "transaction_id": str(uuid.uuid4()),
                },
            )
            session.add(
                OutboxEvent(
                    id=envelope["event_id"],
                    event_type="order.paid",
                    order_id=order.id,
                    payload=json.dumps(envelope),
                )
            )
        else:
            # Versioned transition to PAYMENT_FAILED + history
            record_transition(session, order, OrderStatus.PAYMENT_FAILED)
            order.payment_status = "failed"
            order.failure_code = "PAYMENT_DECLINED"
            session.add(order)
            session.add(SimulatedPayment(
                order_id=order.id, amount_minor=amount_minor,
                currency=order.currency or "INR", status="failed",
                failure_code="PAYMENT_DECLINED",
            ))

            # Create order.payment.failed outbox event (v2 envelope)
            envelope = build_envelope(
                event_type="order.payment.failed",
                order_id=order.id,
                order_version=order.version,
                correlation_id=correlation_id,
                causation_id=causation_id,
                data={"reason": "Insufficient funds"},
            )
            session.add(
                OutboxEvent(
                    id=envelope["event_id"],
                    event_type="order.payment.failed",
                    order_id=order.id,
                    payload=json.dumps(envelope),
                )
            )

        # Single commit: claim + state transition + outbox row are atomic.
        session.commit()

        logger.info(
            f"Payment {'succeeded' if payment_success else 'failed'} "
            f"for order {order_id}."
        )
        return True

    except Exception:
        session.rollback()
        logger.exception("Error processing payment event")
        return False  # Transient: caller applies bounded retry
    finally:
        if own_session:
            session.close()


async def _charge_payment(order: Order) -> bool:
    """
    Mock payment processing.

    Returns True if payment succeeds, False if it fails.
    """
    # Simple mock: fail if total is exactly 999.99 (for testing)
    total = float(order.total_amount)

    if total == 999.99:
        logger.info(f"Mock payment processor: REJECTED (amount: {order.total_amount})")
        return False

    logger.info(f"Mock payment processor: APPROVED (amount: {order.total_amount})")
    await asyncio.sleep(0.1)  # Simulate processing delay
    return True


async def run_payment_worker(channel: aio_pika.Channel):
    """
    Run the payment worker consumer.

    Consumes from payment.queue with explicit, safe acknowledgement.
    """
    await run_worker(channel, "payment.queue", process_payment_event, WORKER_TYPE)
