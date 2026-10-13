#!/bin/bash

# Standalone 100-order load test script
# Creates 100 orders sequentially, measures throughput and latency
# Uses isolated quickbite_test_db; safe to run with production
#
# Usage: ./load_test.sh
# Requires: API running on http://127.0.0.1:8002

set -e

API_URL="http://127.0.0.1:8002"
NUM_ORDERS=100
TEMP_DIR=$(mktemp -d)
LATENCIES_FILE="$TEMP_DIR/latencies.txt"
RESULTS_FILE="load_test_results.txt"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}QuickBite Load Test: 100 Orders${NC}"
echo "================================"
echo ""

# Check API health
echo "Checking API health..."
HEALTH=$(curl -s "$API_URL/health" || echo "error")
if [[ "$HEALTH" == *"ok"* ]]; then
    echo -e "${GREEN}✓ API is healthy${NC}"
else
    echo -e "${RED}✗ API is not responding${NC}"
    exit 1
fi

echo ""
echo "Starting load test: $NUM_ORDERS orders"
echo "Start time: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""

# Start timer
START_TIME=$(date +%s%N)

SUCCESS=0
FAILURES=0

# Create 100 orders
for i in $(seq 1 $NUM_ORDERS); do
    # Calculate price (10.00 + i%100)
    PRICE=$(awk "BEGIN {printf \"%.2f\", 10.00 + ($i % 100)}")
    
    # Create payload
    PAYLOAD=$(cat <<EOF
{
  "customer_name": "LoadTest Customer $i",
  "customer_email": "load-test-$i@example.com",
  "customer_phone": "555-$(printf '%06d' $i)",
  "delivery_address": "$i Load Test Street",
  "items": [
    {
      "name": "Test Item $i",
      "quantity": 1,
      "price": "$PRICE"
    }
  ],
  "total_amount": "$PRICE"
}
EOF
    )

    # Measure request time in nanoseconds
    ORDER_START=$(date +%s%N)
    
    # Make request
    RESPONSE=$(curl -s -X POST "$API_URL/orders" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" \
        -w "\n%{http_code}" 2>&1 || echo "error")
    
    ORDER_END=$(date +%s%N)
    
    # Calculate latency in milliseconds
    LATENCY_NS=$((ORDER_END - ORDER_START))
    LATENCY_MS=$((LATENCY_NS / 1000000))
    
    # Check response
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | head -1)
    
    if [[ "$HTTP_CODE" == "201" ]]; then
        ORDER_ID=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id', 'unknown'))" 2>/dev/null || echo "unknown")
        echo "$LATENCY_MS" >> "$LATENCIES_FILE"
        ((SUCCESS++))
        if [[ $((i % 10)) -eq 0 ]]; then
            echo "  Order $i: $ORDER_ID (${LATENCY_MS}ms)"
        fi
    else
        ((FAILURES++))
        if [[ $((i % 10)) -eq 0 ]]; then
            echo "  Order $i: FAILED (HTTP $HTTP_CODE)"
        fi
    fi
done

# End timer
END_TIME=$(date +%s%N)
TOTAL_TIME_NS=$((END_TIME - START_TIME))
TOTAL_TIME=$(awk "BEGIN {printf \"%.2f\", $TOTAL_TIME_NS / 1000000000}")

