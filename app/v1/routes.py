"""API v1 routes: auth, restaurants, orders, notifications, admin."""

import hashlib
import json
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.database import get_session
from app.models import Order, OrderStatus, OutboxEvent
from app.v1.auth import (
    create_access_token,
    get_current_user,
    require_admin,
    verify_password,
)
from app.v1.models import (
    DriverAssignment,
    IdempotencyRecord,
    MenuItem,
    Notification,
    OrderItem,
    OrderStatusHistory,
    QuarantineRecord,
    Restaurant,
    RetryJob,
    User,
)
from app.v1.schemas import (
    AdminSummary,
    CheckoutAccepted,
    CheckoutRequest,
    DriverOut,
    LoginRequest,
    LoginResponse,
    MenuItemOut,
    NotificationOut,
    OrderHistoryOut,
    OrderItemOut,
    OrderOut,
    Page,
    RestaurantOut,
    UserOut,
)

router = APIRouter(prefix="/api/v1", tags=["v1"])

MAX_PAGE_SIZE = 100


def _request_id() -> str:
    return uuid.uuid4().hex[:12]


def _err(code: str, message: str, http_status: int, details: dict | None = None):
    raise HTTPException(
        status_code=http_status,
        detail={"code": code, "message": message,
                "details": details or {}, "request_id": _request_id()},
    )


def _paginate(query, session: Session, page: int, page_size: int):
    page = max(1, page)
    page_size = min(max(1, page_size), MAX_PAGE_SIZE)
    total = session.execute(
        select(func.count()).select_from(query.subquery())
    ).scalar_one()
    items = session.execute(
        query.offset((page - 1) * page_size).limit(page_size)
    ).scalars().all()
    return items, page, page_size, total


def _order_to_out(order: Order, session: Session) -> OrderOut:
    items = session.execute(
        select(OrderItem).where(OrderItem.order_id == order.id)
    ).scalars().all()
    driver = session.execute(
        select(DriverAssignment).where(DriverAssignment.order_id == order.id)
    ).scalar_one_or_none()
    total_minor = order.total_amount_minor or 0
    return OrderOut(
        id=order.id,
        restaurant_id=order.restaurant_id,
        status=order.status.value,
        currency=order.currency or "INR",
        total_amount_minor=total_minor,
        version=order.version,
        failure_code=order.failure_code,
        driver=DriverOut(name=driver.driver_name) if driver else None,
        items=[OrderItemOut(menu_item_id=i.menu_item_id, name=i.name,
                            quantity=i.quantity, price_minor=i.price_minor)
               for i in items],
        delivery_address=order.delivery_address,
        created_at=order.created_at,
        updated_at=order.updated_at,
    )


# ---------- auth ----------

@router.post("/auth/login", response_model=LoginResponse)
def login(body: LoginRequest, session: Session = Depends(get_session)):
    user = session.execute(
        select(User).where(User.email == body.email)
    ).scalar_one_or_none()
    if not user or not verify_password(body.password, user.password_hash):
        _err("invalid_credentials", "Invalid email or password",
             status.HTTP_401_UNAUTHORIZED)
    token, expires_in = create_access_token(user.id, user.role)
    return LoginResponse(
        access_token=token, expires_in=expires_in,
        user=UserOut(id=user.id, email=user.email, name=user.name, role=user.role),
    )


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)):
    return UserOut(id=user.id, email=user.email, name=user.name, role=user.role)


# ---------- restaurants & menu ----------

@router.get("/restaurants", response_model=Page[RestaurantOut])
def list_restaurants(
    page: int = Query(1, ge=1), page_size: int = Query(20, ge=1, le=100),
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
):
    q = select(Restaurant).where(Restaurant.is_active.is_(True)).order_by(Restaurant.name)
    items, page, page_size, total = _paginate(q, session, page, page_size)
    return Page(items=[RestaurantOut(
        id=r.id, name=r.name, description=r.description,
        image_url=r.image_url, is_active=r.is_active) for r in items],
        page=page, page_size=page_size, total=total)


@router.get("/restaurants/{restaurant_id}/menu", response_model=Page[MenuItemOut])
def restaurant_menu(
    restaurant_id: str,
    page: int = Query(1, ge=1), page_size: int = Query(20, ge=1, le=100),
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
):
    rest = session.execute(
        select(Restaurant).where(Restaurant.id == restaurant_id)
    ).scalar_one_or_none()
    if not rest or not rest.is_active:
        _err("not_found", "Restaurant not found", status.HTTP_404_NOT_FOUND)
    q = select(MenuItem).where(
        MenuItem.restaurant_id == restaurant_id,
        MenuItem.is_available.is_(True),
    ).order_by(MenuItem.name)
    items, page, page_size, total = _paginate(q, session, page, page_size)
    return Page(items=[MenuItemOut(
        id=m.id, restaurant_id=m.restaurant_id, name=m.name,
        description=m.description, price_minor=m.price_minor,
        currency=m.currency, is_available=m.is_available) for m in items],
        page=page, page_size=page_size, total=total)


