"""API v1 tests: auth, restaurants, checkout idempotency, orders, admin."""

import uuid

import pytest
from sqlalchemy import select

from app.v1.auth import hash_password
from app.v1.models import MenuItem, Restaurant, User
from app.v1.seed import seed as seed_data


@pytest.fixture
def seeded(test_db):
    """Seed users, restaurants, menus into the test DB."""
    # Seed via direct inserts (seed.py uses its own engine)
    cust = User(email="customer@example.com", name="Test Customer",
                role="customer", password_hash=hash_password("customer123"))
    admin = User(email="admin@example.com", name="Test Admin",
                 role="admin", password_hash=hash_password("admin123"))
    test_db.add_all([cust, admin])
    test_db.flush()
    r1 = Restaurant(id="rest_1", name="Biryani Blues", description="desc")
    r2 = Restaurant(id="rest_2", name="Slice Society", description="desc")
    test_db.add_all([r1, r2])
    test_db.flush()
    test_db.add_all([
        MenuItem(id="item_a", restaurant_id="rest_1", name="Biryani",
                 price_minor=24999, currency="INR"),
        MenuItem(id="item_b", restaurant_id="rest_1", name="Raita",
                 price_minor=4999, currency="INR"),
        MenuItem(id="item_c", restaurant_id="rest_2", name="Pizza",
                 price_minor=29999, currency="INR"),
    ])
    test_db.commit()
    return {"customer": cust, "admin": admin}


def _login(client, email, password):
    r = client.post("/api/v1/auth/login",
                    json={"email": email, "password": password})
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def _checkout_body():
    return {
        "restaurant_id": "rest_1",
        "delivery_address": "12 Lake Road, Bengaluru",
        "items": [{"menu_item_id": "item_a", "quantity": 2},
                  {"menu_item_id": "item_b", "quantity": 1}],
    }


# ---------- auth ----------

def test_login_success(client, seeded):
    token = _login(client, "customer@example.com", "customer123")
    assert token


def test_login_bad_password(client, seeded):
    r = client.post("/api/v1/auth/login",
                    json={"email": "customer@example.com", "password": "wrong"})
    assert r.status_code == 401


def test_me_requires_auth(client, seeded):
    assert client.get("/api/v1/me").status_code == 401


def test_me_returns_profile(client, seeded):
    token = _login(client, "customer@example.com", "customer123")
    r = client.get("/api/v1/me", headers=_auth(token))
    assert r.status_code == 200
    assert r.json()["role"] == "customer"


# ---------- restaurants ----------

def test_list_restaurants(client, seeded):
    token = _login(client, "customer@example.com", "customer123")
    r = client.get("/api/v1/restaurants", headers=_auth(token))
    assert r.status_code == 200
    data = r.json()
    assert data["total"] == 2
    assert len(data["items"]) == 2


def test_restaurant_menu(client, seeded):
    token = _login(client, "customer@example.com", "customer123")
    r = client.get("/api/v1/restaurants/rest_1/menu", headers=_auth(token))
    assert r.status_code == 200
    data = r.json()
    assert data["total"] == 2
    prices = {i["id"]: i["price_minor"] for i in data["items"]}
    assert prices["item_a"] == 24999


# ---------- checkout ----------

def test_checkout_requires_idempotency_key(client, seeded):
    token = _login(client, "customer@example.com", "customer123")
    r = client.post("/api/v1/orders", json=_checkout_body(), headers=_auth(token))
    assert r.status_code == 422


def test_checkout_success(client, seeded):
    token = _login(client, "customer@example.com", "customer123")
    key = str(uuid.uuid4())
    r = client.post("/api/v1/orders", json=_checkout_body(),
                    headers={**_auth(token), "Idempotency-Key": key})
    assert r.status_code == 202, r.text
    data = r.json()
    # 2*24999 + 1*4999 = 54997
    assert data["total_amount_minor"] == 54997
    assert data["status"] == "PENDING"
    assert data["version"] == 1
    assert "Location" in r.headers


