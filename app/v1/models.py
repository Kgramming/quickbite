"""API v1 domain models: users, restaurants, menus, and supporting records."""

import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)

from app.database import Base


def _uuid():
    return str(uuid.uuid4())


class User(Base):
    """Customer or admin account."""

    __tablename__ = "users"

    id = Column(String(36), primary_key=True, default=_uuid)
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    name = Column(String(255), nullable=False)
    role = Column(String(20), nullable=False, default="customer")  # customer | admin
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)


class Restaurant(Base):
    """Seeded restaurant."""

    __tablename__ = "restaurants"

    id = Column(String(36), primary_key=True, default=_uuid)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    image_url = Column(String(512), nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)


class MenuItem(Base):
    """Menu item with server-authoritative price in minor units."""

    __tablename__ = "menu_items"

    id = Column(String(36), primary_key=True, default=_uuid)
    restaurant_id = Column(String(36), ForeignKey("restaurants.id"), nullable=False, index=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    price_minor = Column(Integer, nullable=False)  # e.g. 24999 = INR 249.99
    currency = Column(String(3), nullable=False, default="INR")
    is_available = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)


class OrderItem(Base):
    """Order line item with price snapshot at checkout."""

    __tablename__ = "order_items"

    id = Column(String(36), primary_key=True, default=_uuid)
    order_id = Column(String(36), ForeignKey("orders.id"), nullable=False, index=True)
    menu_item_id = Column(String(36), nullable=False)
    name = Column(String(255), nullable=False)  # snapshot
    quantity = Column(Integer, nullable=False)
    price_minor = Column(Integer, nullable=False)  # snapshot


class OrderStatusHistory(Base):
    """Append-only order state transition log."""

    __tablename__ = "order_status_history"

    id = Column(String(36), primary_key=True, default=_uuid)
    order_id = Column(String(36), ForeignKey("orders.id"), nullable=False, index=True)
    from_status = Column(String(50), nullable=True)
    to_status = Column(String(50), nullable=False)
    version = Column(Integer, nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)


class SimulatedPayment(Base):
    """Simulated payment record — one per order (unique)."""

    __tablename__ = "simulated_payments"

    id = Column(String(36), primary_key=True, default=_uuid)
    order_id = Column(String(36), ForeignKey("orders.id"), nullable=False, unique=True, index=True)
    amount_minor = Column(Integer, nullable=False)
    currency = Column(String(3), nullable=False, default="INR")
    status = Column(String(20), nullable=False)  # success | failed
    failure_code = Column(String(100), nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)


class DriverAssignment(Base):
    """Simulated driver assignment — one per order (unique)."""

    __tablename__ = "driver_assignments"

    id = Column(String(36), primary_key=True, default=_uuid)
    order_id = Column(String(36), ForeignKey("orders.id"), nullable=False, unique=True, index=True)
    driver_name = Column(String(255), nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)


class Notification(Base):
    """Persisted customer notification."""

    __tablename__ = "notifications"

    id = Column(String(36), primary_key=True, default=_uuid)
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    order_id = Column(String(36), nullable=False, index=True)
    event_type = Column(String(100), nullable=False)
    title = Column(String(255), nullable=False)
    body = Column(Text, nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint("user_id", "order_id", "event_type", name="uq_notification_user_order_event"),
    )


class IdempotencyRecord(Base):
    """Checkout idempotency: key scoped per customer with request hash."""

    __tablename__ = "idempotency_records"

    id = Column(String(36), primary_key=True, default=_uuid)
    idempotency_key = Column(String(255), nullable=False, index=True)
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    request_hash = Column(String(64), nullable=False)  # sha256 of canonical payload
    order_id = Column(String(36), nullable=False)
    response_json = Column(Text, nullable=False)  # canonical acceptance response
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint("idempotency_key", "user_id", name="uq_idempotency_key_user"),
    )


class RetryJob(Base):
    """Scheduled targeted retry for a failed consumer delivery."""

    __tablename__ = "retry_jobs"

    id = Column(String(36), primary_key=True, default=_uuid)
    event_id = Column(String(100), nullable=False, index=True)
    consumer = Column(String(50), nullable=False)  # payment | restaurant | delivery | notification
    attempt = Column(Integer, nullable=False)
    available_at = Column(DateTime, nullable=False, index=True)
    payload = Column(Text, nullable=False)  # event envelope JSON
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint("event_id", "consumer", "attempt", name="uq_retry_event_consumer_attempt"),
    )


class QuarantineRecord(Base):
    """Quarantined (dead-lettered) event with inspection metadata."""

    __tablename__ = "quarantine_records"

    id = Column(String(36), primary_key=True, default=_uuid)
    event_id = Column(String(100), nullable=False, index=True)
    event_type = Column(String(100), nullable=False)
    order_id = Column(String(36), nullable=True, index=True)
    source = Column(String(100), nullable=False)  # consumer/queue name
    attempts = Column(Integer, nullable=False, default=0)
    failure_code = Column(String(100), nullable=False)
    payload = Column(Text, nullable=False)  # original envelope JSON
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)


# Helpful composite index for order listing
Index("ix_orders_user_status", "orders.user_id", "orders.status")
