import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order.g.dart';

enum OrderStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('PAID')
  paid,
  @JsonValue('CONFIRMED')
  confirmed,
  @JsonValue('DRIVER_ASSIGNED')
  driverAssigned,
  @JsonValue('PAYMENT_FAILED')
  paymentFailed,
  @JsonValue('FAILED')
  failed,
  @JsonValue('CANCELLED')
  cancelled,
}

@JsonSerializable()
class OrderItem extends Equatable {
  @JsonKey(name: 'menu_item_id')
  final String menuItemId;

  final String name;
  final int quantity;

  @JsonKey(name: 'price_minor')
  final int priceminor;

  const OrderItem({
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.priceminor,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);

  Map<String, dynamic> toJson() => _$OrderItemToJson(this);

  @override
  List<Object?> get props => [menuItemId, name, quantity, priceminor];
}

@JsonSerializable()
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

  factory Driver.fromJson(Map<String, dynamic> json) => _$DriverFromJson(json);

  Map<String, dynamic> toJson() => _$DriverToJson(this);

  @override
  List<Object?> get props => [name, phone, latitude, longitude];
}

@JsonSerializable()
class Order extends Equatable {
  final String id;

  @JsonKey(name: 'restaurant_id')
  final String restaurantId;

  final OrderStatus status;
  final String currency;

  @JsonKey(name: 'total_amount_minor')
  final int totalAmountMinor;

  final int version;

  @JsonKey(name: 'failure_code')
  final String? failureCode;

  final Driver? driver;
  final List<OrderItem> items;

  @JsonKey(name: 'delivery_address')
  final String deliveryAddress;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'updated_at')
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

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);

  Map<String, dynamic> toJson() => _$OrderToJson(this);

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

@JsonSerializable()
class PaginatedOrders extends Equatable {
  final List<Order> items;
  final int page;

  @JsonKey(name: 'page_size')
  final int pageSize;

  final int total;

  const PaginatedOrders({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory PaginatedOrders.fromJson(Map<String, dynamic> json) =>
      _$PaginatedOrdersFromJson(json);

  Map<String, dynamic> toJson() => _$PaginatedOrdersToJson(this);

  @override
  List<Object?> get props => [items, page, pageSize, total];
}

@JsonSerializable()
class OrderNotification extends Equatable {
  final String id;

  @JsonKey(name: 'event_type')
  final String eventType;

  final String message;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const OrderNotification({
    required this.id,
    required this.eventType,
    required this.message,
    required this.createdAt,
  });

  factory OrderNotification.fromJson(Map<String, dynamic> json) =>
      _$OrderNotificationFromJson(json);

  Map<String, dynamic> toJson() => _$OrderNotificationToJson(this);

  @override
  List<Object?> get props => [id, eventType, message, createdAt];
}

@JsonSerializable()
class OrderStatusHistory extends Equatable {
  final String status;

  @JsonKey(name: 'changed_at')
  final DateTime changedAt;

  final String? message;

  const OrderStatusHistory({
    required this.status,
    required this.changedAt,
    this.message,
  });

  factory OrderStatusHistory.fromJson(Map<String, dynamic> json) =>
      _$OrderStatusHistoryFromJson(json);

  Map<String, dynamic> toJson() => _$OrderStatusHistoryToJson(this);

  @override
  List<Object?> get props => [status, changedAt, message];
}
