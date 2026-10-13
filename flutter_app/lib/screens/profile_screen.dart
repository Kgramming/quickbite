import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_themes.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/qb_widgets.dart';

/// Profile & settings screen.
///
/// Shows authenticated user info, the theme selector (Ember / Saffron /
/// Midnight), and logout. Theme switching is instant and preserves auth,
/// cart, and navigation state.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // User card
              QbCard(
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: tokens.accentSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person_rounded,
                          size: 32, color: tokens.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(user?.name ?? 'Guest',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge),
                          const SizedBox(height: 4),
                          Text(user?.email ?? '',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Theme selector
              Text('Appearance',
                  style:
                      Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Pick a theme. Your cart and session are preserved.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final mode in QuickBiteThemeMode.values)
                _ThemeOption(mode: mode),
              const SizedBox(height: 24),

              // Account
              Text('Account',
                  style:
                      Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              QbCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _MenuTile(
                      icon: Icons.receipt_long_outlined,
                      label: 'My orders',
                      onTap: () => context.go('/orders'),
                    ),
                    Divider(
                        height: 1,
                        indent: 56,
                        color: tokens.border),
                    _MenuTile(
                      icon: Icons.shopping_bag_outlined,
                      label: 'My cart',
                      onTap: () => context.go('/cart'),
                    ),
                    // Admin entry — visible only for admin users.
                    if (user?.role == UserRole.admin) ...[
                      Divider(
                          height: 1,
                          indent: 56,
                          color: tokens.border),
                      _MenuTile(
                        icon:
                            Icons.admin_panel_settings_outlined,
                        label: 'Admin overview',
                        onTap: () => context.go('/admin'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Logout
              QbPrimaryButton(
                label: 'Log out',
                icon: Icons.logout_rounded,
                onPressed: () async {
                  await ref
                      .read(authStateProvider.notifier)
                      .logout();
                  if (context.mounted) context.go('/login');
                },
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'QuickBite v1.0',
                  style:
                      Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selectable theme row with live color preview.
class _ThemeOption extends ConsumerWidget {
  final QuickBiteThemeMode mode;
  const _ThemeOption({required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);
    final selected = current == mode;
    final preview = QuickBiteThemes.of(mode);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: QbCard(
        onTap: () =>
            ref.read(themeModeProvider.notifier).setTheme(mode),
        child: Row(
          children: [
            // Color preview dots
            Row(
              children: [
                _Dot(color: preview.primary),
                _Dot(color: preview.accent),
                _Dot(color: preview.surfaceAlt),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(mode.label,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                              fontWeight: FontWeight.w700)),
                  Text(mode.description,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded,
                  color: preview.primary, size: 26)
            else
              Icon(Icons.circle_outlined,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
            color: Theme.of(context).dividerColor),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon,
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color),
            const SizedBox(width: 14),
            Expanded(
                child: Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge)),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
