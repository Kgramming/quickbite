import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'restaurant.g.dart';

@JsonSerializable()
class Restaurant extends Equatable {
  final String id;
  final String name;
  final String description;
  final String cuisine;
  final double rating;

  @JsonKey(name: 'delivery_time_minutes')
  final int deliveryTimeMinutes;

  @JsonKey(name: 'delivery_fee_minor')
  final int deliveryFeeMinor;

  @JsonKey(name: 'is_open')
  final bool isOpen;

  const Restaurant({
    required this.id,
    required this.name,
    required this.description,
    required this.cuisine,
    required this.rating,
    required this.deliveryTimeMinutes,
    required this.deliveryFeeMinor,
    required this.isOpen,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) =>
      _$RestaurantFromJson(json);

  Map<String, dynamic> toJson() => _$RestaurantToJson(this);

  String get deliveryFee {
    final rupees = deliveryFeeMinor ~/ 100;
    final paise = deliveryFeeMinor % 100;
    return '₹${rupees}.${paise.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        cuisine,
        rating,
        deliveryTimeMinutes,
        deliveryFeeMinor,
        isOpen,
      ];
}

@JsonSerializable()
class PaginatedRestaurants extends Equatable {
  final List<Restaurant> items;
  final int page;

  @JsonKey(name: 'page_size')
  final int pageSize;

  final int total;

  const PaginatedRestaurants({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory PaginatedRestaurants.fromJson(Map<String, dynamic> json) =>
      _$PaginatedRestaurantsFromJson(json);

  Map<String, dynamic> toJson() => _$PaginatedRestaurantsToJson(this);

  @override
  List<Object?> get props => [items, page, pageSize, total];
}

@JsonSerializable()
class MenuItem extends Equatable {
  final String id;
  final String name;
  final String description;

  @JsonKey(name: 'price_minor')
  final int priceMinor;

  final bool available;
  final String? image;

  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.priceMinor,
    required this.available,
    this.image,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) =>
      _$MenuItemFromJson(json);

  Map<String, dynamic> toJson() => _$MenuItemToJson(this);

  String get price {
    final rupees = priceMinor ~/ 100;
    final paise = priceMinor % 100;
    return '₹${rupees}.${paise.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props =>
      [id, name, description, priceMinor, available, image];
}

@JsonSerializable()
class RestaurantMenu extends Equatable {
  @JsonKey(name: 'restaurant_id')
  final String restaurantId;

  final List<MenuItem> items;
  final int page;

  @JsonKey(name: 'page_size')
  final int pageSize;

  final int total;

  const RestaurantMenu({
    required this.restaurantId,
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory RestaurantMenu.fromJson(Map<String, dynamic> json) =>
      _$RestaurantMenuFromJson(json);

  Map<String, dynamic> toJson() => _$RestaurantMenuToJson(this);

  @override
  List<Object?> get props =>
      [restaurantId, items, page, pageSize, total];
}
