import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/restaurant_provider.dart';
import '../widgets/food_image.dart';
import '../widgets/premium_widgets.dart';

/// Premium cart: editable quantities, swipe-to-remove, price breakdown.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your cart'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (cart.items.isNotEmpty)
            TextButton(
              onPressed: () => notifier.clearCart(),
              child: const Text('Clear'),
            ),
        ],
      ),
      body: cart.items.isEmpty
          ? EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Your cart is empty',
              message:
                  'Add something delicious from a restaurant near you.',
              actionLabel: 'Browse restaurants',
              onAction: () => context.go('/'),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppTheme.spaceMd),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppTheme.spaceSm),
                    itemBuilder: (context, i) {
                      final item = cart.items[i];
                      return Dismissible(
                        key: ValueKey(item.menuItem.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.danger,
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd),
                          ),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: Colors.white),
                        ),
                        onDismissed: (_) =>
                            notifier.removeItem(item.menuItem.id),
                        child: Container(
                          padding:
                              const EdgeInsets.all(AppTheme.spaceSm),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd),
                            boxShadow:
                                AppTheme.cardShadow(context),
                          ),
                          child: Row(
                            children: [
                              FoodImage(
                                width: 64,
                                height: 64,
                                imageUrl: item.menuItem.image,
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSm),
                                fallbackIcon:
                                    Icons.fastfood_rounded,
                              ),
                              const SizedBox(
                                  width: AppTheme.spaceMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.menuItem.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.menuItem.price,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppTheme.primary,
                                            fontWeight:
                                                FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              QuantityStepper(
                                quantity: item.quantity,
                                onIncrement: () =>
                                    notifier.updateQuantity(
                                  item.menuItem.id,
                                  item.quantity + 1,
                                ),
                                onDecrement: () =>
                                    notifier.updateQuantity(
                                  item.menuItem.id,
                                  item.quantity - 1,
                                ),
                                compact: true,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Price breakdown
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius:
                        const BorderRadius.vertical(
                      top: Radius.circular(AppTheme.radiusLg),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        _priceRow(context, 'Subtotal',
                            cart.totalPrice, false),
                        const SizedBox(height: 4),
                        _priceRow(
                            context,
                            'Delivery',
                            'Calculated at checkout',
                            false,
                            muted: true),
                        const Divider(height: 20),
                        _priceRow(context, 'Total',
                            cart.totalPrice, true),
                        const SizedBox(height: AppTheme.spaceMd),
                        PremiumButton(
                          label: 'Proceed to checkout',
                          icon: Icons
                              .arrow_forward_rounded,
                          onPressed: () =>
                              context.go('/checkout'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _priceRow(BuildContext context, String label, String value,
      bool isTotal, {bool muted = false}) {
    final style = isTotal
        ? Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(color: AppTheme.primary)
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: muted
                  ? Theme.of(context).textTheme.bodySmall?.color
                  : null,
            );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value,
            style: isTotal
                ? style
                : Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
