"""Reliability unit tests (mocked broker; no live RabbitMQ/Postgres needed).

These tests verify the reliability *mechanisms* — routing-key contract,
bounded-retry policy, topology declaration arguments, acknowledgement
semantics, and atomic idempotency — using fakes. They do NOT verify
against a live broker; see tests/test_integration_live.py for the
live-service tests (marked ``live``, skipped without a broker).
"""

import json
from datetime import timedelta

import aio_pika
import pytest

from app import rabbitmq as rabbitmq_module
from app.database import Base
from app.events import EVENT_ROUTING_KEYS, OUTBOX_ROUTING_KEYS, QUEUE_CONFIG, EventType
from app.idempotency import claim_event
from app.models import Order, OrderStatus
from app.rabbitmq import (
    DLQ_QUEUE,
    DLX_EXCHANGE,
    MAIN_EXCHANGE,
    RETRY_EXCHANGE,
    RETRY_QUEUE,
    RabbitMQManager,
)
from app.retry import (
    MAX_RETRIES,
    RETRY_COUNT_HEADER,
    NonRetryableError,
    get_retry_count,
    next_retry_delay_seconds,
    republish_for_retry,
)
from app.worker_common import handle_terminal_failure, settle_message


# ---------------------------------------------------------------------------
# Fakes
# ---------------------------------------------------------------------------

class FakeExchange:
    def __init__(self, name):
        self.name = name
        self.published = []  # list of (message, routing_key, kwargs)

    async def publish(self, message, routing_key="", **kwargs):
        self.published.append((message, routing_key, kwargs))


class FakeQueue:
    def __init__(self, name, **kwargs):
        self.name = name
        self.kwargs = kwargs
        self.bindings = []  # list of (exchange_name, routing_key)

    async def bind(self, exchange, routing_key=""):
        name = exchange.name if hasattr(exchange, "name") else exchange
        self.bindings.append((name, routing_key))


class FakeChannel:
    def __init__(self):
        self.declared_exchanges = {}  # name -> (type, durable)
        self.declared_queues = {}  # name -> FakeQueue
        self.qos = None

    async def set_qos(self, prefetch_count=1):
        self.qos = prefetch_count

    async def declare_exchange(self, name, type, durable=True):
        self.declared_exchanges[name] = (type, durable)
        return FakeExchange(name)

    async def declare_queue(self, name, durable=True, arguments=None):
        queue = FakeQueue(name, durable=durable, arguments=arguments or {})
        self.declared_queues[name] = queue
        return queue


class FakeConnection:
    def __init__(self, channel):
        self._channel = channel
        self.closed = False

    async def channel(self, publisher_confirms=False):
        self.publisher_confirms = publisher_confirms
        return self._channel

    async def close(self):
        self.closed = True


class FakeMessage:
    """Minimal stand-in for aio_pika.IncomingMessage."""

    def __init__(self, body: bytes, headers=None, routing_key="order.created"):
        self.body = body
        self.headers = headers or {}
        self.routing_key = routing_key
        self.message_id = "msg-1"
        self.acked = 0
        self.nacked = 0
        self.rejected = []  # list of requeue flags

    async def ack(self):
        self.acked += 1

    async def nack(self, requeue=True):
        self.nacked += 1

    async def reject(self, requeue=False):
        self.rejected.append(requeue)


# ---------------------------------------------------------------------------
# Routing-key contract (assignment specification)
# ---------------------------------------------------------------------------

class TestRoutingKeyContract:
    def test_event_routing_keys_match_spec(self):
        assert EVENT_ROUTING_KEYS[EventType.ORDER_CREATED] == "order.created"
        assert EVENT_ROUTING_KEYS[EventType.PAYMENT_SUCCESS] == "order.paid"
        assert EVENT_ROUTING_KEYS[EventType.PAYMENT_FAILED] == "order.payment.failed"
        assert EVENT_ROUTING_KEYS[EventType.RESTAURANT_CONFIRMED] == "order.confirmed"
        assert EVENT_ROUTING_KEYS[EventType.DELIVERY_ASSIGNED] == "order.driver.assigned"

    def test_queue_bindings_match_spec(self):
        assert QUEUE_CONFIG["payment.queue"] == ["order.created"]
        assert QUEUE_CONFIG["restaurant.queue"] == ["order.paid"]
        assert QUEUE_CONFIG["delivery.queue"] == ["order.confirmed"]
        assert QUEUE_CONFIG["notification.queue"] == ["order.#"]

    def test_outbox_routing_keys_are_allow_listed(self):
        for key in ("order.created", "order.paid", "order.payment.failed",
                    "order.confirmed", "order.driver.assigned"):
            assert OUTBOX_ROUTING_KEYS[key] == key
        assert OUTBOX_ROUTING_KEYS.get("order.bogus") is None


