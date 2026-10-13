"""Load test: 100 orders through the full pipeline.

Measures order creation latency, throughput, and idempotency behavior.
Uses the isolated quickbite_test_db; safe to run alongside production.

Run with:
    QUICKBITE_RUN_LIVE=1 pytest tests/test_load.py -v -s

Requires: docker compose up -d (postgres, rabbitmq, api running on 8002)
"""

import asyncio
import json
import time
import uuid
from datetime import datetime
from typing import NamedTuple

import aio_pika
import pytest
import requests
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

from app.database import Base
from app.events import QUEUE_CONFIG
from app.models import Order, OrderStatus, OutboxEvent
from app.rabbitmq import DLQ_QUEUE, MAIN_EXCHANGE, RETRY_EXCHANGE, RabbitMQManager

# Load test configuration
RUN_LIVE = __import__("os").environ.get("QUICKBITE_RUN_LIVE") == "1"
DATABASE_URL = __import__("os").environ.get(
    "QUICKBITE_TEST_DATABASE_URL",
    "postgresql+psycopg://quickbite_user:quickbite_password@127.0.0.1:5434/quickbite_test_db",
)
RABBITMQ_URL = __import__("os").environ.get(
    "QUICKBITE_TEST_RABBITMQ_URL",
    "amqp://quickbite:quickbite_password@127.0.0.1:5672/%2Ftest",
)
API_BASE_URL = "http://127.0.0.1:8002"

NUM_ORDERS = 100
BATCH_SIZE = 10  # Process in batches to avoid overwhelming the API

pytestmark = [
    pytest.mark.live,
    pytest.mark.skipif(not RUN_LIVE, reason="live test (set QUICKBITE_RUN_LIVE=1)"),
]


class LoadTestResult(NamedTuple):
    """Single order creation result."""
    order_id: str | None
    latency_ms: float
    status_code: int
    success: bool
    error: str | None = None


class LoadTestSummary(NamedTuple):
    """Aggregate statistics."""
    total_orders: int
    successful: int
    failed: int
    throughput_orders_per_sec: float
    latency_min_ms: float
    latency_max_ms: float
    latency_p50_ms: float
    latency_p95_ms: float
    latency_p99_ms: float
    latency_mean_ms: float
    idempotency_tested: bool
    idempotency_success: bool


@pytest.fixture(scope="module")
def load_test_db():
    """Isolated test database session."""
    engine = create_engine(DATABASE_URL, future=True)
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    Base.metadata.create_all(bind=engine)
    factory = sessionmaker(bind=engine, expire_on_commit=False)
    yield factory
    # Cleanup: drop pooled connections and truncate test tables
    engine.dispose()
    with engine.begin() as conn:
        conn.execute(text("SET statement_timeout = '5s'"))
        for table in ("outbox_events", "orders"):
            conn.execute(text(f"TRUNCATE {table} CASCADE"))
        conn.commit()
    engine.dispose()


