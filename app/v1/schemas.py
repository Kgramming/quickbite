"""API v1 request/response schemas."""

from datetime import datetime
from typing import Generic, Optional, TypeVar

from pydantic import BaseModel, EmailStr, Field

T = TypeVar("T")


# ---------- errors ----------

class ErrorResponse(BaseModel):
    code: str
    message: str
    details: Optional[dict] = None
    request_id: str


# ---------- pagination ----------

class Page(BaseModel, Generic[T]):
    items: list[T]
    page: int
    page_size: int
    total: int


# ---------- auth ----------

class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1)


class UserOut(BaseModel):
    id: str
    email: str
    name: str
    role: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserOut


# ---------- restaurants & menu ----------

class RestaurantOut(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    image_url: Optional[str] = None
    is_active: bool


class MenuItemOut(BaseModel):
    id: str
    restaurant_id: str
    name: str
    description: Optional[str] = None
    price_minor: int
    currency: str
    is_available: bool


# ---------- checkout ----------

class CheckoutItem(BaseModel):
    menu_item_id: str
    quantity: int = Field(ge=1, le=20)


class CheckoutRequest(BaseModel):
    restaurant_id: str
    delivery_address: str = Field(min_length=5, max_length=1000)
    items: list[CheckoutItem] = Field(min_length=1, max_length=20)


class CheckoutAccepted(BaseModel):
    order_id: str
    status: str
    currency: str
    total_amount_minor: int
    version: int
    message: str = "Order accepted for asynchronous processing."


# ---------- orders ----------

class OrderItemOut(BaseModel):
    menu_item_id: str
    name: str
    quantity: int
    price_minor: int


class DriverOut(BaseModel):
    name: str


class OrderOut(BaseModel):
    id: str
    restaurant_id: Optional[str] = None
    status: str
    currency: str
    total_amount_minor: int
    version: int
    failure_code: Optional[str] = None
    driver: Optional[DriverOut] = None
    items: list[OrderItemOut] = []
    delivery_address: str
    created_at: datetime
    updated_at: datetime


class OrderHistoryOut(BaseModel):
    from_status: Optional[str] = None
    to_status: str
    version: int
    created_at: datetime


class NotificationOut(BaseModel):
    id: str
    order_id: str
    event_type: str
    title: str
    body: str
    created_at: datetime


# ---------- admin ----------

class AdminSummary(BaseModel):
    by_status: dict[str, int]
    outbox_pending: int
    retry_pending: int
    quarantine_count: int
