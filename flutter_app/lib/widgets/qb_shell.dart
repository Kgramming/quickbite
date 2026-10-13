import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_themes.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/restaurant_provider.dart';
import '../providers/theme_provider.dart';

/// Responsive app shell: sidebar on desktop, bottom nav on mobile.
///
/// Wraps the main tab screens (home, orders, profile). Cart is accessed
/// via the persistent badge button. Uses theme tokens throughout.
class QbShell extends ConsumerWidget {
  final Widget child;
  final String location;

  const QbShell({super.key, required this.child, required this.location});

  int get _selectedIndex {
    if (location.startsWith('/orders')) return 1;
    if (location.startsWith('/profile')) return 2;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
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
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              tokens: tokens,
              selectedIndex: _selectedIndex,
              onTap: (i) => _onTap(context, i),
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border(top: BorderSide(color: tokens.border)),
        ),
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  tokens: tokens,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  selected: _selectedIndex == 0,
                  onTap: () => _onTap(context, 0),
                ),
                _NavItem(
                  tokens: tokens,
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                  label: 'Orders',
                  selected: _selectedIndex == 1,
                  onTap: () => _onTap(context, 1),
                ),
                _CartNavItem(
                  tokens: tokens,
                  selected: false,
                  onTap: () => context.go('/cart'),
                ),
                _NavItem(
                  tokens: tokens,
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile',
                  selected: _selectedIndex == 2,
                  onTap: () => _onTap(context, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  final QuickBiteTokens tokens;
  final int selectedIndex;
  final void Function(int) onTap;

  const _Sidebar({
    required this.tokens,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartItemCountProvider);
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(right: BorderSide(color: tokens.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Brand
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tokens.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.lunch_dining_rounded,
                        color: tokens.onPrimary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('QuickBite',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                                fontWeight:
                                    FontWeight.w800),
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _SidebarItem(
                tokens: tokens,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Discover',
                selected: selectedIndex == 0,
                onTap: () => onTap(0),
              ),
              _SidebarItem(
                tokens: tokens,
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: 'My Orders',
                selected: selectedIndex == 1,
                onTap: () => onTap(1),
              ),
              _SidebarItem(
                tokens: tokens,
                icon: Icons.shopping_bag_outlined,
                activeIcon: Icons.shopping_bag_rounded,
                label: 'Cart',
                selected: false,
                badge: cartCount,
                onTap: () => context.go('/cart'),
              ),
              _SidebarItem(
                tokens: tokens,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                selected: selectedIndex == 2,
                onTap: () => onTap(2),
              ),
              // Admin link — visible only for admin users.
              if (ref.watch(authStateProvider).user?.role ==
                  UserRole.admin)
                _SidebarItem(
                  tokens: tokens,
                  icon: Icons.admin_panel_settings_outlined,
                  activeIcon:
                      Icons.admin_panel_settings_rounded,
                  label: 'Admin',
                  selected: false,
                  onTap: () => context.go('/admin'),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.accentSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.delivery_dining_rounded,
                        color: tokens.primary, size: 28),
                    const SizedBox(height: 8),
                    Text('Fast delivery',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'Hot and fresh, right to your door.',
                      style: Theme.of(context).textTheme.bodySmall,
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

class _SidebarItem extends StatelessWidget {
  final QuickBiteTokens tokens;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.tokens,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? tokens.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(selected ? activeIcon : icon,
                    color: selected ? tokens.primary : tokens.muted,
                    size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color:
                              selected ? tokens.primary : tokens.text)),
                ),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: tokens.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$badge',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: tokens.onPrimary)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final QuickBiteTokens tokens;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.tokens,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? tokens.primary : tokens.muted;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

class _CartNavItem extends ConsumerWidget {
  final QuickBiteTokens tokens;
  final bool selected;
  final VoidCallback onTap;

  const _CartNavItem({
    required this.tokens,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartItemCountProvider);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.shopping_bag_outlined,
                    color: tokens.muted, size: 24),
                if (count > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: tokens.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$count',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: tokens.onPrimary)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text('Cart',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: tokens.muted)),
          ],
        ),
      ),
    );
  }
}

/// Persistent cart button with badge for app bars.
class QbCartButton extends ConsumerWidget {
  const QbCartButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final count = ref.watch(cartItemCountProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(Icons.shopping_bag_outlined, color: tokens.text),
          onPressed: () => context.go('/cart'),
          tooltip: 'Cart',
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tokens.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: tokens.onPrimary)),
            ),
          ),
      ],
    );
  }
}
