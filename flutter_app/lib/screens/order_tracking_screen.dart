import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/theme_provider.dart';
import '../config/app_themes.dart';
import '../models/order.dart';
import '../providers/order_provider.dart';
import '../widgets/order_widgets.dart';
import '../widgets/premium_widgets.dart';

/// Premium order tracking: live status timeline, order summary,
/// driver card and failure states. Polls via orderStatusRefreshProvider.
class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState
    extends ConsumerState<OrderTrackingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderStream = ref.watch(orderStatusRefreshProvider(widget.orderId));
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track order'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/orders');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.invalidate(orderStatusRefreshProvider(widget.orderId)),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: orderStream.when(
        data: (order) => _buildBody(context, ref, order, tokens),
        loading: () => const Center(
            child: CircularProgressIndicator()),
        error: (err, _) => ErrorCard(
          message: 'Couldn\'t load this order.\n$err',
          onRetry: () =>
              ref.invalidate(orderStatusRefreshProvider(widget.orderId)),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, Order order,
      QuickBiteTokens tokens) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order header card
          _StaggeredIn(
            delay: 0,
            child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [tokens.primary, tokens.primaryDark]),
              borderRadius:
                  BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color:
                      tokens.primary.withValues(alpha: 0.3),
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
        ),
          const SizedBox(height: 16),
          // Animated journey progress
          _StaggeredIn(
            delay: 100,
            child: _JourneyProgress(
              status: order.status,
              tokens: tokens,
              pulseController: _pulseController,
            ),
          ),
          const SizedBox(height: 16),
          // Timeline card
          _StaggeredIn(
            delay: 200,
            child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius:
                  BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status',
                    style:
                        Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Consumer(
                  builder: (context, ref, _) {
                    final historyAsync =
                        ref.watch(orderHistoryProvider(widget.orderId));
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
        ),
          // Notifications feed — real backend events for this order
          _StaggeredIn(
            delay: 250,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications_outlined,
                          color: tokens.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('Notifications',
                          style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, _) {
                      final notifAsync = ref.watch(
                          orderNotificationsProvider((widget.orderId, 1)));
                      return notifAsync.when(
                        data: (notifs) => notifs.isEmpty
                            ? Text('No notifications yet.',
                                style: Theme.of(context).textTheme.bodySmall)
                            : Column(
                                children: [
                                  for (final n in notifs)
                                    _NotificationRow(
                                        notification: n, tokens: tokens),
                                ],
                              ),
                        loading: () => const SizedBox(
                          height: 80,
                          child: Center(
                              child: CircularProgressIndicator()),
                        ),
                        error: (_, __) => Text(
                          'Could not load notifications.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Failure banner
          if (order.status == OrderStatus.paymentFailed ||
              order.status == OrderStatus.failed) ...[
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    tokens.danger.withValues(alpha: 0.08),
                borderRadius:
                    BorderRadius.circular(16),
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
                      order.failureCode != null
                          ? 'Failed: ${order.failureCode}'
                          : 'This order could not be completed.',
                      style: TextStyle(
                          color: tokens.danger,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Driver card
          if (order.driver != null)
            Container(
              padding:
                  const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius:
                    BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: tokens.success
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                        Icons.delivery_dining_rounded,
                        color: tokens.success,
                        size: 28),
                  ),
                  const SizedBox(width: 16),
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
            const SizedBox(height: 16),
          // Items + address card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius:
                  BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Items',
                    style:
                        Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          '×${item.quantity}',
                          style: TextStyle(
                            color: tokens.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(
                            width: 8),
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
                    Icon(Icons.location_on_outlined,
                        size: 18, color: tokens.primary),
                    const SizedBox(width: 8),
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
          const SizedBox(height: 16),
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

/// Staggered entrance: fades + slides child in with a delay.
class _StaggeredIn extends StatefulWidget {
  final int delay;
  final Widget child;

  const _StaggeredIn({required this.delay, required this.child});

  @override
  State<_StaggeredIn> createState() => _StaggeredInState();
}

class _StaggeredInState extends State<_StaggeredIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

/// Animated journey progress: 3 honest stages mirroring the real backend
/// status model (pending -> paid/confirmed -> driverAssigned).
/// driverAssigned is the terminal live stage at 100% — there is no
/// backend "delivered" status, so none is shown.
class _JourneyProgress extends StatelessWidget {
  final OrderStatus status;
  final QuickBiteTokens tokens;
  final AnimationController pulseController;

  const _JourneyProgress({
    required this.status,
    required this.tokens,
    required this.pulseController,
  });

  static const _stages = [
    (Icons.receipt_long_rounded, 'Placed'),
    (Icons.storefront_rounded, 'Preparing'),
    (Icons.delivery_dining_rounded, 'On the way'),
  ];

  int get _currentStage {
    switch (status) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.paid:
        return 1;
      case OrderStatus.confirmed:
        return 1;
      case OrderStatus.driverAssigned:
        return 2;
      default:
        return 0;
    }
  }

  bool get _isLive =>
      status != OrderStatus.paymentFailed &&
      status != OrderStatus.failed &&
      status != OrderStatus.cancelled;

  @override
  Widget build(BuildContext context) {
    final progress = (_currentStage + 1) / _stages.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Pulsing live dot
              if (_isLive)
                AnimatedBuilder(
                  animation: pulseController,
                  builder: (context, _) => Container(
                    width: 10 + pulseController.value * 4,
                    height: 10 + pulseController.value * 4,
                    decoration: BoxDecoration(
                      color: tokens.success.withValues(
                        alpha: 0.6 + pulseController.value * 0.4,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              else
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: tokens.danger,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                _isLive ? 'LIVE TRACKING' : 'TRACKING ENDED',
                style: TextStyle(
                  color: _isLive ? tokens.success : tokens.danger,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: tokens.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Animated progress bar
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: tokens.primary.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(tokens.primary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Stage icons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 0; i < _stages.length; i++)
                _StageIcon(
                  icon: _stages[i].$1,
                  label: _stages[i].$2,
                  isDone: i <= _currentStage,
                  isCurrent: i == _currentStage && _isLive,
                  tokens: tokens,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StageIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDone;
  final bool isCurrent;
  final QuickBiteTokens tokens;

  const _StageIcon({
    required this.icon,
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDone ? tokens.primary : tokens.primary.withValues(alpha: 0.25);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: isCurrent ? 52 : 44,
          height: isCurrent ? 52 : 44,
          decoration: BoxDecoration(
            color: isDone
                ? tokens.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: isCurrent ? 2.5 : 1.5,
            ),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: tokens.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isDone ? FontWeight.w700 : FontWeight.w400,
            color: isDone
                ? Theme.of(context).textTheme.bodyMedium?.color
                : Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }
}

/// A single row in the notifications feed: icon by event type,
/// the backend's message, and a relative timestamp.
class _NotificationRow extends StatelessWidget {
  final OrderNotification notification;
  final QuickBiteTokens tokens;

  const _NotificationRow({required this.notification, required this.tokens});

  IconData get _icon {
    final t = notification.eventType.toLowerCase();
    if (t.contains('payment')) return Icons.payments_outlined;
    if (t.contains('driver')) return Icons.delivery_dining_rounded;
    if (t.contains('confirm')) return Icons.check_circle_outline_rounded;
    if (t.contains('fail') || t.contains('cancel')) {
      return Icons.error_outline_rounded;
    }
    return Icons.notifications_outlined;
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tokens.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 18, color: tokens.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.message,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(_relativeTime(notification.createdAt),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