# ---------------------------------------------------------------------------
# Retry policy
# ---------------------------------------------------------------------------

class TestRetryPolicy:
    def test_max_retries_bounded(self):
        assert MAX_RETRIES == 3

    def test_retry_count_defaults_to_zero(self):
        assert get_retry_count(FakeMessage(b"{}")) == 0

    def test_retry_count_reads_header(self):
        msg = FakeMessage(b"{}", headers={RETRY_COUNT_HEADER: 2})
        assert get_retry_count(msg) == 2

    def test_retry_count_tolerates_malformed_header(self):
        msg = FakeMessage(b"{}", headers={RETRY_COUNT_HEADER: "bogus"})
        assert get_retry_count(msg) == 0

    def test_backoff_matches_spec_delays(self):
        # Spec: 1 initial + 3 delayed retries at 2s, 10s, 30s.
        from app.retry import RETRY_DELAYS_SECONDS
        assert RETRY_DELAYS_SECONDS == [2.0, 10.0, 30.0]
        delays = [next_retry_delay_seconds(i) for i in range(3)]
        assert delays == [2.0, 10.0, 30.0]

    async def test_republish_for_retry_targets_originating_queue(self):
        # Targeted retry routing: the retry copy is addressed to the
        # failing consumer's queue only (via default exchange), never
        # re-fanned-out through the domain exchange.
        exchange = FakeExchange(RETRY_EXCHANGE)
        msg = FakeMessage(b'{"a": 1}', headers={"order_id": "o1"},
                          routing_key="order.created")
        new_count = await republish_for_retry(exchange, msg, "payment.queue")

        assert new_count == 1
        assert len(exchange.published) == 1
        published, routing_key, _ = exchange.published[0]
        assert routing_key == "payment.queue"  # targeted, not topic key
        assert published.headers[RETRY_COUNT_HEADER] == 1
        assert published.headers["order_id"] == "o1"
        assert published.delivery_mode == aio_pika.DeliveryMode.PERSISTENT
        assert published.expiration is not None
        assert published.body == b'{"a": 1}'

    async def test_republish_for_retry_increments_existing_count(self):
        exchange = FakeExchange(RETRY_EXCHANGE)
        msg = FakeMessage(b"{}", headers={RETRY_COUNT_HEADER: 1},
                          routing_key="order.paid")
        new_count = await republish_for_retry(exchange, msg, "restaurant.queue")
        assert new_count == 2
        published, _, _ = exchange.published[0]
        assert published.headers[RETRY_COUNT_HEADER] == 2


# ---------------------------------------------------------------------------
# Topology declaration
# ---------------------------------------------------------------------------

class TestTopologyDeclaration:
    async def _manager_with_fake_channel(self):
        manager = RabbitMQManager("amqp://test")
        manager.channel = FakeChannel()
        manager.exchange = FakeExchange(MAIN_EXCHANGE)
        return manager

    async def test_worker_queues_declare_dead_letter_exchange(self):
        manager = await self._manager_with_fake_channel()
        await manager.declare_application_topology(QUEUE_CONFIG)

        for queue_name in ("payment.queue", "restaurant.queue",
                           "delivery.queue", "notification.queue"):
            queue = manager.channel.declared_queues[queue_name]
            assert queue.kwargs["durable"] is True
            assert queue.kwargs["arguments"] == {
                "x-dead-letter-exchange": DLX_EXCHANGE,
                "x-dead-letter-routing-key": "failed",
            }, f"{queue_name} missing DLX arguments"
        assert DLX_EXCHANGE == "quickbite.dead"

    async def test_retry_queue_dead_letters_to_default_exchange_targeted(self):
        # Targeted retry routing: expired retries go to the default
        # exchange (routing key = originating queue name), never back
        # through the domain exchange.
        manager = await self._manager_with_fake_channel()
        await manager.declare_application_topology(QUEUE_CONFIG)

        queue = manager.channel.declared_queues[RETRY_QUEUE]
        assert queue.kwargs["arguments"] == {
            "x-dead-letter-exchange": ""
        }

    async def test_dead_letter_queue_bound_to_dlx(self):
        manager = await self._manager_with_fake_channel()
        await manager.declare_application_topology(QUEUE_CONFIG)

        assert DLQ_QUEUE in manager.channel.declared_queues
        dlq = manager.channel.declared_queues[DLQ_QUEUE]
        assert (DLX_EXCHANGE, "failed") in dlq.bindings

    async def test_exchanges_declared_durable(self):
        manager = await self._manager_with_fake_channel()
        await manager.declare_application_topology(QUEUE_CONFIG)

        assert manager.channel.declared_exchanges[RETRY_EXCHANGE][1] is True
        assert manager.channel.declared_exchanges[DLX_EXCHANGE][1] is True


