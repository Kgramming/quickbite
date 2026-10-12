import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Premium gradient button with loading state and tactile feedback.
class PremiumButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool useGradient;

  const PremiumButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.useGradient = true,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    return AnimatedScale(
      scale: enabled ? 1.0 : 0.98,
      duration: const Duration(milliseconds: 120),
      child: Container(
        decoration: BoxDecoration(
          gradient: useGradient && enabled ? AppTheme.brandGradient : null,
          color: !useGradient || !enabled
              ? Theme.of(context).disabledColor.withValues(alpha: 0.15)
              : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          boxShadow: enabled && useGradient
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            onTap: enabled ? onPressed : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
              alignment: Alignment.center,
              child: isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Section header with title and optional action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(actionLabel!),
                const Icon(Icons.arrow_forward_ios, size: 13),
              ],
            ),
          ),
      ],
    );
  }
}

/// Compact rating badge (star + value).
class RatingBadge extends StatelessWidget {
  final double rating;
  final bool large;

  const RatingBadge({super.key, required this.rating, this.large = false});

  @override
  Widget build(BuildContext context) {
    final bg = rating >= 4.0
        ? AppTheme.success
        : rating >= 3.0
            ? AppTheme.warning
            : AppTheme.danger;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 10 : 7,
        vertical: large ? 5 : 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded,
              color: Colors.white, size: large ? 16 : 13),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: Colors.white,
              fontSize: large ? 14 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quantity stepper for cart/menu items.
class QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool compact;

  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 28.0 : 32.0;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepButton(context, Icons.remove, onDecrement, size),
          Container(
            constraints: BoxConstraints(minWidth: size),
            alignment: Alignment.center,
            child: Text(
              '$quantity',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: compact ? 13 : 15,
                color: AppTheme.primary,
              ),
            ),
          ),
          _stepButton(context, Icons.add, onIncrement, size),
        ],
      ),
    );
  }

  Widget _stepButton(
      BuildContext context, IconData icon, VoidCallback onTap, double size) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: 16, color: AppTheme.primary),
        ),
      ),
    );
  }
}

/// Friendly empty state with icon, title, message and optional action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.color;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppTheme.primary),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: AppTheme.spaceXs),
            Text(
              message,
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: AppTheme.spaceMd),
              PremiumButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline error card with retry.
class ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorCard({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppTheme.danger),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            PremiumButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
              useGradient: false,
            ),
          ],
        ),
      ),
    );
  }
}
