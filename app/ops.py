"""Operational endpoints for the QuickBite demo console.

These power the dashboard UI (order tracker, pipeline visualization,
chaos buttons). They are read-only or demo-scoped; the core order API
lives in app/routes.py.
"""

import base64
import json
import logging
import urllib.parse
import urllib.request
import uuid
from datetime import datetime

import aio_pika
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_session
from app.events import QUEUE_CONFIG
from app.rabbitmq import MAIN_EXCHANGE
from app.models import Order, OrderStatus, OutboxEvent
from app.schemas import OrderResponse

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["ops"])


# ---------------------------------------------------------------------------
# Orders: list + event timeline
# ---------------------------------------------------------------------------

@router.get("/orders", response_model=list[OrderResponse])
def list_orders(
    limit: int = Query(default=20, le=100),
    session: Session = Depends(get_session),
):
    """Recent orders, newest first (for the live tracker)."""
    stmt = (
        select(Order)
        .order_by(desc(Order.created_at))
        .limit(limit)
    )
    orders = session.execute(stmt).scalars().all()
    return [OrderResponse.model_validate(o) for o in orders]


class OrderEventOut(BaseModel):
    id: str
    event_type: str
    published: str
    created_at: datetime | None = None
    published_at: datetime | None = None


@router.get("/orders/{order_id}/events", response_model=list[OrderEventOut])
def order_events(
    order_id: str,
    session: Session = Depends(get_session),
):
    """Outbox events for one order — the timeline the dashboard shows."""
    stmt = (
        select(OutboxEvent)
        .where(OutboxEvent.order_id == order_id)
        .order_by(OutboxEvent.created_at)
    )
    events = session.execute(stmt).scalars().all()
    return [
        OrderEventOut(
            id=e.id,
            event_type=e.event_type,
            published=e.published,
            created_at=e.created_at,
            published_at=e.published_at,
        )
        for e in events
    ]


@router.get("/events/recent", response_model=list[OrderEventOut])
def recent_events(
    limit: int = Query(default=40, le=100),
    session: Session = Depends(get_session),
):
    """Recent outbox events across orders — the streaming event log feed."""
    stmt = (
        select(OutboxEvent)
        .order_by(desc(OutboxEvent.created_at))
        .limit(limit)
    )
    events = session.execute(stmt).scalars().all()
    return [
        OrderEventOut(
            id=e.id,
            event_type=e.event_type,
            published=e.published,
            created_at=e.created_at,
            published_at=e.published_at,
        )
        for e in events
    ]


# ---------------------------------------------------------------------------
# Queue depths via the RabbitMQ management API (no new dependencies)
# ---------------------------------------------------------------------------

class QueueDepthOut(BaseModel):
    name: str
    messages: int
    consumers: int


@router.get("/queues", response_model=list[QueueDepthOut])
def queue_depths():
    """Live depth + consumer count per QuickBite queue.

    Read from the RabbitMQ management HTTP API. Fails soft (empty list)
    when the management plugin is unreachable so the dashboard keeps
    working.
    """
    watched = list(QUEUE_CONFIG) + ["orders.dead-letter.queue",
                                    "orders.retry.queue"]
    vhost = urllib.parse.quote(settings.rabbitmq_vhost or "/", safe="")
    mgmt_url = f"http://{settings.rabbitmq_host}:15672/api/queues/{vhost}"
    try:
        req = urllib.request.Request(mgmt_url)
        creds = f"{settings.rabbitmq_user}:{settings.rabbitmq_password}"
        req.add_header(
            "Authorization",
            "Basic " + base64.b64encode(creds.encode()).decode(),
        )
        with urllib.request.urlopen(req, timeout=4) as resp:
            queues = json.loads(resp.read().decode())
    except Exception as e:
        logger.warning(f"RabbitMQ management API unreachable: {e}")
        return []

    by_name = {q["name"]: q for q in queues}
    return [
        QueueDepthOut(
            name=name,
            messages=int(by_name.get(name, {}).get("messages", 0)),
            consumers=int(by_name.get(name, {}).get("consumers", 0)),
        )
        for name in watched
    ]


# ---------------------------------------------------------------------------
# Chaos buttons (demo-scoped)
# ---------------------------------------------------------------------------

def _rabbitmq_url() -> str:
    return (
        f"amqp://{settings.rabbitmq_user}:{settings.rabbitmq_password}"
        f"@{settings.rabbitmq_host}:{settings.rabbitmq_port}/{settings.rabbitmq_vhost}"
    )


async def _publish(routing_key: str, body: bytes, headers: dict | None = None):
    """Publish one message to the main exchange (demo/chaos use)."""
    connection = await aio_pika.connect_robust(_rabbitmq_url())
    try:
        channel = await connection.channel(publisher_confirms=True)
        exchange = await channel.declare_exchange(
            MAIN_EXCHANGE, aio_pika.ExchangeType.TOPIC, durable=True
        )
        await exchange.publish(
            aio_pika.Message(
                body=body,
                delivery_mode=aio_pika.DeliveryMode.PERSISTENT,
                headers=headers or {},
            ),
            routing_key=routing_key,
        )
    finally:
        await connection.close()


@router.post("/chaos/poison", status_code=status.HTTP_202_ACCEPTED)
async def chaos_poison():
    """Publish an unparseable message (poison pill) to watch it land in
    the DLQ. Demo only."""
    await _publish(
        "order.created",
        b"this-is-not-json-poison-pill",
        headers={"order_id": f"poison-{uuid.uuid4().hex[:8]}"},
    )
    return {"status": "poison published", "routing_key": "order.created"}


@router.post("/chaos/duplicate/{order_id}", status_code=status.HTTP_202_ACCEPTED)
async def chaos_duplicate(order_id: str, session: Session = Depends(get_session)):
    """Republish an order's original order.created payload to prove
    idempotent redelivery. Demo only."""
    stmt = (
        select(OutboxEvent)
        .where(OutboxEvent.order_id == order_id,
               OutboxEvent.event_type == "order.created")
        .order_by(OutboxEvent.created_at)
    )
    event = session.execute(stmt).scalars().first()
    if not event:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No order.created event for order {order_id}",
        )
    payload = json.loads(event.payload)
    await _publish(
        "order.created",
        event.payload.encode(),
        headers={"order_id": order_id},
    )
    return {
        "status": "duplicate published",
        "order_id": order_id,
        "event_id": payload.get("event_id"),
    }


@router.get("/chaos/payment-fail-hint")
def payment_fail_hint():
    """How to trigger the payment-failure path from the dashboard form."""
    return {
        "hint": "Create an order with total_amount 999.99 — "
                "the mock processor declines it and the order goes to "
                "PAYMENT_FAILED without advancing.",
        "total_amount": "999.99",
    }
