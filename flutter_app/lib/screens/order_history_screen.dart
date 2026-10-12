import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../models/order.dart';
import '../providers/order_provider.dart';
import '../widgets/order_widgets.dart';
import '../widgets/premium_widgets.dart';

/// Premium order history: rich order cards with status pills.
class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersListProvider(1));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your orders'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: orders.when(
        data: (data) {
          if (data.items.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No orders yet',
              message:
                  'When you place an order, it will show up here.',
              actionLabel: 'Order something tasty',
              onAction: () => context.go('/'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(ordersListProvider(1)),
            child: ListView.separated(
              padding:
                  const EdgeInsets.all(AppTheme.spaceMd),
              itemCount: data.items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppTheme.spaceSm),
              itemBuilder: (context, i) =>
                  _OrderCard(order: data.items[i]),
            ),
          );
        },
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          itemCount: 4,
          separatorBuilder: (_, __) =>
              const SizedBox(height: AppTheme.spaceSm),
          itemBuilder: (_, __) =>
              const SkeletonCard(height: 108),
        ),
        error: (err, _) => ErrorCard(
          message: 'Couldn\'t load your orders.\n$err',
          onRetry: () =>
              ref.invalidate(ordersListProvider(1)),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final itemSummary = order.items.isEmpty
        ? 'No items'
        : order.items
            .map((i) => '${i.quantity}× ${i.name}')
            .join(', ');
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius:
          BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(AppTheme.radiusMd),
        onTap: () =>
            context.go('/order/${order.id}/tracking'),
        child: Container(
          padding:
              const EdgeInsets.all(AppTheme.spaceMd),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: AppTheme.cardShadow(context),
          ),
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
                          .titleMedium,
                    ),
                  ),
                  StatusPill(status: order.status),
                ],
              ),
              const SizedBox(height: AppTheme.spaceXs),
              Text(
                itemSummary,
                style:
                    Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 14,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(order.createdAt),
                    style:
                        Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    order.displayPrice,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: AppTheme.primary),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: AppTheme.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]}, ${d.year}';
  }
}
