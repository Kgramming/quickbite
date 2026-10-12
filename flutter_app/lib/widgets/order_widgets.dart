import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/order.dart';

/// Color-coded status pill for order states.
class StatusPill extends StatelessWidget {
  final OrderStatus status;
  final bool large;

  const StatusPill({super.key, required this.status, this.large = false});

  (Color, IconData, String) get _meta {
    switch (status) {
      case OrderStatus.pending:
        return (AppTheme.warning, Icons.hourglass_top_rounded, 'Pending');
      case OrderStatus.paid:
        return (AppTheme.info, Icons.payments_rounded, 'Paid');
      case OrderStatus.confirmed:
        return (AppTheme.accent, Icons.storefront_rounded, 'Confirmed');
      case OrderStatus.driverAssigned:
        return (AppTheme.success, Icons.delivery_dining_rounded,
            'On the way');
      case OrderStatus.paymentFailed:
        return (AppTheme.danger, Icons.payment_rounded, 'Payment failed');
      case OrderStatus.failed:
        return (AppTheme.danger, Icons.error_outline_rounded, 'Failed');
      case OrderStatus.cancelled:
        return (AppTheme.lightMuted, Icons.cancel_outlined, 'Cancelled');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _meta;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 14 : 10,
        vertical: large ? 7 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: large ? 16 : 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: large ? 14 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical order-status timeline.
class OrderTimeline extends StatelessWidget {
  final List<OrderStatusHistory> history;
  final OrderStatus currentStatus;

  const OrderTimeline({
    super.key,
    required this.history,
    required this.currentStatus,
  });

  static const _steps = [
    OrderStatus.pending,
    OrderStatus.paid,
    OrderStatus.confirmed,
    OrderStatus.driverAssigned,
  ];

  static const _labels = [
    'Order placed',
    'Payment complete',
    'Restaurant confirmed',
    'Driver on the way',
  ];

  static const _icons = [
    Icons.receipt_long_rounded,
    Icons.payments_rounded,
    Icons.storefront_rounded,
    Icons.delivery_dining_rounded,
  ];

  int get _currentIndex {
    final idx = _steps.indexOf(currentStatus);
    if (idx >= 0) return idx;
    return -1; // terminal failure state
  }

  @override
  Widget build(BuildContext context) {
    final isFailed = currentStatus == OrderStatus.paymentFailed ||
        currentStatus == OrderStatus.failed ||
        currentStatus == OrderStatus.cancelled;

    return Column(
      children: [
        for (int i = 0; i < _steps.length; i++)
          _TimelineRow(
            icon: _icons[i],
            label: _labels[i],
            isDone: i < _currentIndex || (!isFailed && i == _currentIndex),
            isCurrent: i == _currentIndex && !isFailed,
            isLast: i == _steps.length - 1,
            timestamp: _timestampFor(_steps[i]),
          ),
        if (isFailed)
          _TimelineRow(
            icon: Icons.error_outline_rounded,
            label: _failedLabel,
            isDone: false,
            isCurrent: true,
            isLast: true,
            isError: true,
            timestamp: history.isNotEmpty ? history.last.changedAt : null,
          ),
      ],
    );
  }

  String get _failedLabel {
    switch (currentStatus) {
      case OrderStatus.paymentFailed:
        return 'Payment failed';
      case OrderStatus.cancelled:
        return 'Order cancelled';
      default:
        return 'Order failed';
    }
  }

  DateTime? _timestampFor(OrderStatus step) {
    final name = step.toString().split('.').last.toUpperCase().replaceAll(
        'DRIVERASSIGNED', 'DRIVER_ASSIGNED');
    for (final h in history) {
      if (h.status.toUpperCase().replaceAll(' ', '_') == name) {
        return h.changedAt;
      }
    }
    return null;
  }
}

class _TimelineRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;
  final bool isError;
  final DateTime? timestamp;

  const _TimelineRow({
    required this.icon,
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
    this.isError = false,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? AppTheme.danger
        : isDone || isCurrent
            ? AppTheme.primary
            : Theme.of(context).disabledColor;
    final muted = Theme.of(context).textTheme.bodySmall?.color;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDone || isCurrent
                      ? color.withValues(alpha: 0.14)
                      : Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: isDone || isCurrent ? 0.5 : 0.2),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  isDone && !isError ? Icons.check_rounded : icon,
                  color: color,
                  size: 20,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isDone
                        ? AppTheme.primary.withValues(alpha: 0.4)
                        : Theme.of(context).dividerColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isDone || isCurrent
                              ? null
                              : muted,
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                  ),
                  if (timestamp != null)
                    Text(
                      _formatTime(timestamp!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }
}
