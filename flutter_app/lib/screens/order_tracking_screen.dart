import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../models/order.dart';
import '../providers/order_provider.dart';
import '../widgets/order_widgets.dart';
import '../widgets/premium_widgets.dart';

/// Premium order tracking: live status timeline, order summary,
/// driver card and failure states. Polls via orderStatusRefreshProvider.
class OrderTrackingScreen extends ConsumerWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderStream = ref.watch(orderStatusRefreshProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track order'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.invalidate(orderStatusRefreshProvider(orderId)),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: orderStream.when(
        data: (order) => _buildBody(context, order),
        loading: () => const Center(
            child: CircularProgressIndicator()),
        error: (err, _) => ErrorCard(
          message: 'Couldn\'t load this order.\n$err',
          onRetry: () =>
              ref.invalidate(orderStatusRefreshProvider(orderId)),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Order order) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order header card
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              gradient: AppTheme.brandGradient,
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusMd),
              boxShadow: [
                BoxShadow(
                  color:
                      AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.displayPrice,
                        style: TextStyle(
                          color: Colors.white
                              .withValues(alpha: 0.9),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.circle,
                          size: 8, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        _shortStatus(order.status),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          // Timeline card
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
                Text('Status',
                    style:
                        Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppTheme.spaceMd),
                Consumer(
                  builder: (context, ref, _) {
                    final historyAsync =
                        ref.watch(orderHistoryProvider(orderId));
                    return historyAsync.when(
                      data: (history) => OrderTimeline(
                        history: history,
                        currentStatus: order.status,
                      ),
                      loading: () => const SizedBox(
                        height: 120,
                        child: Center(
                            child:
                                CircularProgressIndicator()),
                      ),
                      error: (_, __) => OrderTimeline(
                        history: const [],
                        currentStatus: order.status,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Failure banner
          if (order.status == OrderStatus.paymentFailed ||
              order.status == OrderStatus.failed) ...[
            const SizedBox(height: AppTheme.spaceMd),
            Container(
              padding:
                  const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color:
                    AppTheme.danger.withValues(alpha: 0.08),
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                    color: AppTheme.danger
                        .withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppTheme.danger),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: Text(
                      order.failureCode != null
                          ? 'Failed: ${order.failureCode}'
                          : 'This order could not be completed.',
                      style: const TextStyle(
                          color: AppTheme.danger,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spaceMd),
          // Driver card
          if (order.driver != null)
            Container(
              padding:
                  const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMd),
                boxShadow: AppTheme.cardShadow(context),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.success
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                        Icons.delivery_dining_rounded,
                        color: AppTheme.success,
                        size: 28),
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text('Your driver',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall),
                        Text(order.driver!.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium),
                        if (order.driver!.phone != null)
                          Text(order.driver!.phone!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (order.driver != null)
            const SizedBox(height: AppTheme.spaceMd),
          // Items + address card
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
                Text('Items',
                    style:
                        Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppTheme.spaceSm),
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          '×${item.quantity}',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(
                            width: AppTheme.spaceSm),
                        Expanded(
                          child: Text(item.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium),
                        ),
                        Text(
                          _minor(item.priceMinor *
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
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 18, color: AppTheme.primary),
                    const SizedBox(width: AppTheme.spaceSm),
                    Expanded(
                      child: Text(
                        order.deliveryAddress,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
        ],
      ),
    );
  }

  String _shortStatus(OrderStatus s) {
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

  String _minor(int v) {
    return '₹${v ~/ 100}.${(v % 100).toString().padLeft(2, '0')}';
  }
}
