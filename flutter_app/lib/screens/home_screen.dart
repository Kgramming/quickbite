import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../models/restaurant.dart';
import '../providers/auth_provider.dart';
import '../providers/restaurant_provider.dart';
import '../widgets/food_image.dart';
import '../widgets/premium_widgets.dart';

/// Premium home/discovery screen: greeting, search, cuisine filters,
/// featured restaurants and rich cards.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCuisine;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restaurantsAsync = ref.watch(restaurantsProvider(1));
    final cartCount = ref.watch(cartItemCountProvider);
    final user = ref.watch(authStateProvider).user;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Greeting + cart
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceMd, AppTheme.spaceMd,
                    AppTheme.spaceMd, AppTheme.spaceSm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.name ?? 'Food lover',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    _iconButton(
                      context,
                      Icons.shopping_bag_outlined,
                      () => context.go('/cart'),
                      badge: cartCount,
                    ),
                    const SizedBox(width: AppTheme.spaceSm),
                    _iconButton(
                      context,
                      Icons.person_outline_rounded,
                      () => context.go('/profile'),
                    ),
                  ],
                ),
              ),
            ),
            // Search
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMd,
                    vertical: AppTheme.spaceSm),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search restaurants or cuisines…',
                    prefixIcon:
                        const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),
            // Content
            restaurantsAsync.when(
              data: (page) =>
                  _buildContent(context, page),
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: RestaurantListSkeleton(),
              ),
              error: (err, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorCard(
                  message: 'Couldn\'t load restaurants.\n$err',
                  onRetry: () => ref.invalidate(restaurantsProvider(1)),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(currentIndex: 0),
    );
  }

  Widget _buildContent(BuildContext context, PaginatedRestaurants page) {
    final cuisines = _cuisinesOf(page.items);
    var filtered = page.items;
    if (_selectedCuisine != null) {
      filtered = filtered
          .where((r) => r.cuisine == _selectedCuisine)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((r) =>
              r.name.toLowerCase().contains(_searchQuery) ||
              r.cuisine.toLowerCase().contains(_searchQuery) ||
              r.description.toLowerCase().contains(_searchQuery))
          .toList();
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        // Cuisine filter chips
        if (cuisines.isNotEmpty)
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMd),
              itemCount: cuisines.length + 1,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppTheme.spaceSm),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _cuisineChip(context, null, 'All');
                }
                final c = cuisines[i - 1];
                return _cuisineChip(context, c, c);
              },
            ),
          ),
        const SizedBox(height: AppTheme.spaceSm),
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceMd),
          child: SectionHeader(
            title: _selectedCuisine ?? 'Popular near you',
          ),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        // Restaurant cards
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppTheme.spaceXl),
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matches',
              message:
                  'Try a different search or cuisine filter.',
            ),
          )
        else
          ...filtered.map((r) => Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceMd, 0,
                    AppTheme.spaceMd, AppTheme.spaceMd),
                child: _RestaurantCard(restaurant: r),
              )),
        const SizedBox(height: AppTheme.spaceMd),
      ]),
    );
  }

  List<String> _cuisinesOf(List<Restaurant> items) {
    final set = <String>{};
    for (final r in items) {
      if (r.cuisine.isNotEmpty) set.add(r.cuisine);
    }
    return set.toList()..sort();
  }

  Widget _cuisineChip(BuildContext context, String? value, String label) {
    final selected = _selectedCuisine == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) =>
          setState(() => _selectedCuisine = value),
      selectedColor: AppTheme.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : null,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _iconButton(BuildContext context, IconData icon,
      VoidCallback onTap, {int badge = 0}) {
    return Stack(
      children: [
        Material(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            onTap: onTap,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSm),
                border:
                    Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Icon(icon, size: 22),
            ),
          ),
        ),
        if (badge > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                  minWidth: 18, minHeight: 18),
              child: Text(
                '$badge',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning ☀️';
    if (h < 17) return 'Good afternoon 🌤️';
    return 'Good evening 🌙';
  }
}

class _RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;

  const _RestaurantCard({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: () =>
            context.go('/restaurant/${restaurant.id}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: AppTheme.cardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  FoodImage(
                    height: 148,
                    width: double.infinity,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppTheme.radiusMd),
                    ),
                    fallbackIcon: Icons.restaurant_rounded,
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: RatingBadge(
                        rating: restaurant.rating, large: true),
                  ),
                  if (!restaurant.isOpen)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius:
                              const BorderRadius.vertical(
                            top: Radius.circular(AppTheme.radiusMd),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Currently closed',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            restaurant.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            restaurant.cuisine,
                            style: const TextStyle(
                              color: AppTheme.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (restaurant.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        restaurant.description,
                        style:
                            Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppTheme.spaceSm),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 15,
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color),
                        const SizedBox(width: 4),
                        Text(
                          '${restaurant.deliveryTimeMinutes} min',
                          style:
                              Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: AppTheme.spaceMd),
                        Icon(Icons.delivery_dining_outlined,
                            size: 15,
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color),
                        const SizedBox(width: 4),
                        Text(
                          restaurant.deliveryFeeMinor == 0
                              ? 'Free delivery'
                              : restaurant.deliveryFee,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color:
                                    restaurant.deliveryFeeMinor == 0
                                        ? AppTheme.success
                                        : null,
                                fontWeight:
                                    restaurant.deliveryFeeMinor == 0
                                        ? FontWeight.w700
                                        : null,
                              ),
                        ),
                        const Spacer(),
                        const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: AppTheme.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared bottom navigation used by top-level screens.
class _BottomNav extends StatelessWidget {
  final int currentIndex;

  const _BottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (i) {
        if (i == currentIndex) return;
        switch (i) {
          case 0:
            context.go('/');
            break;
          case 1:
            context.go('/orders');
            break;
          case 2:
            context.go('/profile');
            break;
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long_rounded),
          label: 'Orders',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ],
    );
  }
}
