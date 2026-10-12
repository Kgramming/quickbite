import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/order.dart';
import '../providers/order_provider.dart';

class OrderTrackingScreen extends ConsumerWidget {
  final String orderId;

  const OrderTrackingScreen({
    Key? key,
    required this.orderId,
  }) : super(key: key);

  String _getStatusDisplay(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.paid:
        return 'Payment Confirmed';
      case OrderStatus.confirmed:
        return 'Order Confirmed';
      case OrderStatus.driverAssigned:
        return 'Driver Assigned';
      case OrderStatus.paymentFailed:
        return 'Payment Failed';
      case OrderStatus.failed:
        return 'Order Failed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  int _getStatusProgress(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 1;
      case OrderStatus.paid:
        return 2;
      case OrderStatus.confirmed:
        return 3;
      case OrderStatus.driverAssigned:
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use stream provider for live updates
    final orderStream = ref.watch(orderStatusRefreshProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Order'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: orderStream.when(
        data: (order) {
          final statusProgress = _getStatusProgress(order.status);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order ID
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Order #${order.id.substring(0, 8)}'),
                      Text(order.displayPrice, style: Theme.of(context).textTheme.bodyLarge),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Status timeline
                Text('Status', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                _buildStatusTimeline(
                  context,
                  statusProgress,
                  order.status,
                  _getStatusDisplay(order.status),
                ),
                const SizedBox(height: 24),
                // Delivery address
                Text('Delivery Address', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(order.deliveryAddress),
                const SizedBox(height: 24),
                // Items
                Text('Items', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${item.name} x${item.quantity}'),
                        Text(
                          '₹${(item.priceminor / 100).toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                // Driver info if assigned
                if (order.driver != null) ...[
                  Text('Driver', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(order.driver!.name),
                    subtitle: order.driver!.phone != null
                        ? Text(order.driver!.phone!)
                        : null,
                  ),
                  const SizedBox(height: 24),
                ],
                // Error message if payment failed
                if (order.status == OrderStatus.paymentFailed) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Text(
                      'Payment Failed: ${order.failureCode ?? "Unable to process payment"}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Error loading order: $err'),
        ),
      ),
    );
  }

  Widget _buildStatusTimeline(
    BuildContext context,
    int progress,
    OrderStatus currentStatus,
    String statusDisplay,
  ) {
    final statusSteps = [
      'Pending',
      'Payment Confirmed',
      'Order Confirmed',
      'Driver Assigned',
    ];

    return Column(
      children: [
        for (int i = 0; i < statusSteps.length; i++)
          Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: i < progress ? Colors.green : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Icon(
                        i < progress ? Icons.check : Icons.circle,
                        color: i < progress ? Colors.white : Colors.grey,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(statusSteps[i]),
                        if (i == progress - 1)
                          Text(
                            'Current step',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (i < statusSteps.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 8, bottom: 8),
                  child: Container(
                    width: 2,
                    height: 20,
                    color: i < progress - 1 ? Colors.green : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
