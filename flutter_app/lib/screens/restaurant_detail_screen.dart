import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../models/restaurant.dart';
import '../providers/restaurant_provider.dart';
import '../widgets/food_image.dart';
import '../widgets/premium_widgets.dart';

/// Premium restaurant detail: rich header, menu list with food cards and
/// inline quantity steppers, sticky cart bar.
class RestaurantDetailScreen extends ConsumerStatefulWidget {
  final String restaurantId;

  const RestaurantDetailScreen({super.key, required this.restaurantId});

  @override
  ConsumerState<RestaurantDetailScreen> createState() =>
      _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState
    extends ConsumerState<RestaurantDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final menuAsync =
        ref.watch(restaurantMenuProvider((widget.restaurantId, 1)));
    final restaurantsAsync = ref.watch(restaurantsProvider(1));
    final cart = ref.watch(cartProvider);

    final restaurant = restaurantsAsync.maybeWhen(
      data: (page) => page.items
          .where((r) => r.id == widget.restaurantId)
          .firstOrNull,
      orElse: () => null,
    );

    return Scaffold(
      body: menuAsync.when(
        data: (menu) => _buildBody(context, menu, restaurant, cart),
        loading: () => const Center(
            child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: ErrorCard(
            message: 'Couldn\'t load the menu.\n$err',
            onRetry: () => ref.invalidate(
                restaurantMenuProvider((widget.restaurantId, 1))),
          ),
        ),
      ),
      bottomNavigationBar: cart.items.isNotEmpty
          ? _CartBar(
              itemCount:
                  cart.items.fold(0, (s, i) => s + i.quantity),
              total: cart.totalPrice,
              onTap: () => context.go('/cart'),
            )
          : null,
    );
  }

  Widget _buildBody(BuildContext context, RestaurantMenu menu,
      Restaurant? restaurant, CartState cart) {
    return CustomScrollView(
      slivers: [
        // Collapsing header
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black38,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                FoodImage(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.zero,
                  fallbackIcon: Icons.restaurant_rounded,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: AppTheme.spaceMd,
                  right: AppTheme.spaceMd,
                  bottom: AppTheme.spaceMd,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (restaurant != null)
                        Row(
                          children: [
                            RatingBadge(
                                rating: restaurant.rating,
                                large: true),
                            const SizedBox(width: AppTheme.spaceSm),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusXs),
                              ),
                              child: Text(
                                restaurant.cuisine,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: AppTheme.spaceXs),
                      Text(
                        restaurant?.name ?? 'Restaurant',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (restaurant != null)
                        Text(
                          '${restaurant.deliveryTimeMinutes} min delivery • ${restaurant.deliveryFeeMinor == 0 ? 'Free delivery' : restaurant.deliveryFee}',
                          style: TextStyle(
                            color: Colors.white
                                .withValues(alpha: 0.85),
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
        // Menu items
        SliverPadding(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final item = menu.items[i];
                final inCart = cart.items
                    .where((c) => c.menuItem.id == item.id)
                    .firstOrNull;
                return Padding(
                  padding: const EdgeInsets.only(
                      bottom: AppTheme.spaceSm),
                  child: _MenuCard(
                    item: item,
                    quantity: inCart?.quantity ?? 0,
                    onAdd: () => ref
                        .read(cartProvider.notifier)
                        .addItem(item, widget.restaurantId),
                    onIncrement: () => ref
                        .read(cartProvider.notifier)
                        .updateQuantity(item.id,
                            (inCart?.quantity ?? 0) + 1),
                    onDecrement: () => ref
                        .read(cartProvider.notifier)
                        .updateQuantity(item.id,
                            (inCart?.quantity ?? 1) - 1),
                  ),
                );
              },
              childCount: menu.items.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  final MenuItem item;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _MenuCard({
    required this.item,
    required this.quantity,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final dimmed = !item.available;
    return Opacity(
      opacity: dimmed ? 0.55 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceSm),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius:
              BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.cardShadow(context),
        ),
        child: Row(
          children: [
            FoodImage(
              width: 84,
              height: 84,
              imageUrl: item.image,
              fallbackIcon: Icons.fastfood_rounded,
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    item.description,
                    style:
                        Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  Row(
                    children: [
                      Text(
                        item.price,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: AppTheme.primary),
                      ),
                      const Spacer(),
                      if (!item.available)
                        const Text(
                          'Unavailable',
                          style: TextStyle(
                            color: AppTheme.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else if (quantity == 0)
                        _AddButton(onTap: onAdd)
                      else
                        QuantityStepper(
                          quantity: quantity,
                          onIncrement: onIncrement,
                          onDecrement: onDecrement,
                          compact: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primary,
      borderRadius: BorderRadius.circular(AppTheme.radiusXs),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
        onTap: onTap,
        child: const Padding(
          padding:
              EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Text(
            'ADD',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  final int itemCount;
  final String total;
  final VoidCallback onTap;

  const _CartBar({
    required this.itemCount,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppTheme.spaceMd, AppTheme.spaceSm,
            AppTheme.spaceMd, AppTheme.spaceMd),
        child: Material(
          borderRadius:
              BorderRadius.circular(AppTheme.radiusMd),
          child: InkWell(
            borderRadius:
                BorderRadius.circular(AppTheme.radiusMd),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMd,
                  vertical: 14),
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary
                        .withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    '$itemCount item${itemCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  Text(
                    total,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'View cart',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700),
                  ),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
