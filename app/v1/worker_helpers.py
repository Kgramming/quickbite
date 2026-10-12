"""Shared helpers for v1-aware workers: versioned transitions + history."""

from app.models import OrderStatus
from app.v1.models import OrderStatusHistory


def record_transition(session, order, to_status: OrderStatus):
    """Apply a versioned status transition and append history.

    Must be called inside the worker's transaction, before commit.
    """
    from_status = order.status
    order.version = (order.version or 1) + 1
    order.status = to_status
    session.add(OrderStatusHistory(
        order_id=order.id,
        from_status=from_status.value if from_status else None,
        to_status=to_status.value,
        version=order.version,
    ))