# ---------------------------------------------------------------------------
# connect() contract (P0-1 regression)
# ---------------------------------------------------------------------------

class TestConnectContract:
    async def test_connect_returns_manager_and_enables_confirms(self, monkeypatch):
        captured = {}

        async def fake_connect_robust(url, **kwargs):
            captured["url"] = url
            captured["kwargs"] = kwargs
            return FakeConnection(FakeChannel())

        monkeypatch.setattr(rabbitmq_module.aio_pika, "connect_robust",
                            fake_connect_robust)

        manager = await RabbitMQManager("amqp://u:p@h:5672/").connect()

        assert manager is not None
        assert isinstance(manager, RabbitMQManager)
        assert manager.channel is not None
        assert manager.exchange is not None
        # P1-6: publisher confirms must be explicitly enabled
        assert captured["kwargs"].get("publisher_confirms") is True


# ---------------------------------------------------------------------------
# Acknowledgement semantics (P0-4)
# ---------------------------------------------------------------------------

def _sqlite_session():
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker
    from sqlalchemy.pool import StaticPool

    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    return sessionmaker(bind=engine, expire_on_commit=False)()


class TestSettleMessage:
    async def test_success_acks_exactly_once(self):
        message = FakeMessage(b'{"order_id": "o1"}')
        exchange = FakeExchange(RETRY_EXCHANGE)

        async def process_ok(body: bytes) -> bool:
            return True

        result = await settle_message(message, exchange, process_ok, "payment", "payment.queue")

        assert result == "acked"
        assert message.acked == 1
        assert message.nacked == 0
        assert message.rejected == []
        assert exchange.published == []

    async def test_transient_failure_schedules_retry_then_acks_original(self):
        message = FakeMessage(b'{"order_id": "o1"}', routing_key="order.created")
        exchange = FakeExchange(RETRY_EXCHANGE)

        async def process_fail(body: bytes) -> bool:
            return False

        result = await settle_message(message, exchange, process_fail, "payment", "payment.queue")

        assert result == "retried"
        assert len(exchange.published) == 1  # retry copy confirmed first
        assert exchange.published[0][1] == "payment.queue"  # targeted routing
        assert message.acked == 1  # original acked only afterwards
        assert message.rejected == []

    async def test_exception_is_treated_as_transient(self):
        message = FakeMessage(b'{"order_id": "o1"}', routing_key="order.created")
        exchange = FakeExchange(RETRY_EXCHANGE)

        async def process_boom(body: bytes) -> bool:
            raise RuntimeError("db exploded")

        result = await settle_message(message, exchange, process_boom, "payment", "payment.queue")

        assert result == "retried"
        assert len(exchange.published) == 1
        assert message.acked == 1

    async def test_non_retryable_goes_straight_to_dlq(self):
        message = FakeMessage(b"not-json", routing_key="order.created")
        exchange = FakeExchange(RETRY_EXCHANGE)

        async def process_poison(body: bytes) -> bool:
            raise NonRetryableError("unparseable")

        result = await settle_message(message, exchange, process_poison, "payment", "payment.queue")

        assert result == "dlq"
        assert message.rejected == [False]  # reject(requeue=False) -> DLX -> DLQ
        assert message.acked == 0
        assert exchange.published == []  # no retry burned

    async def test_exhausted_retries_reject_to_dlq_and_mark_failed(self, monkeypatch):
        import app.worker_common as worker_common_module

        session = _sqlite_session()
        order = Order(
            id="order-dlq-1",
            customer_name="N",
            customer_email="n@n.com",
            customer_phone="5550000000",
            delivery_address="addr",
            items="[]",
            status=OrderStatus.PENDING,
            total_amount="10.00",
        )
        session.add(order)
        session.commit()

        # Route mark_order_failed at the test session.
        monkeypatch.setattr(
            worker_common_module, "SessionLocal", lambda: session
        )

        body = json.dumps({"order_id": "order-dlq-1",
                           "event_id": "evt-1"}).encode()
        message = FakeMessage(body, headers={RETRY_COUNT_HEADER: MAX_RETRIES},
                              routing_key="order.created")
        exchange = FakeExchange(RETRY_EXCHANGE)

        async def process_fail(body: bytes) -> bool:
            return False

        result = await settle_message(message, exchange, process_fail, "payment", "payment.queue")

        assert result == "dlq"
        assert message.rejected == [False]
        assert exchange.published == []  # no further retry
        # handle_terminal_failure closed the session; re-query for a fresh state.
        order = session.query(Order).filter(Order.id == "order-dlq-1").first()
        assert order.status == OrderStatus.PAYMENT_FAILED  # spec: payment -> PAYMENT_FAILED

    def test_terminal_failure_never_overwrites_terminal(self, monkeypatch):
        import app.worker_common as worker_common_module

        session = _sqlite_session()
        order = Order(
            id="order-term-1",
            customer_name="N",
            customer_email="n@n.com",
            customer_phone="5550000000",
            delivery_address="addr",
            items="[]",
            status=OrderStatus.PAYMENT_FAILED,
            total_amount="10.00",
        )
        session.add(order)
        session.commit()

        handle_terminal_failure(session, "payment", "order-term-1", "evt-1")
        session.commit()
        order = session.query(Order).filter(Order.id == "order-term-1").first()
        assert order.status == OrderStatus.PAYMENT_FAILED


