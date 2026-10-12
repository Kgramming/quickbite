"""Tests for the demo-console ops endpoints (app/ops.py). SQLite-backed."""

import json
import uuid

import pytest
from app.models import Order, OrderStatus, OutboxEvent


def _order(session, status=OrderStatus.PENDING):
    oid = str(uuid.uuid4())
    session.add(Order(
        id=oid, customer_name="Ops", customer_email="ops@x.com",
        customer_phone="5550000000", delivery_address="1 Ops St",
        items="[]", status=status, total_amount="10.00",
        payment_status="pending",
    ))
    session.commit()
    return oid


def _event(session, order_id, event_type="order.created"):
    eid = str(uuid.uuid4())
    session.add(OutboxEvent(
        id=eid, event_type=event_type, order_id=order_id,
        payload=json.dumps({"event_id": eid, "order_id": order_id}),
    ))
    session.commit()
    return eid


class TestOrderListing:
    def test_list_orders_newest_first(self, client, test_db):
        o1 = _order(test_db)
        o2 = _order(test_db)
        r = client.get("/api/orders?limit=20")
        assert r.status_code == 200
        ids = [o["id"] for o in r.json()]
        assert o2 in ids and o1 in ids
        # newest first
        assert ids.index(o2) < ids.index(o1)

    def test_order_events_timeline(self, client, test_db):
        oid = _order(test_db)
        _event(test_db, oid, "order.created")
        _event(test_db, oid, "order.paid")
        r = client.get(f"/api/orders/{oid}/events")
        assert r.status_code == 200
        types = [e["event_type"] for e in r.json()]
        assert types == ["order.created", "order.paid"]

    def test_recent_events(self, client, test_db):
        oid = _order(test_db)
        _event(test_db, oid, "order.created")
        r = client.get("/api/events/recent?limit=40")
        assert r.status_code == 200
        assert any(e["event_type"] == "order.created" for e in r.json())


class TestChaos:
    def test_poison_publishes(self, client, monkeypatch):
        import app.ops as ops_module

        calls = []

        async def fake_publish(routing_key, body, headers=None):
            calls.append((routing_key, body))

        monkeypatch.setattr(ops_module, "_publish", fake_publish)
        r = client.post("/api/chaos/poison")
        assert r.status_code == 202
        assert len(calls) == 1
        assert calls[0][0] == "order.created"
        assert calls[0][1] == b"this-is-not-json-poison-pill"

    def test_duplicate_republishes_original(self, client, test_db, monkeypatch):
        import app.ops as ops_module

        oid = _order(test_db)
        eid = _event(test_db, oid, "order.created")

        calls = []

        async def fake_publish(routing_key, body, headers=None):
            calls.append((routing_key, body, headers))

        monkeypatch.setattr(ops_module, "_publish", fake_publish)
        r = client.post(f"/api/chaos/duplicate/{oid}")
        assert r.status_code == 202
        assert len(calls) == 1
        rk, body, headers = calls[0]
        assert rk == "order.created"
        assert json.loads(body)["event_id"] == eid
        assert headers["order_id"] == oid

    def test_duplicate_missing_order(self, client):
        r = client.post(f"/api/chaos/duplicate/{uuid.uuid4()}")
        assert r.status_code == 404


class TestQueues:
    def test_queues_soft_fail(self, client, monkeypatch):
        """Management API down -> empty list, not a 500."""
        import urllib.request

        def boom(*a, **k):
            raise ConnectionError("nope")

        monkeypatch.setattr(urllib.request, "urlopen", boom)
        r = client.get("/api/queues")
        assert r.status_code == 200
        assert r.json() == []


class TestDashboardPage:
    def test_dashboard_served(self, client):
        r = client.get("/dashboard")
        assert r.status_code == 200
        assert "QuickBite" in r.text
        assert "operations console" in r.text.lower()
