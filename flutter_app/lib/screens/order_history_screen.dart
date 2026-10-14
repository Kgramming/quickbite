import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/order.dart';
import '../models/restaurant.dart';
import '../providers/order_provider.dart';
import '../providers/restaurant_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/qb_widgets.dart';

/// Order history from the real API.
///
/// Shows order cards with actual status, amounts in INR, and item counts.
/// A polished empty state appears when the customer has no orders.
class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersListProvider(1));

    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ordersAsync.when(
            data: (page) {
              if (page.items.isEmpty) {
                return QbEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No orders yet',
                  message:
                      'Your order history will appear here once you place your first order.',
                  actionLabel: 'Order now',
                  onAction: () => context.go('/'),
                );
              }
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(ordersListProvider(1)),
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: page.items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _OrderCard(order: page.items[i]),
                ),
              );
            },
            loading: () => const QbLoading(
                message: 'Loading your orders…'),
            error: (e, _) => QbErrorState(
              message:
                  'Could not load orders. Check your connection and try again.',
              onRetry: () =>
                  ref.invalidate(ordersListProvider(1)),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final Order order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final statusColor = _statusColor(order.status, tokens);

    return QbCard(
      onTap: () => context.go('/order/${order.id}/tracking'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(order.status),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${order.items.length} item${order.items.length == 1 ? '' : 's'} · ${_formatDate(order.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            order.items
                .take(3)
                .map((i) => '${i.quantity}× ${i.name}')
                .join(', ') +
                (order.items.length > 3
                    ? ' +${order.items.length - 3} more'
                    : ''),
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(height: 20),
          Row(
            children: [
              Text('Total',
                  style:
                      Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              Text(formatInr(order.totalAmountMinor),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: tokens.primary)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _reorder(context, ref, order),
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: const Text('Order again'),
            ),
          ),
        ],
      ),
    );
  }

  /// Rebuilds the cart from a past order's items and jumps to the cart.
  /// Uses the recorded item details; prices refresh from the cart.
  void _reorder(BuildContext context, WidgetRef ref, Order order) {
    final notifier = ref.read(cartProvider.notifier);
    notifier.clearCart();
    for (final oi in order.items) {
      final menuItem = MenuItem(
        id: oi.menuItemId,
        name: oi.name,
        description: '',
        priceMinor: oi.priceMinor,
        available: true,
      );
      for (var q = 0; q < oi.quantity; q++) {
        notifier.addItem(menuItem, order.restaurantId);
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '${order.items.length} item${order.items.length == 1 ? '' : 's'} added back to your cart')),
    );
    context.go('/cart');
  }

  String _statusLabel(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.paid:
        return 'Paid';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.driverAssigned:
        return 'On the way';
      case OrderStatus.paymentFailed:
        return 'Payment failed';
      case OrderStatus.failed:
        return 'Failed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _statusColor(OrderStatus s, tokens) {
    switch (s) {
      case OrderStatus.pending:
        return tokens.warning;
      case OrderStatus.paid:
      case OrderStatus.confirmed:
        return tokens.success;
      case OrderStatus.driverAssigned:
        return tokens.primary;
      case OrderStatus.paymentFailed:
      case OrderStatus.failed:
      case OrderStatus.cancelled:
        return tokens.danger;
    }
  }

  String _formatDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year}';
  }
}
