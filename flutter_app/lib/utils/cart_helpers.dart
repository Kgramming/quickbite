import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/restaurant_provider.dart';

/// Ensures the cart holds items from at most one restaurant.
///
/// Returns true when the caller may add an item from [restaurantId]:
/// - cart is empty or already belongs to [restaurantId] -> true immediately
/// - otherwise asks the user; "Start new order" clears the cart and
///   returns true, "Keep cart" returns false.
Future<bool> ensureSingleRestaurantCart(
  BuildContext context,
  WidgetRef ref,
  String restaurantId, {
  String? restaurantName,
}) async {
  final cart = ref.read(cartProvider);
  final switching = cart.items.isNotEmpty &&
      cart.restaurantId != null &&
      cart.restaurantId != restaurantId;
  if (!switching) return true;

  final cartName = cart.restaurantName ?? 'another restaurant';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Start a new order?'),
      content: Text(
        'Your cart has items from $cartName. '
        'QuickBite allows one restaurant per order — '
        'adding this dish will clear your current cart.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Keep cart'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Start new order'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    ref.read(cartProvider.notifier).clearCart();
    return true;
  }
  return false;
}
