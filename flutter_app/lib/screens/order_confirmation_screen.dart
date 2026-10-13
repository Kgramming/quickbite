import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/theme_provider.dart';
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
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      body: Stack(
        children: [
          const _ConfettiBurst(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
              const Spacer(),
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: tokens.success
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: tokens.success,
                    size: 64,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Order placed!',
                style:
                    Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(
                      12),
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
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          12),
                    ),
                  ),
                  child: const Text('Back to home'),
                ),
              ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confetti burst: colorful particles falling from top on order success.
class _ConfettiBurst extends StatefulWidget {
  const _ConfettiBurst();

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<_ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _particles = <_Particle>[];
  static const _colors = [
    Color(0xFFE5484D),
    Color(0xFFF59E0B),
    Color(0xFF16A34A),
    Color(0xFF7C3AED),
    Color(0xFFEC4899),
    Color(0xFF0EA5E9),
  ];

  @override
  void initState() {
    super.initState();
    final rand = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < 50; i++) {
      _particles.add(_Particle(
        x: ((rand + i * 37) % 100) / 100,
        delay: ((rand + i * 13) % 800) / 1000,
        speed: 0.5 + ((rand + i * 7) % 50) / 100,
        size: 6 + ((rand + i * 11) % 8),
        color: _colors[i % _colors.length],
        rotation: ((rand + i * 17) % 360).toDouble(),
      ));
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _ConfettiPainter(
            particles: _particles,
            progress: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Particle {
  final double x;
  final double delay;
  final double speed;
  final double size;
  final Color color;
  final double rotation;

  _Particle({
    required this.x,
    required this.delay,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotation,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = (progress - p.delay) / p.speed;
      if (t < 0 || t > 1) continue;

      final y = t * size.height * 1.2 - 20;
      final xPos = p.x * size.width + t * 40 * (p.x > 0.5 ? 1 : -1);
      final alpha = t > 0.8 ? (1 - t) / 0.2 : 1.0;

      canvas.save();
      canvas.translate(xPos, y);
      canvas.rotate(p.rotation + t * 6);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.6,
        ),
        Paint()..color = p.color.withValues(alpha: alpha.clamp(0.0, 1.0)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