def test_checkout_idempotent_same_payload(client, seeded):
    token = _login(client, "customer@example.com", "customer123")
    key = str(uuid.uuid4())
    h = {**_auth(token), "Idempotency-Key": key}
    r1 = client.post("/api/v1/orders", json=_checkout_body(), headers=h)
    r2 = client.post("/api/v1/orders", json=_checkout_body(), headers=h)
    assert r1.status_code == 202 and r2.status_code == 202
    assert r1.json()["order_id"] == r2.json()["order_id"]


def test_checkout_idempotency_conflict(client, seeded):
    token = _login(client, "customer@example.com", "customer123")
    key = str(uuid.uuid4())
    h = {**_auth(token), "Idempotency-Key": key}
    body2 = _checkout_body()
    body2["items"] = [{"menu_item_id": "item_a", "quantity": 1}]
    r1 = client.post("/api/v1/orders", json=_checkout_body(), headers=h)
    assert r1.status_code == 202
    r2 = client.post("/api/v1/orders", json=body2, headers=h)
    assert r2.status_code == 409


def test_checkout_rejects_mixed_restaurants(client, seeded):
    token = _login(client, "customer@example.com", "customer123")
    body = _checkout_body()
    body["items"].append({"menu_item_id": "item_c", "quantity": 1})
    r = client.post("/api/v1/orders", json=body,
                    headers={**_auth(token), "Idempotency-Key": str(uuid.uuid4())})
    assert r.status_code == 422


def test_checkout_rejects_unknown_item(client, seeded):
    token = _login(client, "customer@example.com", "customer123")
    body = _checkout_body()
    body["items"] = [{"menu_item_id": "nope", "quantity": 1}]
    r = client.post("/api/v1/orders", json=body,
                    headers={**_auth(token), "Idempotency-Key": str(uuid.uuid4())})
    assert r.status_code == 422


# ---------- order access ----------

def test_customer_cannot_see_others_order(client, seeded, test_db):
    # Customer 1 places order; customer 2 tries to fetch it
    t1 = _login(client, "customer@example.com", "customer123")
    r = client.post("/api/v1/orders", json=_checkout_body(),
                    headers={**_auth(t1), "Idempotency-Key": str(uuid.uuid4())})
    order_id = r.json()["order_id"]
    # Create second customer
    u2 = User(email="c2@test.com", name="C2", role="customer",
              password_hash=hash_password("x"))
    test_db.add(u2)
    test_db.commit()
    t2 = _login(client, "c2@test.com", "x")
    r2 = client.get(f"/api/v1/orders/{order_id}", headers=_auth(t2))
    assert r2.status_code == 404


def test_order_history_and_detail(client, seeded):
    token = _login(client, "customer@example.com", "customer123")
    r = client.post("/api/v1/orders", json=_checkout_body(),
                    headers={**_auth(token), "Idempotency-Key": str(uuid.uuid4())})
    order_id = r.json()["order_id"]
    h = client.get(f"/api/v1/orders/{order_id}/history", headers=_auth(token))
    assert h.status_code == 200
    assert h.json()[0]["to_status"] == "PENDING"
    d = client.get(f"/api/v1/orders/{order_id}", headers=_auth(token))
    assert d.status_code == 200
    assert len(d.json()["items"]) == 2


# ---------- admin ----------

def test_admin_forbidden_for_customer(client, seeded):
    token = _login(client, "customer@example.com", "customer123")
    r = client.get("/api/v1/admin/orders", headers=_auth(token))
    assert r.status_code == 403


def test_admin_can_list_and_summarize(client, seeded):
    ctok = _login(client, "customer@example.com", "customer123")
    client.post("/api/v1/orders", json=_checkout_body(),
                headers={**_auth(ctok), "Idempotency-Key": str(uuid.uuid4())})
    atok = _login(client, "admin@example.com", "admin123")
    r = client.get("/api/v1/admin/orders", headers=_auth(atok))
    assert r.status_code == 200
    assert r.json()["total"] >= 1
    s = client.get("/api/v1/admin/summary", headers=_auth(atok))
    assert s.status_code == 200
    assert s.json()["by_status"]["PENDING"] >= 1
