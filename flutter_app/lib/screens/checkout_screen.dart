import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/restaurant_provider.dart';
import '../providers/order_provider.dart';
import '../widgets/premium_widgets.dart';

/// Premium checkout: address form, order summary, server-calculated total.
/// Idempotency-Key behavior preserved via checkoutProvider.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  late TextEditingController _addressController;
  String? _addressError;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    setState(() => _addressError = null);
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      setState(
          () => _addressError = 'Please enter your delivery address');
      return;
    }
    if (address.length < 10) {
      setState(() => _addressError =
          'Address looks too short — please add street and landmark');
      return;
    }

    final cart = ref.read(cartProvider);
    if (cart.restaurantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Restaurant not selected. Please go back.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    try {
      final orderId =
          await ref.read(checkoutProvider.notifier).createOrder(
                restaurantId: cart.restaurantId!,
                deliveryAddress: address,
                items: cart.items
                    .map((item) => {
                          'menu_item_id': item.menuItem.id,
                          'quantity': item.quantity,
                        })
                    .toList(),
              );
      ref.read(cartProvider.notifier).clearCart();
      if (mounted) context.go('/order/$orderId/confirmation');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final checkout = ref.watch(checkoutProvider);

    // Guard: empty cart shouldn't be here
    if (cart.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: EmptyState(
          icon: Icons.shopping_bag_outlined,
          title: 'Nothing to check out',
          message: 'Your cart is empty.',
          actionLabel: 'Browse restaurants',
          onAction: () => context.go('/'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order summary card
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMd),
                boxShadow: AppTheme.cardShadow(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded,
                          size: 20, color: AppTheme.primary),
                      const SizedBox(width: AppTheme.spaceSm),
                      Text('Order summary',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  for (final item in cart.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 5),
                      child: Row(
                        children: [
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primary
                                  .withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(6),
                            ),
                            child: Text(
                              '×${item.quantity}',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(
                              width: AppTheme.spaceSm),
                          Expanded(
                            child: Text(
                              item.menuItem.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _lineTotal(item.menuItem.priceMinor,
                                item.quantity),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium,
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subtotal',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium),
                      Text(cart.totalPrice,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                  color: AppTheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Final total is calculated by the server on order placement.',
                    style:
                        Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            // Delivery address card
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMd),
                boxShadow: AppTheme.cardShadow(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 20, color: AppTheme.primary),
                      const SizedBox(width: AppTheme.spaceSm),
                      Text('Delivery address',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  TextField(
                    controller: _addressController,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText:
                          'Flat, street, area, landmark…',
                      errorText: _addressError,
                      prefixIcon: const Icon(
                          Icons.home_outlined),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            // Payment note
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.08),
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                    color: AppTheme.success
                        .withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments_rounded,
                      color: AppTheme.success),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: Text(
                      'Simulated payment — no real charge is made. Safe retries use an idempotency key.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.success),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            PremiumButton(
              label: 'Place order • ${cart.totalPrice}',
              icon: Icons.check_circle_rounded,
              isLoading: checkout.isLoading,
              onPressed:
                  checkout.isLoading ? null : _submitOrder,
            ),
            if (checkout.error != null) ...[
              const SizedBox(height: AppTheme.spaceMd),
              Container(
                padding:
                    const EdgeInsets.all(AppTheme.spaceMd),
                decoration: BoxDecoration(
                  color: AppTheme.danger
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(
                      AppTheme.radiusSm),
                  border: Border.all(
                      color: AppTheme.danger
                          .withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppTheme.danger, size: 20),
                    const SizedBox(width: AppTheme.spaceSm),
                    Expanded(
                      child: Text(
                        checkout.error!,
                        style: const TextStyle(
                            color: AppTheme.danger,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppTheme.spaceMd),
          ],
        ),
      ),
    );
  }

  String _lineTotal(int priceMinor, int qty) {
    final total = priceMinor * qty;
    final rupees = total ~/ 100;
    final paise = total % 100;
    return '₹$rupees.${paise.toString().padLeft(2, '0')}';
  }
}
