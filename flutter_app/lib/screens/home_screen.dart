import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_themes.dart';
import '../config/food_images.dart';
import '../models/restaurant.dart';
import '../providers/auth_provider.dart';
import '../providers/restaurant_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/cart_helpers.dart';
import '../widgets/food_image.dart';
import '../widgets/qb_shell.dart';
import '../widgets/qb_widgets.dart';

/// Home / Discover screen — premium 10/10 edition.
///
/// - Animated hero with greeting + search
/// - Category pills with icons
/// - Auto-scrolling featured carousel
/// - Press-animated restaurant cards
/// - Shimmer loading states
///
/// Honest metadata policy: the backend does not provide ratings, cuisines,
/// or delivery estimates, so the UI never fabricates them.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  late AnimationController _heroController;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;

  static const _categories = [
    ('All', Icons.restaurant_rounded),
    ('Pizza', Icons.local_pizza_rounded),
    ('Burgers', Icons.lunch_dining_rounded),
    ('Sushi', Icons.set_meal_rounded),
    ('Desserts', Icons.icecream_rounded),
    ('Drinks', Icons.local_cafe_rounded),
  ];

  String? _precachedKey;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heroFade = CurvedAnimation(parent: _heroController, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _heroController, curve: Curves.easeOutCubic));
    _heroController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _heroController.dispose();
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
            child: RefreshIndicator(
              onRefresh: _refreshRestaurants,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Hero header ──
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _heroFade,
                      child: SlideTransition(
                        position: _heroSlide,
                        child: _HeroHeader(
                          tokens: tokens,
                          userName: user?.name ?? 'Food lover',
                          greeting: _greeting(),
                          onSurpriseMe: _openSurprise,
                        ),
                      ),
                    ),
                  ),
                  // ── Search ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: _SearchBar(
                        controller: _searchController,
                        onChanged: (v) => setState(
                            () => _searchQuery = v.trim().toLowerCase()),
                        onClear: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        hasQuery: _searchQuery.isNotEmpty,
                      ),
                    ),
                  ),
                  // ── Categories ──
                  if (_searchQuery.isEmpty)
                    SliverToBoxAdapter(
                      child: _CategoryPills(
                        categories: _categories,
                        selected: _selectedCategory,
                        tokens: tokens,
                        onSelect: (c) => setState(() => _selectedCategory = c),
                      ),
                    ),
                  // ── Content ──
                  restaurantsAsync.when(
                    data: (page) => _buildContent(context, tokens, page),
                    loading: () => const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ShimmerGrid(),
                    ),
                    error: (e, _) => SliverFillRemaining(
                      hasScrollBody: false,
                      child: QbErrorState(
                        message:
                            'Could not load restaurants. Check your connection and try again.',
                        onRetry: () => ref.invalidate(restaurantsProvider(1)),
                      ),
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

  /// Opens the "Surprise me" random dish picker.
  void _openSurprise() {
    final page = ref.read(restaurantsProvider(1)).valueOrNull;
    if (page == null || page.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Restaurants are still loading — try again in a moment.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SurpriseSheet(restaurants: page.items),
    );
  }

  Future<void> _refreshRestaurants() async {
    ref.invalidate(restaurantsProvider(1));
    // Await the refetch so the indicator dismisses once fresh data
    // (or a rendered error) is in place.
    try {
      await ref.read(restaurantsProvider(1).future);
    } catch (_) {      // The error state is rendered by the AsyncValue in build().
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildContent(
      BuildContext context, QuickBiteTokens tokens, PaginatedRestaurants page) {
    var restaurants = page.items.where((r) {
      if (_searchQuery.isNotEmpty) {
        return r.name.toLowerCase().contains(_searchQuery) ||
            r.description.toLowerCase().contains(_searchQuery);
      }
      if (_selectedCategory != 'All') {
        return r.name.toLowerCase().contains(_selectedCategory.toLowerCase()) ||
            r.description
                .toLowerCase()
                .contains(_selectedCategory.toLowerCase());
      }
      return true;
    }).toList();

    // Warm the image cache for the first cards so scrolling doesn't trigger
    // decode jank one card at a time. Runs once per data set; the provider
    // below matches the one the cards render with, so cache entries are
    // shared.
    final cacheKey = page.items.map((r) => r.id).join(',');
    if (cacheKey != _precachedKey) {
      _precachedKey = cacheKey;
      final urls = restaurants
          .take(6)
          .map((r) => QuickBiteImages.forRestaurant(
                restaurantId: r.id,
                restaurantName: r.name,
                backendImageUrl: r.imageUrl,
                w: 600,
              ))
          .toList();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final url in urls) {
          precacheImage(
            QuickBiteImages.imageProvider(url, cacheWidth: 600),
            context,
          );
        }
      });
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        // Featured carousel
        if (_searchQuery.isEmpty && restaurants.length > 1)
          _FeaturedCarousel(
            tokens: tokens,
            restaurants: restaurants.take(5).toList(),
          ),

        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              QbSectionHeader(
                title: _searchQuery.isEmpty
                    ? (_selectedCategory == 'All'
                        ? 'All restaurants'
                        : _selectedCategory)
                    : '${restaurants.length} result${restaurants.length == 1 ? '' : 's'}',
              ),
              const Spacer(),
              if (restaurants.isNotEmpty)
                Text(
                  '${restaurants.length} places',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),

        // Restaurant grid with staggered entrance
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 900
                    ? 3
                    : constraints.maxWidth > 600
                        ? 2
                        : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 1.12,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: restaurants.length,
                  itemBuilder: (context, i) => _StaggeredCard(
                    delay: (i % 6) * 70,
                    child: _RestaurantCard(restaurant: restaurants[i]),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 32),
      ]),
    );
  }
}