# ---------- checkout ----------

def _canonical_hash(payload: dict) -> str:
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode()).hexdigest()


@router.post("/orders", status_code=status.HTTP_202_ACCEPTED)
def checkout(
    body: CheckoutRequest,
    response: Response,
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
    idempotency_key: str | None = Header(None, alias="Idempotency-Key"),
):
    if not idempotency_key:
        _err("missing_idempotency_key", "Idempotency-Key header is required",
             status.HTTP_422_UNPROCESSABLE_ENTITY)

    # Validate restaurant
    rest = session.execute(
        select(Restaurant).where(Restaurant.id == body.restaurant_id)
    ).scalar_one_or_none()
    if not rest or not rest.is_active:
        _err("invalid_restaurant", "Restaurant not found or inactive",
             status.HTTP_422_UNPROCESSABLE_ENTITY)

    # Validate items: exist, belong to restaurant, available, single restaurant
    menu_ids = [i.menu_item_id for i in body.items]
    menu_rows = session.execute(
        select(MenuItem).where(MenuItem.id.in_(menu_ids))
    ).scalars().all()
    menu_by_id = {m.id: m for m in menu_rows}
    for ci in body.items:
        m = menu_by_id.get(ci.menu_item_id)
        if not m:
            _err("invalid_item", f"Menu item not found: {ci.menu_item_id}",
                 status.HTTP_422_UNPROCESSABLE_ENTITY,
                 {"menu_item_id": ci.menu_item_id})
        if m.restaurant_id != body.restaurant_id:
            _err("mixed_restaurants", "All items must be from one restaurant",
                 status.HTTP_422_UNPROCESSABLE_ENTITY,
                 {"menu_item_id": ci.menu_item_id})
        if not m.is_available:
            _err("item_unavailable", f"Item unavailable: {m.name}",
                 status.HTTP_422_UNPROCESSABLE_ENTITY,
                 {"menu_item_id": ci.menu_item_id})

    # Server-side total in minor units
    total_minor = sum(menu_by_id[ci.menu_item_id].price_minor * ci.quantity
                      for ci in body.items)

    # Idempotency: same key+user
    payload_hash = _canonical_hash(body.model_dump())
    existing = session.execute(
        select(IdempotencyRecord).where(
            IdempotencyRecord.idempotency_key == idempotency_key,
            IdempotencyRecord.user_id == user.id,
        )
    ).scalar_one_or_none()
    if existing:
        if existing.request_hash != payload_hash:
            _err("idempotency_conflict",
                 "Idempotency-Key was already used with a different payload",
                 status.HTTP_409_CONFLICT)
        stored = json.loads(existing.response_json)
        response.headers["Location"] = f"/api/v1/orders/{stored['order_id']}"
        return stored

    # Create order — one transaction: order, items, history, idempotency, outbox
    order_id = str(uuid.uuid4())
    total_str = f"{total_minor // 100}.{total_minor % 100:02d}"
    order = Order(
        id=order_id,
        user_id=user.id,
        restaurant_id=body.restaurant_id,
        customer_name=user.name,
        customer_email=user.email,
        customer_phone="0000000000",
        delivery_address=body.delivery_address,
        items=json.dumps([{"menu_item_id": ci.menu_item_id,
                           "quantity": ci.quantity} for ci in body.items]),
        status=OrderStatus.PENDING,
        total_amount=total_str,  # legacy decimal string for existing workers
        total_amount_minor=total_minor,
        currency="INR",
        version=1,
        payment_status="pending",
    )
    session.add(order)
    session.flush()

    for ci in body.items:
        m = menu_by_id[ci.menu_item_id]
        session.add(OrderItem(order_id=order_id, menu_item_id=m.id,
                              name=m.name, quantity=ci.quantity,
                              price_minor=m.price_minor))

    session.add(OrderStatusHistory(order_id=order_id, from_status=None,
                                   to_status="PENDING", version=1))

    event_id = str(uuid.uuid4())
    session.add(OutboxEvent(
        id=event_id,
        event_type="order.created",
        order_id=order_id,
        payload=json.dumps({
            "event_id": event_id,
            "event_type": "order.created",
            "order_id": order_id,
            "restaurant_id": body.restaurant_id,
            "total_amount_minor": total_minor,
            "currency": "INR",
            "status": "PENDING",
        }),
    ))

    accepted = CheckoutAccepted(
        order_id=order_id, status="PENDING", currency="INR",
        total_amount_minor=total_minor, version=1,
    )
    session.add(IdempotencyRecord(
        idempotency_key=idempotency_key, user_id=user.id,
        request_hash=payload_hash, order_id=order_id,
        response_json=accepted.model_dump_json(),
    ))

    session.commit()

    response.headers["Location"] = f"/api/v1/orders/{order_id}"
    return json.loads(accepted.model_dump_json())


