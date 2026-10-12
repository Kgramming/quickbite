# QuickBite — Requirements Checklist

Assignment requirement → implementation → verification. All file:line
references are against the fixed tree.

## Order flow

| Requirement | Implementation | Verification |
|---|---|---|
| Customer submits `POST /orders` | `app/routes.py` — `create_order` | `tests/test_routes.py`, `tests/test_integration.py::TestOrderFlow::test_create_order` |
| Validate + persist with `PENDING` status | Pydantic `CreateOrderRequest` (`app/schemas.py`); single-transaction `Order` + `OutboxEvent` insert (`app/routes.py`) | `test_create_order`, `test_order_and_outbox_atomic_transaction` |
| Publish `order.created`, respond promptly | Outbox relay `app/outbox_publisher.py` (poll 2s, confirms) | `tests/test_integration_live.py::TestLiveOutboxAndPayment` (live) |
| Payment worker → `order.paid` / `order.payment.failed` | `app/workers/payment.py` | `test_payment_success_flow`, `test_payment_failure_flow`, PG verification |
| Restaurant worker consumes `order.paid` → `order.confirmed` | `app/workers/restaurant.py` | `test_restaurant_confirmation`, PG verification |
| Delivery worker consumes `order.confirmed` → `order.driver.assigned` | `app/workers/delivery.py` | `test_delivery_assignment`, PG verification |
| Notification worker consumes relevant events independently | `app/workers/notification.py` (own queue, no pipeline publishes) | `test_integration.py` notification tests; downtime demo in `demo.sh` |

## Endpoints

| Requirement | Implementation | Verification |
|---|---|---|
| `POST /orders` | `app/routes.py` | route + integration tests |
| `GET /orders/{order_id}` | `app/routes.py` | `test_get_order_*` |
| `GET /health` | `app/routes.py` — DB ping + AMQP handshake, `ok`/`degraded` | `test_health_check`, `test_health_check_all_healthy` |

## RabbitMQ

| Requirement | Implementation | Verification |
|---|---|---|
| Durable topic exchange `quickbite.orders` | `app/rabbitmq.py::RabbitMQManager.connect` | `TestTopologyDeclaration`, live `test_exchange_and_queues_exist` |
| Queues: `payment.queue`, `restaurant.queue`, `delivery.queue`, `notification.queue`, `orders.dead-letter.queue` | `app/events.py::QUEUE_CONFIG`, `declare_application_topology` | topology unit tests, live tests |
| Routing keys `order.created`, `order.paid`, `order.payment.failed`, `order.confirmed`, `order.driver.assigned` | `app/events.py::EVENT_ROUTING_KEYS` | `TestRoutingKeyContract` |

## Reliability

| Requirement | Implementation | Verification |
|---|---|---|
| Durable queues + persistent messages | `durable=True`, `delivery_mode=PERSISTENT` | `TestTopologyDeclaration`, `test_republish_for_retry_*` |
| Manual acknowledgements | `app/worker_common.py::settle_message` (no `message.process()`) | `TestSettleMessage` (5 tests) |
| Bounded retries | `x-retry-count` header, max 3, 5s/10s/20s TTL (`app/retry.py`) | `TestRetryPolicy`, live retry-exhaustion test |
| Dead-letter queue | `dlx.quickbite.orders` + per-queue `x-dead-letter-exchange` | topology tests, live `test_poison_message_reaches_dlq` |
| Idempotent processing | atomic `claim_event()` (`app/idempotency.py`) | `TestAtomicIdempotency`, PG 8-thread race, duplicate-event tests |
| Prefetch control | `set_qos(prefetch_count=1)` per worker channel | `TestConnectContract` |
| Multiple worker instances | per-worker channels; `docker compose up --scale worker=3` | atomic claim design; demo in `demo.sh` (live) |
| Safe status transitions | state guards in each worker (`PENDING`→`PAID`→`CONFIRMED`→`DRIVER_ASSIGNED`); `FAILED` never overwrites terminal | integration tests, `test_mark_order_failed_never_overwrites_terminal` |
| Useful health checks | DB + RabbitMQ with documented scope | `test_health_check*` |

## Deliverables

| Requirement | Location |
|---|---|
| Working source repository | `app/`, `tests/` |
| Docker Compose configuration | `docker-compose.yml` (postgres, rabbitmq, api, publisher, worker) |
| README and setup instructions | `README.md` |
| Example API requests | `demo.sh`, `README.md` |
| Architecture diagram | `ARCHITECTURE.md` |
| Short technical report | `TECHNICAL_REPORT.md` |
| Demonstration script / checklist | `demo.sh`, `docs/TESTING.md` |
