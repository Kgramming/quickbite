/// Integration verification test — checks API client and model contracts
/// without requiring a live backend.

import 'package:flutter_test/flutter_test.dart';
import 'package:quickbite/models/user.dart';
import 'package:quickbite/models/order.dart';
import 'package:quickbite/models/restaurant.dart';

void main() {
  group('API Contract Verification', () {
    test('AuthResponse model has required fields', () {
      final json = {
        'access_token': 'token123',
        'token_type': 'bearer',
        'expires_in': 86400,
        'user': {
          'id': 'user1',
          'email': 'test@example.com',
          'name': 'Test User',
          'role': 'customer',
        },
      };
      final response = AuthResponse.fromJson(json);
      expect(response.accessToken, 'token123');
      expect(response.user.email, 'test@example.com');
    });

    test('Order model has required fields and parses correctly', () {
      final json = {
        'id': 'order1',
        'restaurant_id': 'rest1',
        'status': 'PENDING',
        'currency': 'INR',
        'total_amount_minor': 50000,
        'version': 1,
        'failure_code': null,
        'driver': null,
        'items': [
          {
            'menu_item_id': 'item1',
            'name': 'Biryani',
            'quantity': 2,
            'price_minor': 25000,
          },
        ],
        'delivery_address': '123 Main St',
        'created_at': '2026-10-12T10:00:00Z',
        'updated_at': '2026-10-12T10:00:00Z',
      };
      final order = Order.fromJson(json);
      expect(order.id, 'order1');
      expect(order.currency, 'INR');
      expect(order.items, isNotEmpty);
      expect(order.items.first.priceMinor, 25000);
      expect(order.displayPrice, '₹500.00');
    });

    test('MenuItem model has price_minor field', () {
      final json = {
        'id': 'item1',
        'name': 'Chicken Biryani',
        'description': 'Fragrant biryani',
        'price_minor': 24999,
        'available': true,
      };
      final item = MenuItem.fromJson(json);
      expect(item.priceMinor, 24999);
      expect(item.price, '₹249.99');
    });

    test('Order status machine is correctly defined', () {
      expect(OrderStatus.pending.name, 'pending');
      expect(OrderStatus.paid.name, 'paid');
      expect(OrderStatus.confirmed.name, 'confirmed');
      expect(OrderStatus.driverAssigned.name, 'driverAssigned');
      expect(OrderStatus.paymentFailed.name, 'paymentFailed');
      expect(OrderStatus.failed.name, 'failed');
      expect(OrderStatus.cancelled.name, 'cancelled');
    });

    test('Order isTerminal identifies terminal states', () {
      final pendingOrder = Order(
        id: 'o1',
        restaurantId: 'r1',
        status: OrderStatus.pending,
        currency: 'INR',
        totalAmountMinor: 0,
        version: 1,
        items: [],
        deliveryAddress: '123 Main',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(pendingOrder.isTerminal, false);

      final cancelledOrder = Order(
        id: 'o2',
        restaurantId: 'r2',
        status: OrderStatus.cancelled,
        currency: 'INR',
        totalAmountMinor: 0,
        version: 1,
        items: [],
        deliveryAddress: '456 Oak',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(cancelledOrder.isTerminal, true);
    });

    test('Restaurant and MenuItem models parse correctly', () {
      final json = {
        'id': 'rest1',
        'name': 'Taj Mahal',
        'description': 'Indian cuisine',
        'delivery_fee_minor': 5000,
        'average_rating': 4.5,
      };
      final restaurant = Restaurant.fromJson(json);
      expect(restaurant.id, 'rest1');
      expect(restaurant.deliveryFee, '₹50.00');
    });

    test('PaginatedOrders model parses paginated response', () {
      final json = {
        'items': [],
        'page': 1,
        'page_size': 20,
        'total': 42,
      };
      final paginated = PaginatedOrders.fromJson(json);
      expect(paginated.page, 1);
      expect(paginated.pageSize, 20);
      expect(paginated.total, 42);
    });
  });
}