# ---------- orders ----------

@router.get("/orders", response_model=Page[OrderOut])
def list_orders(
    page: int = Query(1, ge=1), page_size: int = Query(20, ge=1, le=100),
    status_filter: str | None = Query(None, alias="status"),
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
):
    q = select(Order).where(Order.user_id == user.id).order_by(Order.created_at.desc())
    if status_filter:
        try:
            st = OrderStatus(status_filter)
        except ValueError:
            _err("invalid_status", f"Unknown status: {status_filter}",
                 status.HTTP_422_UNPROCESSABLE_ENTITY)
        q = q.where(Order.status == st)
    items, page, page_size, total = _paginate(q, session, page, page_size)
    return Page(items=[_order_to_out(o, session) for o in items],
                page=page, page_size=page_size, total=total)


def _get_order_or_404(order_id: str, session: Session, user: User) -> Order:
    order = session.execute(select(Order).where(Order.id == order_id)).scalar_one_or_none()
    if not order:
        _err("not_found", "Order not found", status.HTTP_404_NOT_FOUND)
    if user.role != "admin" and order.user_id != user.id:
        _err("not_found", "Order not found", status.HTTP_404_NOT_FOUND)
    return order


@router.get("/orders/{order_id}", response_model=OrderOut)
def get_order_v1(order_id: str, session: Session = Depends(get_session),
                 user: User = Depends(get_current_user)):
    return _order_to_out(_get_order_or_404(order_id, session, user), session)


@router.get("/orders/{order_id}/history", response_model=list[OrderHistoryOut])
def order_history(order_id: str, session: Session = Depends(get_session),
                  user: User = Depends(get_current_user)):
    _get_order_or_404(order_id, session, user)
    rows = session.execute(
        select(OrderStatusHistory).where(OrderStatusHistory.order_id == order_id)
        .order_by(OrderStatusHistory.created_at)
    ).scalars().all()
    return [OrderHistoryOut(from_status=r.from_status, to_status=r.to_status,
                            version=r.version, created_at=r.created_at) for r in rows]


@router.get("/orders/{order_id}/notifications", response_model=Page[NotificationOut])
def order_notifications(
    order_id: str,
    page: int = Query(1, ge=1), page_size: int = Query(20, ge=1, le=100),
    session: Session = Depends(get_session),
    user: User = Depends(get_current_user),
):
    _get_order_or_404(order_id, session, user)
    q = select(Notification).where(
        Notification.order_id == order_id, Notification.user_id == user.id,
    ).order_by(Notification.created_at.desc())
    items, page, page_size, total = _paginate(q, session, page, page_size)
    return Page(items=[NotificationOut(
        id=n.id, order_id=n.order_id, event_type=n.event_type,
        title=n.title, body=n.body, created_at=n.created_at) for n in items],
        page=page, page_size=page_size, total=total)


# ---------- admin ----------

@router.get("/admin/orders", response_model=Page[OrderOut])
def admin_orders(
    page: int = Query(1, ge=1), page_size: int = Query(20, ge=1, le=100),
    status_filter: str | None = Query(None, alias="status"),
    session: Session = Depends(get_session),
    admin: User = Depends(require_admin),
):
    q = select(Order).order_by(Order.created_at.desc())
    if status_filter:
        try:
            st = OrderStatus(status_filter)
        except ValueError:
            _err("invalid_status", f"Unknown status: {status_filter}",
                 status.HTTP_422_UNPROCESSABLE_ENTITY)
        q = q.where(Order.status == st)
    items, page, page_size, total = _paginate(q, session, page, page_size)
    return Page(items=[_order_to_out(o, session) for o in items],
                page=page, page_size=page_size, total=total)


@router.get("/admin/summary", response_model=AdminSummary)
def admin_summary(session: Session = Depends(get_session),
                  admin: User = Depends(require_admin)):
    rows = session.execute(
        select(Order.status, func.count()).group_by(Order.status)
    ).all()
    by_status = {s.value: c for s, c in rows}
    outbox_pending = session.execute(
        select(func.count()).select_from(OutboxEvent).where(OutboxEvent.published == "N")
    ).scalar_one()
    retry_pending = session.execute(
        select(func.count()).select_from(RetryJob)
        .where(RetryJob.available_at <= datetime.utcnow())
    ).scalar_one()
    quarantine_count = session.execute(
        select(func.count()).select_from(QuarantineRecord)
    ).scalar_one()
    return AdminSummary(by_status=by_status, outbox_pending=outbox_pending,
                        retry_pending=retry_pending, quarantine_count=quarantine_count)
