import 'package:equatable/equatable.dart';

class Restaurant extends Equatable {
  final String id;
  final String name;
  final String description;
  final String cuisine;
  final double rating;
  final int deliveryTimeMinutes;
  final int deliveryFeeMinor;
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

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      cuisine: json['cuisine'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      deliveryTimeMinutes: json['delivery_time_minutes'] as int? ?? 0,
      deliveryFeeMinor: json['delivery_fee_minor'] as int? ?? 0,
      isOpen: json['is_open'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'cuisine': cuisine,
        'rating': rating,
        'delivery_time_minutes': deliveryTimeMinutes,
        'delivery_fee_minor': deliveryFeeMinor,
        'is_open': isOpen,
      };

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

class PaginatedRestaurants extends Equatable {
  final List<Restaurant> items;
  final int page;
  final int pageSize;
  final int total;

  const PaginatedRestaurants({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory PaginatedRestaurants.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List? ?? [];
    final restaurants = itemsList
        .map((item) => Restaurant.fromJson(item as Map<String, dynamic>))
        .toList();

    return PaginatedRestaurants(
      items: restaurants,
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

class MenuItem extends Equatable {
  final String id;
  final String name;
  final String description;
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

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      priceMinor: json['price_minor'] as int? ?? 0,
      available: json['available'] as bool? ?? false,
      image: json['image'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'price_minor': priceMinor,
        'available': available,
        'image': image,
      };

  String get price {
    final rupees = priceMinor ~/ 100;
    final paise = priceMinor % 100;
    return '₹${rupees}.${paise.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props =>
      [id, name, description, priceMinor, available, image];
}

class RestaurantMenu extends Equatable {
  final String restaurantId;
  final List<MenuItem> items;
  final int page;
  final int pageSize;
  final int total;

  const RestaurantMenu({
    required this.restaurantId,
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory RestaurantMenu.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List? ?? [];
    final menuItems = itemsList
        .map((item) => MenuItem.fromJson(item as Map<String, dynamic>))
        .toList();

    return RestaurantMenu(
      restaurantId: json['restaurant_id'] as String? ?? '',
      items: menuItems,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 50,
      total: json['total'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'restaurant_id': restaurantId,
        'items': items.map((item) => item.toJson()).toList(),
        'page': page,
        'page_size': pageSize,
        'total': total,
      };

  @override
  List<Object?> get props =>
      [restaurantId, items, page, pageSize, total];
}
