import 'package:flutter/material.dart';
import '../config/food_images.dart';
import '../config/theme.dart';

/// Elegant food image with gradient fallback.
///
/// Shows the network image when [imageUrl] is provided; otherwise renders a
/// warm gradient with a food icon — never a broken-image box.
///
/// Pass [cacheWidth] matching the display size so the image is decoded at
/// (roughly) the rendered resolution instead of the full download size —
/// this is what keeps long image lists smooth.
class FoodImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;
  final int? cacheWidth;

  const FoodImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.borderRadius,
    this.fallbackIcon = Icons.restaurant_rounded,
    this.cacheWidth,
  });

  static const _gradients = [
    [Color(0xFFFF9A5A), Color(0xFFE5484D)],
    [Color(0xFFF59E0B), Color(0xFFD97706)],
    [Color(0xFF7C3AED), Color(0xFF4F46E5)],
    [Color(0xFF16A34A), Color(0xFF059669)],
    [Color(0xFFEC4899), Color(0xFFD63A5C)],
  ];

  List<Color> _gradientFor(String seed) {
    final idx = seed.hashCode.abs() % _gradients.length;
    return _gradients[idx];
  }

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppTheme.radiusMd);
    final colors = _gradientFor(imageUrl ?? fallbackIcon.toString());

    Widget fallback = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: radius,
      ),
      child: Center(
        child: Icon(fallbackIcon,
            color: Colors.white.withValues(alpha: 0.9),
            size: (height ?? 80) * 0.38),
      ),
    );

    if (imageUrl == null || imageUrl!.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: radius,
      child: Image(
        image: QuickBiteImages.imageProvider(
          imageUrl!,
          cacheWidth: cacheWidth,
        ),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: radius,
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Pulsing skeleton placeholder for loading lists.
class SkeletonCard extends StatefulWidget {
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonCard({super.key, required this.height, this.borderRadius});

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkSurfaceAlt
        : AppTheme.lightSurfaceAlt;
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: base,
          borderRadius:
              widget.borderRadius ?? BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
    );
  }
}

/// Skeleton list used while restaurants load.
class RestaurantListSkeleton extends StatelessWidget {
  const RestaurantListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      child: Column(
        children: const [
          SkeletonCard(height: 148),
          SizedBox(height: AppTheme.spaceMd),
          SkeletonCard(height: 148),
          SizedBox(height: AppTheme.spaceMd),
          SkeletonCard(height: 148),
        ],
      ),
    );
  }
}