@pytest.fixture(scope="module")
def load_test_loop():
    """Single event loop for RabbitMQ operations."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="module")
def load_test_rabbitmq(load_test_loop):
    """Connected RabbitMQ manager (with isolated /test vhost)."""

    async def setup():
        manager = await RabbitMQManager(RABBITMQ_URL).connect()
        await manager.declare_application_topology(QUEUE_CONFIG)
        # Clean the queues for a deterministic test
        for queue_name in list(QUEUE_CONFIG) + [DLQ_QUEUE]:
            queue = await manager.channel.get_queue(queue_name)
            await queue.purge()
        return manager

    manager = load_test_loop.run_until_complete(setup())
    yield manager
    load_test_loop.run_until_complete(manager.close())


class TestLoadBenchmark100Orders:
    """Load test: create 100 orders and measure throughput/latency."""

    def test_100_order_throughput_and_latency(self, load_test_db, load_test_loop, load_test_rabbitmq):
        """Create 100 orders, record latency and throughput."""
        results = []
        start_time = time.time()

        # Batch creation for realistic load
        for batch_idx in range(0, NUM_ORDERS, BATCH_SIZE):
            batch_end = min(batch_idx + BATCH_SIZE, NUM_ORDERS)
            batch_size = batch_end - batch_idx

            # Create batch in parallel-ish (sequential requests, but grouped)
            for order_idx in range(batch_size):
                order_num = batch_idx + order_idx + 1
                result = _create_order(order_num)
                results.append(result)

            # Small delay between batches to avoid overwhelming the API
            if batch_end < NUM_ORDERS:
                time.sleep(0.1)

        end_time = time.time()
        total_time = end_time - start_time

        # Compute summary statistics
        successful = sum(1 for r in results if r.success)
        failed = sum(1 for r in results if not r.success)
        latencies = sorted([r.latency_ms for r in results if r.success])

        summary = LoadTestSummary(
            total_orders=NUM_ORDERS,
            successful=successful,
            failed=failed,
            throughput_orders_per_sec=successful / total_time if total_time > 0 else 0,
            latency_min_ms=min(latencies) if latencies else 0,
            latency_max_ms=max(latencies) if latencies else 0,
            latency_p50_ms=latencies[len(latencies) // 2] if latencies else 0,
            latency_p95_ms=latencies[int(len(latencies) * 0.95)] if latencies else 0,
            latency_p99_ms=latencies[int(len(latencies) * 0.99)] if latencies else 0,
            latency_mean_ms=sum(latencies) / len(latencies) if latencies else 0,
            idempotency_tested=True,
            idempotency_success=_test_idempotency(results),
        )

        # Print detailed results
        print("\n" + "=" * 60)
        print("QUICKBITE LOAD TEST RESULTS (100 Orders)")
        print("=" * 60)
        print(f"Timestamp: {datetime.utcnow().isoformat()}")
        print(f"API: {API_BASE_URL}")
        print(f"Database: {DATABASE_URL.split('/')[-1]}")
        print(f"Environment: isolated test DB (quickbite_test_db)")
        print()
        print("THROUGHPUT & SUCCESS")
        print(f"  Total Orders:        {summary.total_orders}")
        print(f"  Successful:          {summary.successful}")
        print(f"  Failed:              {summary.failed}")
        print(f"  Success Rate:        {100.0 * summary.successful / summary.total_orders:.1f}%")
        print(f"  Total Time:          {total_time:.2f}s")
        print(f"  Throughput:          {summary.throughput_orders_per_sec:.2f} orders/sec")
        print()
        print("LATENCY (Order Creation, ms)")
        print(f"  Min:                 {summary.latency_min_ms:.2f}")
        print(f"  P50:                 {summary.latency_p50_ms:.2f}")
        print(f"  P95:                 {summary.latency_p95_ms:.2f}")
        print(f"  P99:                 {summary.latency_p99_ms:.2f}")
        print(f"  Max:                 {summary.latency_max_ms:.2f}")
        print(f"  Mean:                {summary.latency_mean_ms:.2f}")
        print()
        print("IDEMPOTENCY")
        print(f"  Tested:              {summary.idempotency_tested}")
        print(f"  Success:             {summary.idempotency_success}")
        print("=" * 60)
        print()

        # Save results to file for documentation
        _save_results(summary, results)

        # Assertions
        assert summary.successful == summary.total_orders, \
            f"Expected all orders to succeed; {summary.failed} failed"
        assert summary.throughput_orders_per_sec > 0, \
            "Throughput should be positive"
        assert summary.latency_mean_ms < 1000, \
            "Average latency should be < 1 second"
        assert summary.idempotency_success, \
            "Idempotency check failed"

    def test_verify_outbox_events_created(self, load_test_db):
        """Verify that 100 outbox events were created (one per order)."""
        session = load_test_db()
        try:
            count = session.query(OutboxEvent).count()
            assert count >= NUM_ORDERS, \
                f"Expected >= {NUM_ORDERS} outbox events; got {count}"
            print(f"\n✓ Outbox events created: {count}")
        finally:
            session.close()

    def test_verify_orders_in_test_db_only(self, load_test_db):
        """Verify that orders were created only in test DB, not production."""
        # Connect to production DB
        prod_engine = create_engine(
            "postgresql+psycopg://quickbite_user:quickbite_password@127.0.0.1:5434/quickbite_db",
            future=True,
        )
        prod_session = sessionmaker(bind=prod_engine)()

        # Connect to test DB
        test_session = load_test_db()

        try:
            prod_count = prod_session.query(Order).count()
            test_count = test_session.query(Order).count()

            # Production should have at most 1 order from earlier manual test
            # Test DB should have >= 100 orders
            assert test_count >= NUM_ORDERS, \
                f"Test DB should have >= {NUM_ORDERS} orders; got {test_count}"
            assert prod_count <= 2, \
                f"Production DB should be largely unaffected (has {prod_count}); test isolation failed"

            print(f"\n✓ Database isolation verified:")
            print(f"  Production DB (quickbite_db):  {prod_count} orders")
            print(f"  Test DB (quickbite_test_db):   {test_count} orders")
        finally:
            prod_session.close()
            test_session.close()
            prod_engine.dispose()


def _create_order(order_num: int) -> LoadTestResult:
    """Create a single order via POST /orders; return timing and result."""
    payload = {
        "customer_name": f"LoadTest Customer {order_num}",
        "customer_email": f"load-test-{order_num}@example.com",
        "customer_phone": f"555-{order_num:06d}",
        "delivery_address": f"{order_num} Load Test Street",
        "items": [
            {
                "name": f"Test Item {order_num}",
                "quantity": 1,
                "price": f"{10.00 + (order_num % 100):.2f}",
            }
        ],
        "total_amount": f"{10.00 + (order_num % 100):.2f}",
    }

    start = time.time()
    try:
        response = requests.post(
            f"{API_BASE_URL}/orders",
            json=payload,
            timeout=10,
        )
        latency_ms = (time.time() - start) * 1000

        if response.status_code == 201:
            data = response.json()
            return LoadTestResult(
                order_id=data.get("id"),
                latency_ms=latency_ms,
                status_code=response.status_code,
                success=True,
            )
        else:
            return LoadTestResult(
                order_id=None,
                latency_ms=latency_ms,
                status_code=response.status_code,
                success=False,
                error=f"HTTP {response.status_code}: {response.text[:100]}",
            )
    except Exception as e:
        latency_ms = (time.time() - start) * 1000
        return LoadTestResult(
            order_id=None,
            latency_ms=latency_ms,
            status_code=0,
            success=False,
            error=str(e)[:100],
        )


def _test_idempotency(results: list[LoadTestResult]) -> bool:
    """Test idempotency by retrying the first successful order.

    If idempotency_key works, the second request should return the same order.
    """
    if not results or not results[0].success or not results[0].order_id:
        return False

    first_order = results[0].order_id

    # Retry creating the same order (same payload, with idempotency_key)
    payload = {
        "customer_name": "LoadTest Customer 1",
        "customer_email": "load-test-1@example.com",
        "customer_phone": "555-000001",
        "delivery_address": "1 Load Test Street",
        "items": [{"name": "Test Item 1", "quantity": 1, "price": "10.00"}],
        "total_amount": "10.00",
        "idempotency_key": "load-test-idempotency-key-1",
    }

    try:
        # First request with idempotency key
        response1 = requests.post(
            f"{API_BASE_URL}/orders",
            json=payload,
            timeout=10,
        )
        if response1.status_code != 201:
            return False
        order1_id = response1.json().get("id")

        # Second request with same idempotency key
        response2 = requests.post(
            f"{API_BASE_URL}/orders",
            json=payload,
            timeout=10,
        )
        if response2.status_code != 201:
            return False
        order2_id = response2.json().get("id")

        # Both should return the same order ID
        return order1_id == order2_id
    except Exception:
        return False


def _save_results(summary: LoadTestSummary, results: list[LoadTestResult]) -> None:
    """Save detailed results to file for documentation."""
    timestamp = datetime.utcnow().isoformat()
    output_file = "docs/load_test_results.json"

    output = {
        "timestamp": timestamp,
        "test_type": "100-order creation benchmark",
        "api_url": API_BASE_URL,
        "database": DATABASE_URL.split("/")[-1],
        "environment": "isolated test DB (quickbite_test_db)",
        "summary": {
            "total_orders": summary.total_orders,
            "successful": summary.successful,
            "failed": summary.failed,
            "success_rate_percent": 100.0 * summary.successful / summary.total_orders,
            "throughput_orders_per_sec": summary.throughput_orders_per_sec,
            "latency_min_ms": summary.latency_min_ms,
            "latency_p50_ms": summary.latency_p50_ms,
            "latency_p95_ms": summary.latency_p95_ms,
            "latency_p99_ms": summary.latency_p99_ms,
            "latency_max_ms": summary.latency_max_ms,
            "latency_mean_ms": summary.latency_mean_ms,
            "idempotency_tested": summary.idempotency_tested,
            "idempotency_success": summary.idempotency_success,
        },
        "raw_results": [
            {
                "order_id": r.order_id,
                "latency_ms": r.latency_ms,
                "status_code": r.status_code,
                "success": r.success,
                "error": r.error,
            }
            for r in results
        ],
    }

    try:
        import os
        os.makedirs(os.path.dirname(output_file), exist_ok=True)
        with open(output_file, "w") as f:
            json.dump(output, f, indent=2)
        print(f"\n✓ Results saved to {output_file}")
    except Exception as e:
        print(f"\n✗ Failed to save results: {e}")
