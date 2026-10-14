import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/restaurant.dart';
import '../services/api_client.dart';

final restaurantsProvider =
    FutureProvider.family<PaginatedRestaurants, int>((ref, page) async {
  final apiClient = ref.watch(authenticatedApiClientProvider);
  return apiClient.getRestaurants(page: page, pageSize: 20);
});

final restaurantMenuProvider = FutureProvider.family<RestaurantMenu, (String, int)>(
    (ref, params) async {
  final (restaurantId, page) = params;
  final apiClient = ref.watch(authenticatedApiClientProvider);
  return apiClient.getRestaurantMenu(restaurantId: restaurantId, page: page, pageSize: 50);
});

// Cart state management
class CartItem {
  final MenuItem menuItem;
  int quantity;

  CartItem({required this.menuItem, this.quantity = 1});

  int get totalPrice => menuItem.priceMinor * quantity;

  CartItem copyWith({MenuItem? menuItem, int? quantity}) {
    return CartItem(
      menuItem: menuItem ?? this.menuItem,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CartState {
  final String? restaurantId;
  final String? restaurantName;
  final List<CartItem> items;
  final bool isCheckingOut;
  final String? error;

  const CartState({
    this.restaurantId,
    this.restaurantName,
    this.items = const [],
    this.isCheckingOut = false,
    this.error,
  });

  int get totalAmount {
    return items.fold(0, (sum, item) => sum + item.totalPrice);
  }

  String get totalPrice {
    final rupees = totalAmount ~/ 100;
    final paise = totalAmount % 100;
    return '₹${rupees}.${paise.toString().padLeft(2, '0')}';
  }

  CartState copyWith({
    String? restaurantId,
    String? restaurantName,
    List<CartItem>? items,
    bool? isCheckingOut,
    String? error,
  }) {
    return CartState(
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      items: items ?? this.items,
      isCheckingOut: isCheckingOut ?? this.isCheckingOut,
      error: error ?? this.error,
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  void addItem(MenuItem menuItem, String restaurantId, {String? restaurantName}) {
    // Check if switching restaurants
    if (state.restaurantId != null && state.restaurantId != restaurantId) {
      // Clear cart when switching restaurants
      state = CartState(
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        items: [CartItem(menuItem: menuItem)],
      );
      return;
    }

    // Check if item already in cart
    final existingIndex =
        state.items.indexWhere((item) => item.menuItem.id == menuItem.id);

    if (existingIndex >= 0) {
      final updatedItems = [...state.items];
      updatedItems[existingIndex] = updatedItems[existingIndex].copyWith(
        quantity: updatedItems[existingIndex].quantity + 1,
      );
      state = state.copyWith(
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        items: updatedItems,
      );
    } else {
      state = state.copyWith(
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        items: [...state.items, CartItem(menuItem: menuItem)],
      );
    }
  }

  void removeItem(String menuItemId) {
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.menuItem.id != menuItemId) item,
      ],
    );
  }

  void updateQuantity(String menuItemId, int quantity) {
    if (quantity <= 0) {
      removeItem(menuItemId);
      return;
    }

    final updatedItems = state.items.map((item) {
      if (item.menuItem.id == menuItemId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);
  }

  void clearCart() {
    state = const CartState();
  }

  bool canCheckout() {
    return state.items.isNotEmpty && state.restaurantId != null;
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});

// Convenience providers
final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.items.length;
});

final cartTotalProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.totalAmount;
});
