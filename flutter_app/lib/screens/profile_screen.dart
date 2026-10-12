import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/premium_widgets.dart';

/// Premium profile: user card, menu rows, logout with confirmation.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: currentUser == null
          ? EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Not signed in',
              message: 'Sign in to see your profile.',
              actionLabel: 'Sign in',
              onAction: () => context.go('/login'),
            )
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.all(AppTheme.spaceMd),
              child: Column(
                children: [
                  // User card
                  Container(
                    padding: const EdgeInsets.all(
                        AppTheme.spaceLg),
                    decoration: BoxDecoration(
                      gradient: AppTheme.brandGradient,
                      borderRadius: BorderRadius.circular(
                          AppTheme.radiusMd),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary
                              .withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: Colors.white
                                .withValues(alpha: 0.22),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            currentUser.name.isNotEmpty
                                ? currentUser.name[0]
                                    .toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(
                            width: AppTheme.spaceMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentUser.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentUser.email,
                                style: TextStyle(
                                  color: Colors.white
                                      .withValues(
                                          alpha: 0.85),
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  // Menu
                  Container(
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(
                          AppTheme.radiusMd),
                      boxShadow:
                          AppTheme.cardShadow(context),
                    ),
                    child: Column(
                      children: [
                        _menuRow(
                          context,
                          Icons.receipt_long_outlined,
                          'Order history',
                          'See past orders and reorder',
                          () => context.go('/orders'),
                        ),
                        Divider(
                            height: 1,
                            color: Theme.of(context)
                                .dividerColor),
                        _menuRow(
                          context,
                          Icons.notifications_outlined,
                          'Notifications',
                          'Order updates and offers',
                          () => _comingSoon(context),
                        ),
                        Divider(
                            height: 1,
                            color: Theme.of(context)
                                .dividerColor),
                        _menuRow(
                          context,
                          Icons.location_on_outlined,
                          'Addresses',
                          'Manage delivery addresses',
                          () => _comingSoon(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  // Logout
                  Container(
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(
                          AppTheme.radiusMd),
                      boxShadow:
                          AppTheme.cardShadow(context),
                    ),
                    child: _menuRow(
                      context,
                      Icons.logout_rounded,
                      'Sign out',
                      null,
                      () => _confirmLogout(context, ref),
                      destructive: true,
                    ),
                  ),
                  const SizedBox(
                      height: AppTheme.spaceXl),
                  Text(
                    'QuickBite v1.0.0',
                    style:
                        Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _ProfileNav(),
    );
  }

  Widget _menuRow(
    BuildContext context,
    IconData icon,
    String title,
    String? subtitle,
    VoidCallback onTap, {
    bool destructive = false,
  }) {
    final color =
        destructive ? AppTheme.danger : AppTheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceMd,
              vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                      AppTheme.radiusSm),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: destructive
                                  ? AppTheme.danger
                                  : null,
                            )),
                    if (subtitle != null)
                      Text(subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color),
            ],
          ),
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coming soon in a future update.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmLogout(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(AppTheme.radiusMd),
        ),
        title: const Text('Sign out?'),
        content: const Text(
            'You\'ll need to sign in again to order.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out',
                style:
                    TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }
  }
}

class _ProfileNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: 2,
      onDestinationSelected: (i) {
        switch (i) {
          case 0:
            context.go('/');
            break;
          case 1:
            context.go('/orders');
            break;
          case 2:
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
