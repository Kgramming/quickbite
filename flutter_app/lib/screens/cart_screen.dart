import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/food_images.dart';
import '../providers/restaurant_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/food_image.dart';
import '../widgets/qb_widgets.dart';

/// Cart screen: editable quantities, honest price breakdown in INR.
///
/// Pricing comes from the cart state (menu `priceMinor` values). Delivery
/// fee and taxes are shown only when the backend provides them — never
/// invented.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
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
          ? QbEmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Your cart is empty',
              message:
                  'Add something delicious from a restaurant near you.',
              actionLabel: 'Browse restaurants',
              onAction: () => context.go('/'),
            )
          : Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: cart.items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final item = cart.items[i];
                          return QbCard(
                            child: Row(
                              children: [
                                FoodImage(
                                  imageUrl:
                                      QuickBiteImages.forMenuItem(
                                    itemName:
                                        item.menuItem.name,
                                    backendImageUrl:
                                        item.menuItem.image,
                                  ),
                                  width: 72,
                                  height: 72,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Row(
                                        children: [
                                          VegBadge(
                                              isVeg: inferVeg(item
                                                  .menuItem
                                                  .name)),
                                          const SizedBox(
                                              width: 6),
                                          Expanded(
                                            child: Text(
                                                item.menuItem
                                                    .name,
                                                style: Theme.of(
                                                        context)
                                                    .textTheme
                                                    .titleMedium,
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow
                                                        .ellipsis),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                          formatInr(item.menuItem
                                              .priceMinor),
                                          style: Theme.of(
                                                  context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                  fontWeight:
                                                      FontWeight
                                                          .w700)),
                                    ],
                                  ),
                                ),
                                QbStepper(
                                  quantity: item.quantity,
                                  onAdd: () =>
                                      notifier.updateQuantity(
                                          item.menuItem.id,
                                          item.quantity + 1),
                                  onRemove: () =>
                                      notifier.updateQuantity(
                                          item.menuItem.id,
                                          item.quantity - 1),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Bill summary
                    Container(
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        border: Border(
                            top: BorderSide(
                                color: tokens.border)),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding:
                              const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _BillRow(
                                  label: 'Subtotal',
                                  value: formatInr(
                                      cart.totalAmount)),
                              const SizedBox(height: 6),
                              _BillRow(
                                label: 'Delivery fee',
                                // Backend does not provide a per-order
                                // delivery fee; show as calculated at
                                // checkout, not here.
                                value:
                                    'Calculated at checkout',
                                isMuted: true,
                              ),
                              const Divider(height: 20),
                              _BillRow(
                                label: 'To pay',
                                value: formatInr(
                                    cart.totalAmount),
                                isTotal: true,
                              ),
                              const SizedBox(height: 16),
                              QbPrimaryButton(
                                label:
                                    'Proceed to checkout',
                                icon: Icons
                                    .arrow_forward_rounded,
                                onPressed: () =>
                                    context.go('/checkout'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;
  final bool isMuted;

  const _BillRow({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.isMuted = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = isTotal
        ? Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w800)
        : Theme.of(context).textTheme.bodyMedium;
    return Row(
      children: [
        Text(label,
            style: isMuted
                ? Theme.of(context).textTheme.bodySmall
                : style),
        const SizedBox(width: 12),
        Expanded(
          child: Text(value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: isMuted
                  ? Theme.of(context).textTheme.bodySmall
                  : style?.copyWith(
                      fontWeight: isTotal
                          ? FontWeight.w800
                          : FontWeight.w600)),
        ),
      ],
    );
  }
}
