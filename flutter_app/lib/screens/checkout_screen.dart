import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/order_provider.dart';
import '../providers/restaurant_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/qb_widgets.dart';

/// Checkout screen: delivery address, order summary, place order.
///
/// Uses the real `POST /api/v1/orders` API with idempotency keys (generated
/// per submission in [CheckoutNotifier]). Duplicate taps are blocked while
/// a submission is in flight.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitted = false;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final cart = ref.watch(cartProvider);
    final checkout = ref.watch(checkoutProvider);

    // Redirect to confirmation on success (once).
    ref.listen(checkoutProvider, (_, next) {
      final orderId = next.orderId;
      if (orderId != null && orderId.isNotEmpty && !_submitted) {
        _submitted = true;
        ref.read(cartProvider.notifier).clearCart();
        context.go('/order/$orderId/confirmation');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: cart.items.isEmpty
          ? QbEmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Nothing to check out',
              message: 'Your cart is empty.',
              actionLabel: 'Browse restaurants',
              onAction: () => context.go('/'),
            )
          : Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 720),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Address
                      Text('Delivery address',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText:
                              'Flat / street / area / city / PIN',
                          prefixIcon:
                              Icon(Icons.location_on_outlined),
                        ),
                        validator: (v) {
                          if (v == null ||
                              v.trim().length < 10) {
                            return 'Please enter a complete delivery address.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      // Summary
                      Text('Order summary',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge),
                      const SizedBox(height: 12),
                      QbCard(
                        child: Column(
                          children: [
                            for (final item
                                in cart.items) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                        '${item.quantity} × ${item.menuItem.name}',
                                        style: Theme.of(
                                                context)
                                            .textTheme
                                            .bodyMedium),
                                  ),
                                  Text(
                                      formatInr(item
                                          .totalPrice),
                                      style: Theme.of(
                                              context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              fontWeight:
                                                  FontWeight
                                                      .w600)),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text('Total',
                                    style: Theme.of(
                                            context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight:
                                                FontWeight
                                                    .w800)),
                                const Spacer(),
                                Text(
                                    formatInr(
                                        cart.totalAmount),
                                    style: Theme.of(
                                            context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight:
                                                FontWeight
                                                    .w800,
                                            color: tokens
                                                .primary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Final delivery fee and taxes are calculated by the server at order time.',
                        style:
                            Theme.of(context).textTheme.bodySmall,
                      ),
                      // Error
                      if (checkout.error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding:
                              const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: tokens.danger.withValues(
                                alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                                color: tokens.danger
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  color: tokens.danger),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                    checkout.error!,
                                    style: TextStyle(
                                        color:
                                            tokens.danger)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      QbPrimaryButton(
                        label: 'Place order',
                        icon: Icons.check_rounded,
                        isLoading: checkout.isLoading,
                        onPressed: checkout.isLoading
                            ? null
                            : _placeOrder,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    final cart = ref.read(cartProvider);
    if (!(cart.items.isNotEmpty && cart.restaurantId != null)) return;

    // Double-submit guard.
    if (ref.read(checkoutProvider).isLoading) return;

    try {
      await ref.read(checkoutProvider.notifier).createOrder(
            restaurantId: cart.restaurantId!,
            deliveryAddress:
                _addressController.text.trim(),
            items: cart.items
                .map((i) => {
                      'menu_item_id': i.menuItem.id,
                      'quantity': i.quantity,
                    })
                .toList(),
          );
    } catch (_) {
      // Error is surfaced via checkoutProvider.error.
    }
  }
}