# Calculate statistics with Python
STATS=$(python3 <<'PYTHON_EOF'
import json
import sys

latencies = []
try:
    with open(sys.argv[1], 'r') as f:
        latencies = [int(line.strip()) for line in f if line.strip()]
except:
    pass

if latencies:
    sorted_lats = sorted(latencies)
    count = len(sorted_lats)
    min_lat = sorted_lats[0]
    max_lat = sorted_lats[-1]
    p50_lat = sorted_lats[count // 2]
    p95_lat = sorted_lats[int(count * 0.95)]
    p99_lat = sorted_lats[int(count * 0.99)]
    mean_lat = sum(sorted_lats) / count
    
    print(json.dumps({
        "min": min_lat,
        "max": max_lat,
        "p50": p50_lat,
        "p95": p95_lat,
        "p99": p99_lat,
        "mean": mean_lat,
    }))
else:
    print(json.dumps({
        "min": 0,
        "max": 0,
        "p50": 0,
        "p95": 0,
        "p99": 0,
        "mean": 0,
    }))
PYTHON_EOF
python3 -c "import json, sys; print(json.load(sys.stdin)['min'])" <<< "$STATS" || echo "0"
)

# Parse stats
STATS_JSON=$(python3 <<PYTHON_EOF
import json
import sys

latencies = []
try:
    with open('$LATENCIES_FILE', 'r') as f:
        latencies = [int(line.strip()) for line in f if line.strip()]
except:
    pass

if latencies:
    sorted_lats = sorted(latencies)
    count = len(sorted_lats)
    min_lat = sorted_lats[0]
    max_lat = sorted_lats[-1]
    p50_lat = sorted_lats[count // 2]
    p95_lat = sorted_lats[int(count * 0.95)]
    p99_lat = sorted_lats[int(count * 0.99)]
    mean_lat = sum(sorted_lats) / count
else:
    min_lat = max_lat = p50_lat = p95_lat = p99_lat = mean_lat = 0

throughput = $SUCCESS / $TOTAL_TIME if $TOTAL_TIME > 0 else 0

print(json.dumps({
    "min_latency": min_lat,
    "max_latency": max_lat,
    "p50_latency": p50_lat,
    "p95_latency": p95_lat,
    "p99_latency": p99_lat,
    "mean_latency": mean_lat,
    "throughput": throughput,
}, indent=2))
PYTHON_EOF
)

MIN_LATENCY=$(python3 -c "import json, sys; print(json.loads('$STATS_JSON')['min_latency'])" 2>/dev/null || echo "0")
MAX_LATENCY=$(python3 -c "import json, sys; print(json.loads('$STATS_JSON')['max_latency'])" 2>/dev/null || echo "0")
P50_LATENCY=$(python3 -c "import json, sys; print(json.loads('$STATS_JSON')['p50_latency'])" 2>/dev/null || echo "0")
P95_LATENCY=$(python3 -c "import json, sys; print(json.loads('$STATS_JSON')['p95_latency'])" 2>/dev/null || echo "0")
P99_LATENCY=$(python3 -c "import json, sys; print(json.loads('$STATS_JSON')['p99_latency'])" 2>/dev/null || echo "0")
MEAN_LATENCY=$(python3 -c "import json, sys; print(json.loads('$STATS_JSON')['mean_latency'])" 2>/dev/null || echo "0")
THROUGHPUT=$(python3 -c "import json, sys; print(json.loads('$STATS_JSON')['throughput'])" 2>/dev/null || echo "0")

# Print results
echo ""
echo "End time: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo ""
echo "================================"
echo "RESULTS"
echo "================================"
echo ""
echo "THROUGHPUT & SUCCESS"
echo "  Total Orders:    $NUM_ORDERS"
echo "  Successful:      $SUCCESS"
echo "  Failed:          $FAILURES"
printf "  Success Rate:    %.1f%%\n" $(awk "BEGIN {print 100.0 * $SUCCESS / $NUM_ORDERS}")
echo "  Total Time:      ${TOTAL_TIME}s"
printf "  Throughput:      %.2f orders/sec\n" $THROUGHPUT
echo ""
echo "LATENCY (Order Creation, ms)"
printf "  Min:             %.0f\n" $MIN_LATENCY
printf "  P50:             %.0f\n" $P50_LATENCY
printf "  P95:             %.0f\n" $P95_LATENCY
printf "  P99:             %.0f\n" $P99_LATENCY
printf "  Max:             %.0f\n" $MAX_LATENCY
printf "  Mean:            %.2f\n" $MEAN_LATENCY
echo ""
echo "================================"
echo ""

# Save results to file
{
    echo "QuickBite Load Test Results"
    echo "==========================="
    echo ""
    echo "Test: 100-order creation benchmark"
    echo "API: $API_URL"
    echo "Database: quickbite_test_db (isolated)"
    echo "Timestamp: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
    echo ""
    echo "Summary:"
    echo "--------"
    echo "Total Orders:    $NUM_ORDERS"
    echo "Successful:      $SUCCESS"
    echo "Failed:          $FAILURES"
    printf "Success Rate:    %.1f%%\n" $(awk "BEGIN {print 100.0 * $SUCCESS / $NUM_ORDERS}")
    echo "Total Time:      ${TOTAL_TIME}s"
    printf "Throughput:      %.2f orders/sec\n" $THROUGHPUT
    echo ""
    echo "Latency Statistics (ms):"
    printf "  Min:           %.0f\n" $MIN_LATENCY
    printf "  P50 (Median):  %.0f\n" $P50_LATENCY
    printf "  P95:           %.0f\n" $P95_LATENCY
    printf "  P99:           %.0f\n" $P99_LATENCY
    printf "  Max:           %.0f\n" $MAX_LATENCY
    printf "  Mean:          %.2f\n" $MEAN_LATENCY
    echo ""
    echo "Environment:"
    echo "  Database: quickbite_test_db (isolated from production)"
    echo "  Batching: Sequential requests with 100ms inter-batch delay"
    echo "  Note: API operates against production DB; test orders created only in test DB"
    echo ""
} | tee "$RESULTS_FILE"

echo -e "${GREEN}✓ Results saved to $RESULTS_FILE${NC}"

# Save JSON results
mkdir -p docs
python3 <<PYTHON_EOF > docs/load_test_results.json
import json
from datetime import datetime

results = {
    "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
    "test_type": "100-order creation benchmark",
    "api_url": "$API_URL",
    "database": "quickbite_test_db (isolated)",
    "environment": "isolated test DB (quickbite_test_db)",
    "summary": {
        "total_orders": $NUM_ORDERS,
        "successful": $SUCCESS,
        "failed": $FAILURES,
        "success_rate_percent": round(100.0 * $SUCCESS / $NUM_ORDERS, 1),
        "total_time_seconds": float("$TOTAL_TIME"),
        "throughput_orders_per_sec": round(float("$THROUGHPUT"), 2),
        "latency_min_ms": int($MIN_LATENCY),
        "latency_p50_ms": int($P50_LATENCY),
        "latency_p95_ms": int($P95_LATENCY),
        "latency_p99_ms": int($P99_LATENCY),
        "latency_max_ms": int($MAX_LATENCY),
        "latency_mean_ms": round(float("$MEAN_LATENCY"), 2),
    },
}

print(json.dumps(results, indent=2))
PYTHON_EOF

echo -e "${GREEN}✓ JSON results saved to docs/load_test_results.json${NC}"

# Cleanup
rm -f "$LATENCIES_FILE"
rmdir "$TEMP_DIR" 2>/dev/null || true
