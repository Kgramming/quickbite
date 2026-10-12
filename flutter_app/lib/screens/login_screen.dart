import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/premium_widgets.dart';

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
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(
        parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF2A1A14), AppTheme.darkBg]
                : [const Color(0xFFFFF1E8), AppTheme.lightBg],
            stops: const [0.0, 0.45],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppTheme.spaceXl),
                    // Brand mark
                    Center(
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          gradient: AppTheme.brandGradient,
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusLg),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary
                                  .withValues(alpha: 0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'QB',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLg),
                    Text(
                      'Welcome to QuickBite',
                      style: Theme.of(context).textTheme.displayMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spaceXs),
                    Text(
                      'Craving something delicious?\nSign in and let\'s fix that.',
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
                    const SizedBox(height: AppTheme.spaceXl),
                    // Email
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: InputDecoration(
                        hintText: 'Email address',
                        prefixIcon: const Icon(Icons.mail_outline_rounded),
                        errorText: _emailError,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
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
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLg),
                    PremiumButton(
                      label: 'Sign In',
                      icon: Icons.login_rounded,
                      isLoading: authState.isLoading,
                      onPressed:
                          authState.isLoading ? null : _validateAndLogin,
                    ),
                    if (authState.error != null) ...[
                      const SizedBox(height: AppTheme.spaceMd),
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spaceMd),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm),
                          border: Border.all(
                            color:
                                AppTheme.danger.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppTheme.danger, size: 20),
                            const SizedBox(width: AppTheme.spaceSm),
                            Expanded(
                              child: Text(
                                authState.error!,
                                style: const TextStyle(
                                    color: AppTheme.danger, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTheme.spaceXl),
                    // Demo hint
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMd,
                          vertical: AppTheme.spaceSm),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(
                            color: Theme.of(context).dividerColor),
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
                          const SizedBox(width: AppTheme.spaceXs),
                          Flexible(
                            child: Text(
                              'Demo: customer@example.com / customer123',
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLg),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