# ---------------------------------------------------------------------------
# Atomic idempotency (P1-7)
# ---------------------------------------------------------------------------

class TestAtomicIdempotency:
    def test_first_claim_wins_second_loses(self):
        session = _sqlite_session()
        assert claim_event(session, "evt-a", "payment") is True
        assert claim_event(session, "evt-a", "payment") is False
        # Different worker type is an independent claim.
        assert claim_event(session, "evt-a", "restaurant") is True

    def test_claim_persists_after_commit(self):
        session = _sqlite_session()
        assert claim_event(session, "evt-b", "payment") is True
        session.commit()
        # Second claim in a new transaction still loses.
        assert claim_event(session, "evt-b", "payment") is False


# ---------------------------------------------------------------------------
# Consumer lifetime: run_worker must not return after registering (regression)
# ---------------------------------------------------------------------------

class TestConsumerLifetime:
    @pytest.mark.asyncio
    async def test_run_worker_stays_alive(self):
        """run_worker must keep consuming forever.

        Regression: an earlier version returned right after
        queue.consume(), so asyncio.gather() completed and the whole
        worker process exited seconds after startup.
        """
        import asyncio

        from app.worker_common import run_worker

        consumed = []

        class FakeQueue:
            async def consume(self, callback):
                consumed.append(callback)
                return "ctag"

        class FakeExchange:
            pass

        class FakeChannel:
            async def declare_exchange(self, name, type, durable=True):
                return FakeExchange()

            async def get_queue(self, name):
                return FakeQueue()

        async def process_fn(body: bytes) -> bool:
            return True

        task = asyncio.create_task(
            run_worker(FakeChannel(), "payment.queue", process_fn, "payment"))
        await asyncio.sleep(0.2)
        # The consumer callback was registered...
        assert len(consumed) == 1
        # ...and the worker task is still alive (not returned).
        assert not task.done(), "run_worker returned; workers would exit!"
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass


# ---------------------------------------------------------------------------
# Milestone 2: quarantine records + worker-aware exhaustion
# ---------------------------------------------------------------------------