/// Hero header with gradient, greeting, and cart.
class _HeroHeader extends StatelessWidget {
  final QuickBiteTokens tokens;
  final String userName;
  final String greeting;
  final VoidCallback onSurpriseMe;

  const _HeroHeader({
    required this.tokens,
    required this.userName,
    required this.greeting,
    required this.onSurpriseMe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tokens.primary, tokens.primaryDark],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: tokens.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('👋 ', style: const TextStyle(fontSize: 14)),
                    Text(
                      greeting,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'What are you craving today?',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onSurpriseMe,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.casino_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Surprise me',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const QbCartButton(),
        ],
      ),
    );
  }
}

/// Premium floating search bar.
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool hasQuery;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.hasQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search restaurants or dishes…',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: hasQuery
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        ),
      ),
    );
  }
}

/// Horizontal category pills.
class _CategoryPills extends StatelessWidget {
  final List<(String, IconData)> categories;
  final String selected;
  final QuickBiteTokens tokens;
  final ValueChanged<String> onSelect;

  const _CategoryPills({
    required this.categories,
    required this.selected,
    required this.tokens,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (label, icon) = categories[i];
          final isSelected = label == selected;
          return _Pressable(
            onTap: () => onSelect(label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color:
                    isSelected ? tokens.primary : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected
                      ? tokens.primary
                      : Theme.of(context).dividerColor,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: tokens.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 18,
                      color: isSelected ? Colors.white : tokens.primary),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Auto-scrolling featured carousel.
class _FeaturedCarousel extends StatefulWidget {
  final QuickBiteTokens tokens;
  final List<Restaurant> restaurants;

  const _FeaturedCarousel({required this.tokens, required this.restaurants});

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel> {
  late PageController _controller;
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || widget.restaurants.length < 2) return;
      _current = (_current + 1) % widget.restaurants.length;
      _controller.animateToPage(
        _current,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: widget.restaurants.length,
            itemBuilder: (context, i) {
              final r = widget.restaurants[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _FeaturedCard(tokens: widget.tokens, restaurant: r),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < widget.restaurants.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _current ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _current
                      ? widget.tokens.primary
                      : widget.tokens.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final QuickBiteTokens tokens;
  final Restaurant restaurant;

  const _FeaturedCard({required this.tokens, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: () => context.go('/restaurant/${restaurant.id}'),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          image: DecorationImage(
            image: QuickBiteImages.imageProvider(
              QuickBiteImages.forRestaurant(
                restaurantId: restaurant.id,
                restaurantName: restaurant.name,
                backendImageUrl: restaurant.imageUrl,
              ),
              cacheWidth: 800,
            ),
            fit: BoxFit.cover,
            onError: (_, __) {},
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.78),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: const Text('✨ FEATURED',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.white)),
                ),
                const SizedBox(height: 8),
                Text(restaurant.name,
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5)),
                Text(restaurant.description,
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pressable wrapper: scales down on tap for tactile feedback.
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _Pressable({required this.child, required this.onTap});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// Staggered card entrance.
class _StaggeredCard extends StatefulWidget {
  final int delay;
  final Widget child;

  const _StaggeredCard({required this.delay, required this.child});

  @override
  State<_StaggeredCard> createState() => _StaggeredCardState();
}

class _StaggeredCardState extends State<_StaggeredCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.12),
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

/// Shimmer loading grid.
class _ShimmerGrid extends StatefulWidget {
  const _ShimmerGrid();

  @override
  State<_ShimmerGrid> createState() => _ShimmerGridState();
}

class _ShimmerGridState extends State<_ShimmerGrid>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
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
        final alpha = 0.3 + _controller.value * 0.4;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.12,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: 6,
            itemBuilder: (_, __) => Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withValues(alpha: alpha),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Restaurant card with press animation and honest metadata.
class _RestaurantCard extends ConsumerWidget {
  final Restaurant restaurant;

  const _RestaurantCard({required this.restaurant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    return _Pressable(
      onTap: () => context.go('/restaurant/${restaurant.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image with overlay gradient
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FoodImage(
                      imageUrl: QuickBiteImages.forRestaurant(
                        restaurantId: restaurant.id,
                        restaurantName: restaurant.name,
                        backendImageUrl: restaurant.imageUrl,
                        w: 600,
                      ),
                      width: double.infinity,
                      borderRadius: BorderRadius.zero,
                      cacheWidth: 600,
                    ),
                    // Rating badge
                    if (restaurant.hasRating)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 14, color: Colors.amber),
                              const SizedBox(width: 3),
                              Text(restaurant.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(restaurant.name,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(restaurant.description,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (restaurant.hasDeliveryEstimate) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.delivery_dining_outlined,
                              size: 14, color: tokens.primary),
                          const SizedBox(width: 4),
                          Text('${restaurant.deliveryTimeMinutes} min',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: tokens.primary,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Surprise me" bottom sheet: a slot-machine style random dish picker.
///
/// Picks a random restaurant, loads its real menu, then cycles through
/// dishes with a playful animation before landing on one. Add to cart
/// respects the single-restaurant cart rule.
class _SurpriseSheet extends ConsumerStatefulWidget {
  final List<Restaurant> restaurants;
  const _SurpriseSheet({required this.restaurants});

  @override
  ConsumerState<_SurpriseSheet> createState() => _SurpriseSheetState();
}

class _SurpriseSheetState extends ConsumerState<_SurpriseSheet> {
  final _random = Random();
  Restaurant? _restaurant;
  List<MenuItem> _menuItems = const [];
  int _displayIndex = 0;
  bool _loading = true;
  bool _shuffling = false;
  Timer? _timer;
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    _shuffle();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _shuffle() async {
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _shuffling = false;
    });
    try {
      final restaurant =
          widget.restaurants[_random.nextInt(widget.restaurants.length)];
      final menu = await ref.read(
          restaurantMenuProvider((restaurant.id, 1)).future);
      if (!mounted) return;
      if (menu.items.isEmpty) {
        _shuffle();
        return;
      }
      setState(() {
        _restaurant = restaurant;
        _menuItems = menu.items;
        _loading = false;
        _shuffling = true;
        _ticks = 0;
        _displayIndex = _random.nextInt(menu.items.length);
      });
      _timer = Timer.periodic(const Duration(milliseconds: 90), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          _ticks++;
          _displayIndex = _random.nextInt(_menuItems.length);
          if (_ticks >= 14) {
            t.cancel();
            _shuffling = false;
          }
        });
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addToCart() async {
    final restaurant = _restaurant;
    if (restaurant == null || _menuItems.isEmpty || _shuffling) return;
    final item = _menuItems[_displayIndex];
    final ok = await ensureSingleRestaurantCart(
      context,
      ref,
      restaurant.id,
      restaurantName: restaurant.name,
    );
    if (!ok || !mounted) return;
    ref.read(cartProvider.notifier).addItem(
          item,
          restaurant.id,
          restaurantName: restaurant.name,
        );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.name} added to cart')),
    );
    context.go('/cart');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color:
                    Theme.of(context).dividerColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.casino_rounded,
                    color: tokens.primary, size: 22),
                const SizedBox(width: 8),
                Text("Chef's surprise",
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_menuItems.isEmpty)
              const SizedBox(
                height: 220,
                child: Center(
                    child: Text('No dishes found — try again.')),
              )
            else
              _buildDishCard(tokens),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shuffling || _loading ? null : _shuffle,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Shuffle again'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: QbPrimaryButton(
                    label: _shuffling ? 'Picking…' : 'Add to cart',
                    icon: Icons.add_shopping_cart_rounded,
                    onPressed:
                        _shuffling || _loading ? null : _addToCart,
                    expanded: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDishCard(QuickBiteTokens tokens) {
    final item = _menuItems[_displayIndex];
    final restaurant = _restaurant!;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 110),
      child: Container(
        key: ValueKey(_displayIndex),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FoodImage(
                imageUrl: QuickBiteImages.forMenuItem(
                  itemName: item.name,
                  itemId: item.id,
                  backendImageUrl: item.image,
                ),
                width: double.infinity,
                height: 160,
                cacheWidth: 600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.name,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'from ${restaurant.name}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: tokens.primary),
            ),
            const SizedBox(height: 6),
            Text(
              _formatInr(item.priceMinor),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  String _formatInr(int minor) {
    return '₹${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';
  }
}
