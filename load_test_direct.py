#!/usr/bin/env python3

"""Direct 100-order load test with proper latency tracking.

Creates 100 orders via the API, records latencies, throughput, and idempotency.
Uses the production database (same as API); orders are real operations.

Run: python3 load_test_direct.py

Results saved to: docs/load_test_results.json
"""

import json
import time
import statistics
from datetime import datetime
from pathlib import Path

import requests


def main():
    API_URL = "http://127.0.0.1:8002"
    NUM_ORDERS = 100
    
    print("\n" + "=" * 60)
    print("QuickBite Load Test: 100 Orders")
    print("=" * 60)
    print(f"Timestamp: {datetime.utcnow().isoformat()}")
    print(f"API: {API_URL}")
    print(f"Database: quickbite_db (production)")
    print()
    
    # Check health
    try:
        health = requests.get(f"{API_URL}/health", timeout=5).json()
        if health.get("status") == "ok":
            print("✓ API is healthy\n")
        else:
            print("✗ API is degraded\n")
            return
    except Exception as e:
        print(f"✗ API is not responding: {e}\n")
        return
    
    # Create orders and track latencies
    latencies = []
    successful = 0
    failures = 0
    order_ids = []
    
    print(f"Creating {NUM_ORDERS} orders...\n")
    start_total = time.time()
    
    for i in range(1, NUM_ORDERS + 1):
        price = f"{10.00 + (i % 100):.2f}"
        payload = {
            "customer_name": f"LoadTest Customer {i}",
            "customer_email": f"load-test-direct-{i}@example.com",
            "customer_phone": f"555-{i:06d}",
            "delivery_address": f"{i} Load Test Street",
            "items": [
                {
                    "name": f"Test Item {i}",
                    "quantity": 1,
                    "price": price,
                }
            ],
            "total_amount": price,
        }
        
        try:
            start_req = time.time()
            response = requests.post(
                f"{API_URL}/orders",
                json=payload,
                timeout=10,
            )
            latency_ms = (time.time() - start_req) * 1000
            
            if response.status_code == 201:
                data = response.json()
                order_id = data.get("id")
                order_ids.append(order_id)
                latencies.append(latency_ms)
                successful += 1
                if i % 10 == 0:
                    print(f"  Order {i:3d}: {order_id} ({latency_ms:.1f}ms)")
            else:
                failures += 1
                print(f"  Order {i:3d}: FAILED (HTTP {response.status_code})")
        except Exception as e:
            failures += 1
            print(f"  Order {i:3d}: ERROR ({str(e)[:50]})")
    
    total_time = time.time() - start_total
    
    # Calculate statistics
    if latencies:
        sorted_lats = sorted(latencies)
        min_lat = min(sorted_lats)
        max_lat = max(sorted_lats)
        mean_lat = statistics.mean(sorted_lats)
        median_lat = statistics.median(sorted_lats)
        p95_lat = sorted_lats[int(len(sorted_lats) * 0.95)]
        p99_lat = sorted_lats[int(len(sorted_lats) * 0.99)]
    else:
        min_lat = max_lat = mean_lat = median_lat = p95_lat = p99_lat = 0
    
    throughput = successful / total_time if total_time > 0 else 0
    
    # Print results
    print()
    print("=" * 60)
    print("RESULTS")
    print("=" * 60)
    print()
    print("THROUGHPUT & SUCCESS")
    print(f"  Total Orders:    {NUM_ORDERS}")
    print(f"  Successful:      {successful}")
    print(f"  Failed:          {failures}")
    print(f"  Success Rate:    {100.0 * successful / NUM_ORDERS:.1f}%")
    print(f"  Total Time:      {total_time:.2f}s")
    print(f"  Throughput:      {throughput:.2f} orders/sec")
    print()
    print("LATENCY (Order Creation, ms)")
    print(f"  Min:             {min_lat:.1f}")
    print(f"  P50 (Median):    {median_lat:.1f}")
    print(f"  P95:             {p95_lat:.1f}")
    print(f"  P99:             {p99_lat:.1f}")
    print(f"  Max:             {max_lat:.1f}")
    print(f"  Mean:            {mean_lat:.2f}")
    print()
    print("=" * 60)
    
    # Test idempotency
    print("\nTesting idempotency...")
    idempotency_key = "load-test-idempotency-key-test"
    price = "15.99"
    payload = {
        "customer_name": "Idempotency Test",
        "customer_email": "idempotency-test@example.com",
        "customer_phone": "555-999999",
        "delivery_address": "Idempotency Test Street",
        "items": [{"name": "Test Item", "quantity": 1, "price": price}],
        "total_amount": price,
        "idempotency_key": idempotency_key,
    }
    
    try:
        resp1 = requests.post(f"{API_URL}/orders", json=payload, timeout=10)
        order1_id = resp1.json().get("id") if resp1.status_code == 201 else None
        
        resp2 = requests.post(f"{API_URL}/orders", json=payload, timeout=10)
        order2_id = resp2.json().get("id") if resp2.status_code == 201 else None
        
        if order1_id == order2_id:
            print(f"✓ Idempotency works: same order {order1_id} returned on retry")
            idempotency_ok = True
        else:
            print(f"✗ Idempotency failed: got different orders {order1_id} vs {order2_id}")
            idempotency_ok = False
    except Exception as e:
        print(f"✗ Idempotency test failed: {e}")
        idempotency_ok = False
    
    # Save JSON results
    results = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "test_type": "100-order creation benchmark (direct)",
        "api_url": API_URL,
        "database": "quickbite_db (production)",
        "environment": "Production database (same as API)",
        "note": "Load test creates real orders in the database",
        "summary": {
            "total_orders": NUM_ORDERS,
            "successful": successful,
            "failed": failures,
            "success_rate_percent": 100.0 * successful / NUM_ORDERS,
            "total_time_seconds": round(total_time, 2),
            "throughput_orders_per_sec": round(throughput, 2),
            "latency_min_ms": round(min_lat, 1),
            "latency_p50_ms": round(median_lat, 1),
            "latency_p95_ms": round(p95_lat, 1),
            "latency_p99_ms": round(p99_lat, 1),
            "latency_max_ms": round(max_lat, 1),
            "latency_mean_ms": round(mean_lat, 2),
            "idempotency_tested": True,
            "idempotency_success": idempotency_ok,
        },
        "sample_order_ids": order_ids[:5],  # First 5 for reference
    }
    
    output_file = Path("docs/load_test_results.json")
    output_file.parent.mkdir(exist_ok=True)
    with open(output_file, "w") as f:
        json.dump(results, f, indent=2)
    
    print(f"\n✓ Results saved to {output_file}")
    print()


if __name__ == "__main__":
    main()
