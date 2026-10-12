"""Bounded retry policy for worker message processing.

Strategy (no broker plugins required):
  - Each message carries an ``x-retry-count`` header (default 0).
  - On transient failure with count < MAX_RETRIES, the worker publishes
    a delayed-retry copy **targeted at the originating queue only**
    (via the default exchange with the queue name as routing key),
    with a per-message TTL (2s / 10s / 30s backoff), then acks the original.
    ``orders.retry.queue`` dead-letters expired messages to the default
    exchange, so they are redelivered **only** to the failing consumer's
    queue — never re-fanned-out to unrelated subscribers.
  - When retries are exhausted (or the failure is non-retryable), the
    worker rejects with requeue=False; the queue's
    ``x-dead-letter-exchange`` routes the message to
    ``orders.dead-letter.queue`` and the order is marked terminal.
"""

import logging
from datetime import timedelta

import aio_pika

logger = logging.getLogger(__name__)

MAX_RETRIES = 3
RETRY_DELAYS_SECONDS = [2.0, 10.0, 30.0]
RETRY_COUNT_HEADER = "x-retry-count"


class NonRetryableError(Exception):
    """Raised when a message can never succeed (poison message).

    The worker must reject it straight to the dead-letter queue instead
    of burning retries.
    """


def get_retry_count(message: aio_pika.IncomingMessage) -> int:
    """Read the retry attempt count from message headers (0 if absent)."""
    try:
        return int((message.headers or {}).get(RETRY_COUNT_HEADER, 0))
    except (TypeError, ValueError):
        return 0


def next_retry_delay_seconds(retry_count: int) -> float:
    """Backoff delay for the *next* attempt, given attempts already made."""
    idx = min(max(retry_count, 0), len(RETRY_DELAYS_SECONDS) - 1)
    return RETRY_DELAYS_SECONDS[idx]


async def republish_for_retry(
    retry_exchange: aio_pika.Exchange,
    message: aio_pika.IncomingMessage,
    target_queue: str,
) -> int:
    """Publish a delayed-retry copy targeted at one queue.

    The retry copy is published with ``target_queue`` (the originating
    consumer's queue name) as the routing key. After its TTL expires,
    ``orders.retry.queue`` dead-letters it to the **default exchange**,
    so it lands only in ``target_queue`` — never re-fanned-out through
    the domain exchange to unrelated subscribers.

    Publisher confirms: this coroutine only returns after the broker
    confirms receipt. Callers must ack the original message only after
    this returns.

    Returns:
        The new retry count carried by the retry copy.
    """
    count = get_retry_count(message)
    delay = next_retry_delay_seconds(count)
    headers = dict(message.headers or {})
    headers[RETRY_COUNT_HEADER] = count + 1

    retry_message = aio_pika.Message(
        body=message.body,
        headers=headers,
        content_type="application/json",
        delivery_mode=aio_pika.DeliveryMode.PERSISTENT,
        message_id=message.message_id,
        expiration=timedelta(seconds=delay),
    )
    await retry_exchange.publish(retry_message, routing_key=target_queue)
    logger.info(
        f"Scheduled retry {count + 1}/{MAX_RETRIES} in {delay:.0f}s "
        f"(target_queue={target_queue})"
    )
    return count + 1
