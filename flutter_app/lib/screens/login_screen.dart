import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/premium_widgets.dart';

/// Demo credentials shown prefilled on the login form.
/// These are development-only credentials from the backend seed data.
const String _demoEmail = 'customer@example.com';
const String _demoPassword = 'customer123';
const String _adminEmail = 'admin@example.com';
const String _adminPassword = 'admin123';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  String? _emailError;
  String? _passwordError;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Prefill demo credentials so the user can sign in with one tap.
    // Password stays masked; the eye toggle reveals it.
    _emailController = TextEditingController(text: _demoEmail);
    _passwordController = TextEditingController(text: _demoPassword);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _fillCredentials(String email, String password) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = password;
      _emailError = null;
      _passwordError = null;
    });
  }

  void _validateAndLogin() {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = 'Email is required');
      return;
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      setState(() => _emailError = 'Enter a valid email address');
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _passwordError = 'Password is required');
      return;
    }
    if (_passwordController.text.length < 6) {
      setState(() => _passwordError = 'Password must be at least 6 characters');
      return;
    }
    _login();
  }

  Future<void> _login() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();
    try {
      await ref.read(authStateProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) context.go('/');
    } catch (_) {
      // The error is already stored in authStateProvider and shown inline
      // in the card below. No snackbar: avoids duplicate raw error dumps.
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              tokens.accentSoft,
              tokens.background,
            ],
            stops: const [0.0, 0.45],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 36),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Brand mark
                          Center(
                            child: Container(
                              width: 72,
                              height: 72,
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
                                        tokens.primary.withValues(alpha: 0.35),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  'QB',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Welcome to QuickBite',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sign in to order your favorites.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          // Email
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: InputDecoration(
                              hintText: 'Email address',
                              prefixIcon:
                                  const Icon(Icons.mail_outline_rounded),
                              errorText: _emailError,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Password
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _validateAndLogin(),
                            decoration: InputDecoration(
                              hintText: 'Password',
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded),
                              errorText: _passwordError,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          PremiumButton(
                            label: 'Sign In',
                            icon: Icons.login_rounded,
                            isLoading: authState.isLoading,
                            onPressed:
                                authState.isLoading ? null : _validateAndLogin,
                          ),
                          // Inline error — single, compact, no raw dumps.
                          if (authState.error != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: tokens.danger.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: tokens.danger.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.error_outline_rounded,
                                      color: tokens.danger, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      authState.error!,
                                      style: TextStyle(
                                          color: tokens.danger,
                                          fontSize: 13,
                                          height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          // Demo hint
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: tokens.accentSoft.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 16,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Demo credentials are prefilled — just tap Sign In.',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Quick-fill login chips: customer vs admin
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _LoginChip(
                                icon: Icons.person_outline_rounded,
                                label: 'Customer login',
                                selected: _emailController.text ==
                                    _demoEmail,
                                onTap: () => _fillCredentials(
                                    _demoEmail, _demoPassword),
                              ),
                              const SizedBox(width: 8),
                              _LoginChip(
                                icon:
                                    Icons.admin_panel_settings_outlined,
                                label: 'Admin login',
                                selected: _emailController.text ==
                                    _adminEmail,
                                onTap: () => _fillCredentials(
                                    _adminEmail, _adminPassword),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small tappable chip that fills the login form with a demo account.
class _LoginChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LoginChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? scheme.primary
                : scheme.outline.withValues(alpha: 0.5),
            width: selected ? 1.5 : 1,
          ),
          color: selected
              ? scheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected
                    ? scheme.primary
                    : Theme.of(context).textTheme.bodySmall?.color),
            const SizedBox(width: 6),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: selected ? scheme.primary : null,
                    )),
          ],
        ),
      ),
    );
  }
}
