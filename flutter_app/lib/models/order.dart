import 'package:equatable/equatable.dart';

enum OrderStatus {
  pending,
  paid,
  confirmed,
  driverAssigned,
  paymentFailed,
  failed,
  cancelled,
}

OrderStatus _parseOrderStatus(String? status) {
  switch (status?.toUpperCase()) {
    case 'PENDING':
      return OrderStatus.pending;
    case 'PAID':
      return OrderStatus.paid;
    case 'CONFIRMED':
      return OrderStatus.confirmed;
    case 'DRIVER_ASSIGNED':
      return OrderStatus.driverAssigned;
    case 'PAYMENT_FAILED':
      return OrderStatus.paymentFailed;
    case 'FAILED':
      return OrderStatus.failed;
    case 'CANCELLED':
      return OrderStatus.cancelled;
    default:
      return OrderStatus.pending;
  }
}

String _orderStatusToString(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return 'PENDING';
    case OrderStatus.paid:
      return 'PAID';
    case OrderStatus.confirmed:
      return 'CONFIRMED';
    case OrderStatus.driverAssigned:
      return 'DRIVER_ASSIGNED';
    case OrderStatus.paymentFailed:
      return 'PAYMENT_FAILED';
    case OrderStatus.failed:
      return 'FAILED';
    case OrderStatus.cancelled:
      return 'CANCELLED';
  }
}

class OrderItem extends Equatable {
  final String menuItemId;
  final String name;
  final int quantity;
  final int priceMinor;

  const OrderItem({
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.priceMinor,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      menuItemId: json['menu_item_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      priceMinor: json['price_minor'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'menu_item_id': menuItemId,
        'name': name,
        'quantity': quantity,
        'price_minor': priceMinor,
      };

  @override
  List<Object?> get props => [menuItemId, name, quantity, priceMinor];
}

class Driver extends Equatable {
  final String name;
  final String? phone;
  final double? latitude;
  final double? longitude;

  const Driver({
    required this.name,
    this.phone,
    this.latitude,
    this.longitude,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'latitude': latitude,
        'longitude': longitude,
      };

  @override
  List<Object?> get props => [name, phone, latitude, longitude];
}

class Order extends Equatable {
  final String id;
  final String restaurantId;
  final OrderStatus status;
  final String currency;
  final int totalAmountMinor;
  final int version;
  final String? failureCode;
  final Driver? driver;
  final List<OrderItem> items;
  final String deliveryAddress;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Order({
    required this.id,
    required this.restaurantId,
    required this.status,
    required this.currency,
    required this.totalAmountMinor,
    required this.version,
    this.failureCode,
    this.driver,
    required this.items,
    required this.deliveryAddress,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List? ?? [];
    final items = itemsList
        .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
        .toList();

    return Order(
      id: json['id'] as String? ?? '',
      restaurantId: json['restaurant_id'] as String? ?? '',
      status: _parseOrderStatus(json['status'] as String?),
      currency: json['currency'] as String? ?? 'INR',
      totalAmountMinor: json['total_amount_minor'] as int? ?? 0,
      version: json['version'] as int? ?? 1,
      failureCode: json['failure_code'] as String?,
      driver: json['driver'] != null
          ? Driver.fromJson(json['driver'] as Map<String, dynamic>)
          : null,
      items: items,
      deliveryAddress: json['delivery_address'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'restaurant_id': restaurantId,
        'status': _orderStatusToString(status),
        'currency': currency,
        'total_amount_minor': totalAmountMinor,
        'version': version,
        'failure_code': failureCode,
        'driver': driver?.toJson(),
        'items': items.map((item) => item.toJson()).toList(),
        'delivery_address': deliveryAddress,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  bool get isTerminal =>
      status == OrderStatus.paymentFailed ||
      status == OrderStatus.failed ||
      status == OrderStatus.cancelled;

  String get displayPrice {
    final rupees = totalAmountMinor ~/ 100;
    final paise = totalAmountMinor % 100;
    return '₹${rupees}.${paise.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [
        id,
        restaurantId,
        status,
        currency,
        totalAmountMinor,
        version,
        failureCode,
        driver,
        items,
        deliveryAddress,
        createdAt,
        updatedAt,
      ];
}

class PaginatedOrders extends Equatable {
  final List<Order> items;
  final int page;
  final int pageSize;
  final int total;

  const PaginatedOrders({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory PaginatedOrders.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List? ?? [];
    final orders = itemsList
        .map((item) => Order.fromJson(item as Map<String, dynamic>))
        .toList();

    return PaginatedOrders(
      items: orders,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      total: json['total'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((item) => item.toJson()).toList(),
        'page': page,
        'page_size': pageSize,
        'total': total,
      };

  @override
  List<Object?> get props => [items, page, pageSize, total];
}

class OrderNotification extends Equatable {
  final String id;
  final String eventType;
  final String message;
  final DateTime createdAt;

  const OrderNotification({
    required this.id,
    required this.eventType,
    required this.message,
    required this.createdAt,
  });

  factory OrderNotification.fromJson(Map<String, dynamic> json) {
    return OrderNotification(
      id: json['id'] as String? ?? '',
      eventType: json['event_type'] as String? ?? '',
      message: json['message'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'event_type': eventType,
        'message': message,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, eventType, message, createdAt];
}

class OrderStatusHistory extends Equatable {
  final String status;
  final DateTime changedAt;
  final String? message;

  const OrderStatusHistory({
    required this.status,
    required this.changedAt,
    this.message,
  });

  factory OrderStatusHistory.fromJson(Map<String, dynamic> json) {
    return OrderStatusHistory(
      status: json['status'] as String? ?? '',
      changedAt: DateTime.tryParse(json['changed_at'] as String? ?? '') ??
          DateTime.now(),
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'changed_at': changedAt.toIso8601String(),
        'message': message,
      };

  @override
  List<Object?> get props => [status, changedAt, message];
}
