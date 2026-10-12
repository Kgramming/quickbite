"""Notification worker: sends notifications to customers.

Consumes all ``order.*`` events from ``notification.queue``. It never
updates order state and never publishes pipeline events, so its
downtime or slowness cannot stall payment/restaurant/delivery.

Reliability: atomic ``claim_event`` idempotency, ack only after the
claim commits, bounded retries on transient failure,
``NonRetryableError`` for poison messages.
"""

import asyncio
import json
import logging
from typing import Optional

import aio_pika
from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.idempotency import claim_event
from app.models import Order
from app.retry import NonRetryableError
from app.v1.models import Notification
from app.worker_common import run_worker

logger = logging.getLogger(__name__)

WORKER_TYPE = "notification"

# Human-readable notification copy per event type
_NOTIFICATION_COPY = {
    "order.created": ("Order received", "We've received your order and started processing it."),
    "order.paid": ("Payment successful", "Your payment went through. The restaurant is preparing your order."),
    "order.payment.failed": ("Payment failed", "We couldn't charge for your order. Please try again with a different method."),
    "order.confirmed": ("Order confirmed", "The restaurant confirmed your order and started cooking."),
    "order.driver.assigned": ("Driver assigned", "A driver has been assigned and is on the way to the restaurant."),
    "order.failed": ("Order failed", "Something went wrong and your order couldn't be completed."),
}


async def process_notification_event(body: bytes, session: Optional[Session] = None) -> bool:
    """
    Process a notification event from the queue.

    This worker listens to all order.* events and sends appropriate
    notifications. It does not update order state, only sends
    notifications (mock: logs to console).

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
        raise NonRetryableError(f"unparseable notification event body: {e}")

    order_id = data.get("order_id")
    event_id = data.get("event_id")
    event_type = data.get("event_type")
    if not order_id or not event_id:
        raise NonRetryableError("missing order_id or event_id in notification event")

    own_session = session is None
    if own_session:
        session = SessionLocal()
    try:
        # Atomic idempotency claim: each event notifies exactly once.
        if not claim_event(session, event_id, WORKER_TYPE):
            logger.info(f"Notification already claimed for event {event_id} (duplicate)")
            session.rollback()
            return True

        # Fetch order
        order = session.query(Order).filter(Order.id == order_id).first()
        if not order:
            logger.warning(f"Order {order_id} not found for notification")
            session.commit()
            return True

        # Persist notification (v1 orders have user_id; legacy orders fall back to no user link)
        title, body_text = _NOTIFICATION_COPY.get(
            event_type, ("Order update", f"Update for your order: {event_type}"))
        if order.user_id:
            session.add(Notification(
                user_id=order.user_id,
                order_id=order_id,
                event_type=event_type or "unknown",
                title=title,
                body=f"{body_text} (Order {order_id[:8]})",
            ))

        # Send notification based on event type
        await _send_notification(order, event_type)

        # Commit the claim + notification: exactly once.
        session.commit()

        logger.info(f"Notification sent for order {order_id} (event: {event_type})")
        return True

    except Exception:
        session.rollback()
        logger.exception("Error processing notification event")
        return False  # Transient: caller applies bounded retry
    finally:
        if own_session:
            session.close()


async def _send_notification(order: Order, event_type: str):
    """Mock notification sending."""
    logger.info(
        f"Sending notification to {order.customer_email}: "
        f"Order {order.id} - {event_type} (status: {order.status})"
    )
    await asyncio.sleep(0.05)  # Simulate sending delay
    logger.info(f"Notification sent to {order.customer_email}")


async def run_notification_worker(channel: aio_pika.Channel):
    """
    Run the notification worker consumer.

    Consumes from notification.queue (all order events) with explicit,
    safe acknowledgement.
    """
    await run_worker(channel, "notification.queue", process_notification_event, WORKER_TYPE)
