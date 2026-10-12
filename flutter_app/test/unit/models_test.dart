import 'package:flutter_test/flutter_test.dart';
import 'package:quickbite/models/order.dart';
import 'package:quickbite/models/restaurant.dart';
import 'package:quickbite/models/user.dart';

void main() {
  group('User Model Tests', () {
    test('User.fromJson creates user correctly', () {
      final json = {
        'id': 'user123',
        'email': 'test@example.com',
        'name': 'Test User',
        'role': 'customer',
      };

      final user = User.fromJson(json);

      expect(user.id, 'user123');
      expect(user.email, 'test@example.com');
      expect(user.name, 'Test User');
      expect(user.role, UserRole.customer);
    });

    test('User.toJson serializes correctly', () {
      const user = User(
        id: 'user123',
        email: 'test@example.com',
        name: 'Test User',
        role: UserRole.customer,
      );

      final json = user.toJson();

      expect(json['id'], 'user123');
      expect(json['email'], 'test@example.com');
      expect(json['name'], 'Test User');
    });
  });

  group('MenuItem Model Tests', () {
    test('MenuItem price formatting', () {
      const item = MenuItem(
        id: 'item1',
        name: 'Pizza',
        description: 'Cheese pizza',
        priceMinor: 29999, // ₹299.99
        available: true,
      );

      expect(item.price, '₹299.99');
    });

    test('MenuItem with zero cents', () {
      const item = MenuItem(
        id: 'item2',
        name: 'Drink',
        description: 'Cold drink',
        priceMinor: 10000, // ₹100.00
        available: true,
      );

      expect(item.price, '₹100.00');
    });
  });

  group('Order Model Tests', () {
    test('Order displayPrice formatting', () {
      final order = Order(
        id: 'order1',
        restaurantId: 'rest1',
        status: OrderStatus.pending,
        currency: 'INR',
        totalAmountMinor: 54997, // ₹549.97
        version: 1,
        items: [],
        deliveryAddress: '123 Main St',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(order.displayPrice, '₹549.97');
    });

    test('Order isTerminal correctly identifies terminal states', () {
      final pendingOrder = Order(
        id: 'order1',
        restaurantId: 'rest1',
        status: OrderStatus.pending,
        currency: 'INR',
        totalAmountMinor: 10000,
        version: 1,
        items: [],
        deliveryAddress: '123 Main St',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final failedOrder = Order(
        id: 'order2',
        restaurantId: 'rest1',
        status: OrderStatus.paymentFailed,
        currency: 'INR',
        totalAmountMinor: 10000,
        version: 1,
        items: [],
        deliveryAddress: '123 Main St',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(pendingOrder.isTerminal, false);
      expect(failedOrder.isTerminal, true);
    });
  });

  group('Restaurant Model Tests', () {
    test('Restaurant deliveryFee formatting', () {
      const restaurant = Restaurant(
        id: 'rest1',
        name: 'Test Restaurant',
        description: 'A test restaurant',
        cuisine: 'Italian',
        rating: 4.5,
        deliveryTimeMinutes: 30,
        deliveryFeeMinor: 5000, // ₹50.00
        isOpen: true,
      );

      expect(restaurant.deliveryFee, '₹50.00');
    });
  });
}
