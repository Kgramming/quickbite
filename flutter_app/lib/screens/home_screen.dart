import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_themes.dart';
import '../config/food_images.dart';
import '../models/restaurant.dart';
import '../providers/auth_provider.dart';
import '../providers/restaurant_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/food_image.dart';
import '../widgets/qb_shell.dart';
import '../widgets/qb_widgets.dart';

/// Home / Discover screen.
///
/// Honest metadata policy: the backend does not provide ratings, cuisines,
/// or delivery estimates, so the UI never fabricates them. Cards show the
/// restaurant name, real description, and imagery only.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final restaurantsAsync = ref.watch(restaurantsProvider(1));
    final user = ref.watch(authStateProvider).user;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
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
                        const QbCartButton(),
                      ],
                    ),
                  ),
                ),
                // Search
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(
                          () => _searchQuery = v.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText:
                            'Search restaurants or dishes…',
                        prefixIcon:
                            const Icon(Icons.search_rounded),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                    Icons.clear_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(
                                      () => _searchQuery = '');
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
                      _buildContent(context, tokens, page),
                  loading: () => const SliverFillRemaining(
                    hasScrollBody: false,
                    child: QbLoading(
                        message: 'Finding great food near you…'),
                  ),
                  error: (e, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: QbErrorState(
                      message:
                          'Could not load restaurants. Check your connection and try again.',
                      onRetry: () =>
                          ref.invalidate(restaurantsProvider(1)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildContent(
      BuildContext context, QuickBiteTokens tokens, PaginatedRestaurants page) {
    final restaurants = page.items.where((r) {
      if (_searchQuery.isEmpty) return true;
      return r.name.toLowerCase().contains(_searchQuery) ||
          r.description.toLowerCase().contains(_searchQuery);
    }).toList();

    return SliverList(
      delegate: SliverChildListDelegate([
        // Featured banner
        if (_searchQuery.isEmpty && restaurants.isNotEmpty)
          _FeaturedBanner(
              tokens: tokens, restaurant: restaurants.first),

        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: QbSectionHeader(
            title: _searchQuery.isEmpty
                ? 'All restaurants'
                : '${restaurants.length} result${restaurants.length == 1 ? '' : 's'}',
          ),
        ),

        // Restaurant grid
        if (restaurants.isEmpty)
          QbEmptyState(
            icon: Icons.search_off_rounded,
            title: 'No restaurants found',
            message: _searchQuery.isEmpty
                ? 'There are no restaurants available right now.'
                : 'Try a different search term.',
          )
        else
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount =
                    constraints.maxWidth > 900
                        ? 3
                        : constraints.maxWidth > 600
                            ? 2
                            : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 1.15,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: restaurants.length,
                  itemBuilder: (context, i) =>
                      _RestaurantCard(
                          restaurant: restaurants[i]),
                );
              },
            ),
          ),
        const SizedBox(height: 32),
      ]),
    );
  }
}

/// Featured restaurant hero banner.
class _FeaturedBanner extends StatelessWidget {
  final QuickBiteTokens tokens;
  final Restaurant restaurant;

  const _FeaturedBanner(
      {required this.tokens, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () =>
            context.go('/restaurant/${restaurant.id}'),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            image: DecorationImage(
              image: NetworkImage(
                QuickBiteImages.forRestaurant(
                  restaurantId: restaurant.id,
                  restaurantName: restaurant.name,
                  backendImageUrl: restaurant.imageUrl,
                ),
              ),
              fit: BoxFit.cover,
              onError: (_, __) {},
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.75),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: tokens.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('FEATURED',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: tokens.onPrimary)),
                  ),
                  const SizedBox(height: 8),
                  Text(restaurant.name,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  Text(restaurant.description,
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.white
                              .withValues(alpha: 0.85)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Restaurant card with honest metadata (no fake ratings).
class _RestaurantCard extends ConsumerWidget {
  final Restaurant restaurant;

  const _RestaurantCard({required this.restaurant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    return QbCard(
      padding: EdgeInsets.zero,
      onTap: () => context.go('/restaurant/${restaurant.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: FoodImage(
                imageUrl: QuickBiteImages.forRestaurant(
                  restaurantId: restaurant.id,
                  restaurantName: restaurant.name,
                  backendImageUrl: restaurant.imageUrl,
                ),
                width: double.infinity,
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(restaurant.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(restaurant.description,
                      style:
                          Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  // Only show rating if the backend provided one.
                  if (restaurant.hasRating)
                    Row(
                      children: [
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3),
                          decoration: BoxDecoration(
                            color: tokens.success,
                            borderRadius:
                                BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 14,
                                  color: Colors.white),
                              const SizedBox(width: 2),
                              Text(
                                  restaurant.rating
                                      .toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w700,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                        if (restaurant
                            .hasDeliveryEstimate) ...[
                          const SizedBox(width: 8),
                          Icon(
                              Icons
                                  .delivery_dining_outlined,
                              size: 16,
                              color: tokens.muted),
                          const SizedBox(width: 4),
                          Text(
                              '${restaurant.deliveryTimeMinutes} min',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall),
                        ],
                      ],
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
