import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/order_provider.dart';
import '../widgets/premium_widgets.dart';

/// Premium order confirmation with animated success mark.
class OrderConfirmationScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderConfirmationScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState
    extends ConsumerState<OrderConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checkoutState = ref.watch(checkoutProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Column(
            children: [
              const Spacer(),
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: AppTheme.success
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.success,
                    size: 64,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceLg),
              Text(
                'Order placed!',
                style:
                    Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(
                      AppTheme.radiusSm),
                  border: Border.all(
                      color:
                          Theme.of(context).dividerColor),
                ),
                child: Text(
                  'Order #${widget.orderId.length > 8 ? widget.orderId.substring(0, 8) : widget.orderId}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontFeatures: const [
                          FontFeature.tabularFigures()
                        ],
                      ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Text(
                checkoutState.successMessage ??
                    'We\'re firing up the kitchen. Track your order live.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color,
                    ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              PremiumButton(
                label: 'Track order',
                icon: Icons.timeline_rounded,
                onPressed: () => context
                    .go('/order/${widget.orderId}/tracking'),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          AppTheme.radiusSm),
                    ),
                  ),
                  child: const Text('Back to home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