class TestQuarantineAndExhaustion:
    def _order(self, session, order_id, status):
        order = Order(
            id=order_id,
            customer_name="N",
            customer_email="n@n.com",
            customer_phone="5550000000",
            delivery_address="addr",
            items="[]",
            status=status,
            total_amount="10.00",
        )
        session.add(order)
        session.commit()
        return order

    async def test_payment_exhaustion_writes_quarantine_and_payment_failed(self, monkeypatch):
        import app.worker_common as wc
        from app.v1.models import QuarantineRecord

        session = _sqlite_session()
        self._order(session, "q-pay-1", OrderStatus.PENDING)
        monkeypatch.setattr(wc, "SessionLocal", lambda: session)

        body = json.dumps({
            "event_id": "evt-q1", "event_type": "order.created",
            "order_id": "q-pay-1"}).encode()
        message = FakeMessage(body, headers={RETRY_COUNT_HEADER: MAX_RETRIES})
        exchange = FakeExchange(RETRY_EXCHANGE)

        async def always_fail(body: bytes) -> bool:
            return False

        result = await settle_message(message, exchange, always_fail,
                                      "payment", "payment.queue")
        assert result == "dlq"

        rec = session.query(QuarantineRecord).filter(
            QuarantineRecord.event_id == "evt-q1").first()
        assert rec is not None
        assert rec.failure_code == "RETRY_EXHAUSTED"
        assert rec.attempts == MAX_RETRIES
        assert rec.source == "payment:payment.queue"

        order = session.query(Order).filter(Order.id == "q-pay-1").first()
        assert order.status == OrderStatus.PAYMENT_FAILED  # spec, not FAILED

    async def test_notification_exhaustion_preserves_business_status(self, monkeypatch):
        import app.worker_common as wc
        from app.v1.models import QuarantineRecord

        session = _sqlite_session()
        self._order(session, "q-notif-1", OrderStatus.DRIVER_ASSIGNED)
        monkeypatch.setattr(wc, "SessionLocal", lambda: session)

        body = json.dumps({
            "event_id": "evt-q2", "event_type": "order.driver.assigned",
            "order_id": "q-notif-1"}).encode()
        message = FakeMessage(body, headers={RETRY_COUNT_HEADER: MAX_RETRIES})
        exchange = FakeExchange(RETRY_EXCHANGE)

        async def always_fail(body: bytes) -> bool:
            return False

        result = await settle_message(message, exchange, always_fail,
                                      "notification", "notification.queue")
        assert result == "dlq"

        # Quarantine record exists...
        rec = session.query(QuarantineRecord).filter(
            QuarantineRecord.event_id == "evt-q2").first()
        assert rec is not None
        # ...but business status untouched.
        order = session.query(Order).filter(Order.id == "q-notif-1").first()
        assert order.status == OrderStatus.DRIVER_ASSIGNED

    async def test_poison_message_quarantined_without_retry(self, monkeypatch):
        import app.worker_common as wc
        from app.v1.models import QuarantineRecord

        session = _sqlite_session()
        self._order(session, "q-poison-1", OrderStatus.PAID)
        monkeypatch.setattr(wc, "SessionLocal", lambda: session)

        body = json.dumps({
            "event_id": "evt-q3", "event_type": "order.paid",
            "order_id": "q-poison-1"}).encode()
        message = FakeMessage(body)
        exchange = FakeExchange(RETRY_EXCHANGE)

        async def poison(body: bytes) -> bool:
            raise NonRetryableError("bad payload")

        result = await settle_message(message, exchange, poison,
                                      "restaurant", "restaurant.queue")
        assert result == "dlq"
        assert exchange.published == []  # no retry burned

        rec = session.query(QuarantineRecord).filter(
            QuarantineRecord.event_id == "evt-q3").first()
        assert rec is not None
        assert rec.failure_code == "POISON_MESSAGE"


# ---------------------------------------------------------------------------
# Milestone 2: event envelope v2
# ---------------------------------------------------------------------------

