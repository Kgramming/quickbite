import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/food_images.dart';
import '../models/restaurant.dart';
import '../providers/restaurant_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/food_image.dart';
import '../widgets/qb_shell.dart';
import '../widgets/qb_widgets.dart';

/// Restaurant detail + menu screen.
///
/// Hero image, honest metadata, menu grouped with food cards, quantity
/// controls, and add-to-cart. Veg indicators are inferred from names since
/// the backend provides no veg flag — shown as a best-effort hint.
class RestaurantDetailScreen extends ConsumerStatefulWidget {
  final String restaurantId;

  const RestaurantDetailScreen(
      {super.key, required this.restaurantId});

  @override
  ConsumerState<RestaurantDetailScreen> createState() =>
      _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState
    extends ConsumerState<RestaurantDetailScreen> {
  final _searchController = TextEditingController();
  String _menuQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final restaurantsAsync = ref.watch(restaurantsProvider(1));
    final menuAsync = ref.watch(
        restaurantMenuProvider((widget.restaurantId, 1)));

    return Scaffold(
      body: restaurantsAsync.when(
        data: (page) {
          final restaurant = page.items
              .where((r) => r.id == widget.restaurantId)
              .firstOrNull;
          if (restaurant == null) {
            return SafeArea(
              child: Column(
                children: [
                  _BackBar(tokens: tokens),
                  Expanded(
                    child: QbEmptyState(
                      icon: Icons.restaurant_rounded,
                      title: 'Restaurant not found',
                      message:
                          'This restaurant may have been removed.',
                      actionLabel: 'Back to home',
                      onAction: () => context.go('/'),
                    ),
                  ),
                ],
              ),
            );
          }
          return _buildBody(context, tokens, restaurant, menuAsync);
        },
        loading: () =>
            const SafeArea(child: QbLoading(message: 'Loading…')),
        error: (e, _) => SafeArea(
          child: Column(
            children: [
              _BackBar(tokens: tokens),
              Expanded(
                child: QbErrorState(
                  message: 'Could not load restaurant details.',
                  onRetry: () =>
                      ref.invalidate(restaurantsProvider(1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context,
      tokens,
      Restaurant restaurant,
      AsyncValue<RestaurantMenu> menuAsync) {
    final cart = ref.watch(cartProvider);
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
        // Hero
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: CircleAvatar(
              backgroundColor:
                  tokens.surface.withValues(alpha: 0.9),
              child: IconButton(
                icon: Icon(Icons.arrow_back_rounded,
                    color: tokens.text),
                onPressed: () => context.go('/'),
              ),
            ),
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: QbCartButton(),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                FoodImage(
                  imageUrl: QuickBiteImages.forRestaurant(
                    restaurantId: restaurant.id,
                    restaurantName: restaurant.name,
                    backendImageUrl: restaurant.imageUrl,
                  ),
                  width: double.infinity,
                  borderRadius: BorderRadius.zero,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Info
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(restaurant.name,
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(fontSize: 26)),
                const SizedBox(height: 6),
                Text(restaurant.description,
                    style:
                        Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                // Honest metadata row — only real data.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (restaurant.hasRating)
                      _MetaChip(
                        icon: Icons.star_rounded,
                        label: restaurant.rating
                            .toStringAsFixed(1),
                        color: tokens.success,
                      ),
                    if (restaurant.hasDeliveryEstimate)
                      _MetaChip(
                        icon: Icons.delivery_dining_outlined,
                        label:
                            '${restaurant.deliveryTimeMinutes} min',
                      ),
                    if (restaurant.cuisine.isNotEmpty)
                      _MetaChip(
                        icon: Icons.restaurant_menu_rounded,
                        label: restaurant.cuisine,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                // Menu search
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() =>
                      _menuQuery = v.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: 'Search menu…',
                    prefixIcon:
                        Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Menu
        menuAsync.when(
          data: (menu) => _buildMenu(context, menu),
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: QbLoading(message: 'Loading menu…'),
            ),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: QbErrorState(
                message: 'Could not load the menu.',
                onRetry: () => ref.invalidate(
                    restaurantMenuProvider(
                        (widget.restaurantId, 1))),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
        // Floating cart bar
        if (cart.items.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _FloatingCartBar(tokens: tokens),
          ),
      ],
    );
  }

  Widget _buildMenu(BuildContext context, RestaurantMenu menu) {
    final items = menu.items.where((item) {
      if (_menuQuery.isEmpty) return true;
      return item.name.toLowerCase().contains(_menuQuery) ||
          item.description
              .toLowerCase()
              .contains(_menuQuery);
    }).toList();

    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: QbEmptyState(
          icon: Icons.fastfood_outlined,
          title: 'No dishes found',
          message: _menuQuery.isEmpty
              ? 'This restaurant has no menu items right now.'
              : 'Try a different search term.',
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) => _MenuItemCard(
              item: items[i],
              restaurantId: widget.restaurantId),
          childCount: items.length,
        ),
      ),
    );
  }
}

class _BackBar extends StatelessWidget {
  final tokens;
  const _BackBar({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MetaChip(
      {required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16,
              color: color ??
                  Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color),
          const SizedBox(width: 6),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Menu item card with image, veg hint, price, and add/stepper.
class _MenuItemCard extends ConsumerWidget {
  final MenuItem item;
  final String restaurantId;

  const _MenuItemCard(
      {required this.item, required this.restaurantId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final cartItem = cart.items
        .where((c) => c.menuItem.id == item.id)
        .firstOrNull;
    final qty = cartItem?.quantity ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: QbCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            FoodImage(
              imageUrl: QuickBiteImages.forMenuItem(
                itemName: item.name,
                backendImageUrl: item.image,
              ),
              width: 96,
              height: 96,
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      VegBadge(isVeg: inferVeg(item.name)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(item.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium,
                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(item.description,
                      style:
                          Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(formatInr(item.priceMinor),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  fontWeight:
                                      FontWeight.w800)),
                      const Spacer(),
                      if (qty == 0)
                        _AddButton(
                            onPressed: () => ref
                                .read(cartProvider.notifier)
                                .addItem(
                                    item, restaurantId))
                      else
                        QbStepper(
                          quantity: qty,
                          onAdd: () => ref
                              .read(cartProvider.notifier)
                              .updateQuantity(
                                  item.id, qty + 1),
                          onRemove: () => ref
                              .read(cartProvider.notifier)
                              .updateQuantity(
                                  item.id, qty - 1),
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

class _AddButton extends ConsumerWidget {
  final VoidCallback onPressed;
  const _AddButton({required this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.primary,
        side: BorderSide(color: tokens.primary),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
      child: const Text('ADD',
          style: TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

/// Floating cart bar: appears when cart has items, shows count + total.
class _FloatingCartBar extends ConsumerWidget {
  final tokens;
  const _FloatingCartBar({required this.tokens});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final itemCount =
        cart.items.fold<int>(0, (sum, i) => sum + i.quantity);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(
        scale: value,
        child: child,
      ),
      child: GestureDetector(
        onTap: () => context.go('/cart'),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tokens.primary, tokens.primaryDark],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color:
                    tokens.primary.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$itemCount item${itemCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                cart.totalPrice,
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
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
