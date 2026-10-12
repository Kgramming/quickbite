"""Deterministic failure injection for reliability testing.

Enabled ONLY through development/test environment variables — never in
production. Each worker reads its mode at event time (no restart needed).

Environment variables:
  QB_PAYMENT_FAILURE_MODE:      success | fail_twice_then_succeed |
                                always_fail | crash_after_charge
  QB_RESTAURANT_FAILURE_MODE:   success | always_fail
  QB_DELIVERY_FAILURE_MODE:     success | always_fail
  QB_NOTIFICATION_FAILURE_MODE: success | always_fail

Modes:
  success                 normal behavior (default)
  fail_twice_then_succeed first two attempts return transient failure,
                          third succeeds (payment only)
  always_fail             every attempt fails transiently; after the bounded
                          retries the message is quarantined and the order
                          gets its worker-specific terminal transition
  crash_after_charge      hard process crash via os._exit(1) after the
                          injection checkpoint (payment only; test-only)

The legacy 999.99 amount-based decline path in _charge_payment is kept for
dashboard demo compatibility; env-driven injection is the primary,
deterministic mechanism for rubric verification.
"""

import logging
import os

logger = logging.getLogger(__name__)

_ENV_VARS = {
    "payment": "QB_PAYMENT_FAILURE_MODE",
    "restaurant": "QB_RESTAURANT_FAILURE_MODE",
    "delivery": "QB_DELIVERY_FAILURE_MODE",
    "notification": "QB_NOTIFICATION_FAILURE_MODE",
}

_VALID_MODES = {
    "payment": {"success", "fail_twice_then_succeed", "always_fail",
                "crash_after_charge"},
    "restaurant": {"success", "always_fail"},
    "delivery": {"success", "always_fail"},
    "notification": {"success", "always_fail"},
}


def get_failure_mode(worker: str, order_id: str = "") -> str:
    """Return the configured failure-injection mode for a worker.

    Unknown workers or invalid values fall back to "success".
    """
    env_var = _ENV_VARS.get(worker)
    if not env_var:
        return "success"
    mode = os.environ.get(env_var, "success").strip().lower()
    if mode not in _VALID_MODES[worker]:
        logger.warning(f"Ignoring invalid {env_var}={mode!r}; using 'success'")
        return "success"
    if mode != "success":
        logger.warning(f"Failure injection ACTIVE: {worker}={mode} "
                       f"(order={order_id or 'n/a'})")
    return mode