class TestEnvelopeV2:
    def test_envelope_has_required_fields(self):
        from app.events import build_envelope
        env = build_envelope(
            event_type="order.paid", order_id="o1",
            order_version=3, correlation_id="corr-1", causation_id="cause-1",
            data={"amount_minor": 100},
        )
        assert env["schema_version"] == 1
        assert env["event_type"] == "order.paid"
        assert env["order_id"] == "o1"
        assert env["order_version"] == 3
        assert env["correlation_id"] == "corr-1"
        assert env["causation_id"] == "cause-1"
        assert env["data"] == {"amount_minor": 100}
        assert env["event_id"]  # immutable id present
        assert env["occurred_at"]  # timestamp present

    def test_envelope_defaults_correlation_to_event_id(self):
        from app.events import build_envelope
        env = build_envelope(event_type="order.created", order_id="o2")
        assert env["correlation_id"] == env["event_id"]
        assert env["causation_id"] is None


# ---------------------------------------------------------------------------
# Milestone 2: deterministic failure injection config
# ---------------------------------------------------------------------------

class TestFailureInjectionConfig:
    def test_defaults_to_success(self, monkeypatch):
        from app.v1.failure_config import get_failure_mode
        monkeypatch.delenv("QB_PAYMENT_FAILURE_MODE", raising=False)
        assert get_failure_mode("payment") == "success"

    def test_reads_env_mode(self, monkeypatch):
        from app.v1.failure_config import get_failure_mode
        monkeypatch.setenv("QB_PAYMENT_FAILURE_MODE", "fail_twice_then_succeed")
        assert get_failure_mode("payment") == "fail_twice_then_succeed"

    def test_invalid_mode_falls_back_to_success(self, monkeypatch):
        from app.v1.failure_config import get_failure_mode
        monkeypatch.setenv("QB_PAYMENT_FAILURE_MODE", "explode")
        assert get_failure_mode("payment") == "success"

    def test_unknown_worker_is_success(self):
        from app.v1.failure_config import get_failure_mode
        assert get_failure_mode("nope") == "success"


# ---------------------------------------------------------------------------
# Milestone 2: payment fail_twice_then_succeed injection
# ---------------------------------------------------------------------------

class TestPaymentInjection:
    async def test_fail_twice_then_succeed(self, monkeypatch):
        import app.workers.payment as pay
        from app.v1.models import SimulatedPayment

        monkeypatch.setenv("QB_PAYMENT_FAILURE_MODE", "fail_twice_then_succeed")
        pay._injection_attempts.clear()

        session = _sqlite_session()
        order = Order(
            id="inj-1",
            customer_name="N", customer_email="n@n.com",
            customer_phone="5550000000", delivery_address="addr",
            items="[]", status=OrderStatus.PENDING, total_amount="10.00",
        )
        session.add(order)
        session.commit()

        body = json.dumps({
            "event_id": "evt-inj-1", "event_type": "order.created",
            "order_id": "inj-1"}).encode()

        # Attempts 1-2: transient failure (drives the retry loop)
        assert await pay.process_payment_event(body, session) is False
        assert await pay.process_payment_event(body, session) is False
        # Attempt 3: succeeds and charges exactly once
        assert await pay.process_payment_event(body, session) is True

        order = session.query(Order).filter(Order.id == "inj-1").first()
        assert order.status == OrderStatus.PAID
        assert session.query(SimulatedPayment).filter(
            SimulatedPayment.order_id == "inj-1").count() == 1
        pay._injection_attempts.clear()
        monkeypatch.delenv("QB_PAYMENT_FAILURE_MODE", raising=False)

    async def test_always_fail_returns_transient(self, monkeypatch):
        import app.workers.payment as pay

        monkeypatch.setenv("QB_PAYMENT_FAILURE_MODE", "always_fail")
        session = _sqlite_session()
        order = Order(
            id="inj-2",
            customer_name="N", customer_email="n@n.com",
            customer_phone="5550000000", delivery_address="addr",
            items="[]", status=OrderStatus.PENDING, total_amount="10.00",
        )
        session.add(order)
        session.commit()

        body = json.dumps({
            "event_id": "evt-inj-2", "event_type": "order.created",
            "order_id": "inj-2"}).encode()
        assert await pay.process_payment_event(body, session) is False
        # Order untouched: exhaustion handling (PAYMENT_FAILED) is the
        # settle_message layer's job, not the worker's.
        order = session.query(Order).filter(Order.id == "inj-2").first()
        assert order.status == OrderStatus.PENDING
        monkeypatch.delenv("QB_PAYMENT_FAILURE_MODE", raising=False)
