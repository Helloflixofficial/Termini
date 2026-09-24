import 'dart:async';
import 'dart:math' as math;
import 'package:app_links/app_links.dart';
import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'clerk_user_bridge.dart';

/// Ultra-modern, premium authentication screen powered by official Clerk SDK.
/// Seamlessly handles:
/// - "Continue with Google" (login if account exists, create if not)
/// - "Continue with GitHub" (login if account exists, create if not)
/// - Email & Password Sign In / Sign Up
/// - Automatic Riverpod session synchronization via [ClerkUserBridge]
class ClerkAuthScreen extends ConsumerStatefulWidget {
  const ClerkAuthScreen({super.key});

  @override
  ConsumerState<ClerkAuthScreen> createState() => _ClerkAuthScreenState();
}

class _ClerkAuthScreenState extends ConsumerState<ClerkAuthScreen> {
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _setupDeepLinkListener();
  }

  void _setupDeepLinkListener() {
    _linkSub = AppLinks().uriLinkStream.listen((uri) async {
      debugPrint('[ClerkAuthScreen] Deep link arrived: $uri');
      if (uri.scheme == 'termini' || uri.scheme == 'com.clerk.flutter') {
        if (!mounted) return;
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });

        try {
          final authState = ClerkAuth.of(context);
          await authState.parseDeepLink(uri);
          if (authState.signIn?.isTransferable == true ||
              authState.signUp?.isTransferable == true) {
            await authState.transfer();
          }
          await authState.refreshClient();
        } catch (e) {
          debugPrint('[ClerkAuthScreen] Deep link processing error: $e');
        } finally {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      }
    }, onError: (err) {
      debugPrint('[ClerkAuthScreen] Deep link stream error: $err');
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  /// Official Clerk OAuth flow — opens the SYSTEM BROWSER (Chrome) so the user can
  /// pick an already signed-in Google / GitHub account without re-entering credentials.
  Future<void> _handleOAuth(BuildContext context, clerk.Strategy strategy) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authState = ClerkAuth.of(context);

      // Attempt Clerk's SSO flow which opens Chrome (external browser)
      await authState.ssoSignIn(
        context,
        strategy,
        launchMode: LaunchMode.externalApplication,
      );

      // Handle new-user transfer if already prepared
      if (authState.signIn?.isTransferable == true ||
          authState.signUp?.isTransferable == true) {
        await authState.transfer();
      }
    } on clerk.ClerkError catch (e) {
      // If Clerk throws an error with a redirect URL, open it in browser
      final msg = e.toString();
      final urlMatch = RegExp(r'https?://[^\s"]+').firstMatch(msg);
      if (urlMatch != null) {
        final uri = Uri.tryParse(urlMatch.group(0)!);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else if (mounted) {
        setState(() {
          _errorMessage = msg.replaceFirst(RegExp(r'^[A-Za-z]+Exception:\s*'), '');
        });
      }
    } catch (e) {
      // Attempt to parse any URL from the error and open browser
      final msg = e.toString();
      final urlMatch = RegExp(r'https?://[^\s"]+').firstMatch(msg);
      if (urlMatch != null) {
        final uri = Uri.tryParse(urlMatch.group(0)!);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }
      if (mounted) {
        setState(() {
          _errorMessage = msg.replaceFirst(RegExp(r'^[A-Za-z]+Exception:\s*'), '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Official Clerk Email/Password flow
  Future<void> _handleEmailAuth(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authState = ClerkAuth.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_isSignUp) {
        await authState.attemptSignUp(
          strategy: clerk.Strategy.password,
          emailAddress: email,
          password: password,
          passwordConfirmation: password,
          firstName: _firstNameController.text.trim().isNotEmpty
              ? _firstNameController.text.trim()
              : null,
          lastName: _lastNameController.text.trim().isNotEmpty
              ? _lastNameController.text.trim()
              : null,
        );
        if (authState.signUp?.isTransferable == true) {
          await authState.transfer();
        }
      } else {
        await authState.attemptSignIn(
          strategy: clerk.Strategy.password,
          identifier: email,
          password: password,
        );
        if (authState.signIn?.isTransferable == true) {
          await authState.transfer();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst(RegExp(r'^[A-Za-z]+Exception:\s*'), '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      body: ClerkAuthBuilder(
        // When authenticated, bridge user into Riverpod and go straight to Dashboard
        signedInBuilder: (context, authState) {
          return ClerkUserBridge(
            authState: authState,
            onUserReady: () {
              if (mounted) context.go('/');
            },
          );
        },
        signedOutBuilder: (context, authState) {
          return Stack(
            children: [
              // Ambient glowing background orbs
              Positioned(
                top: -80,
                right: -60,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF6366F1).withValues(alpha: isDark ? 0.28 : 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 240,
                left: -80,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF06B6D4).withValues(alpha: isDark ? 0.20 : 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Main content
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Brand Header ──
                          _buildBrandHeader(isDark),
                          const SizedBox(height: 28),

                          // ── Auth Glass Card ──
                          _buildAuthCard(context, isDark),
                          const SizedBox(height: 24),

                          // ── Security Footer ──
                          _buildSecurityFooter(isDark),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Full-screen loading overlay when authenticating
              if (_isLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF6366F1),
                      strokeWidth: 3,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBrandHeader(bool isDark) {
    return Column(
      children: [
        // App Icon with glowing border
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'TERMINI',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.5,
            color: Color(0xFF6366F1),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Next-Gen Learning Management Platform',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.black54,
            letterSpacing: 0.3,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF131927).withValues(alpha: 0.85)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tab switcher: Sign In vs Sign Up
            _buildTabSwitcher(isDark),
            const SizedBox(height: 22),

            // Title & Subtitle
            Text(
              _isSignUp ? 'Create your account' : 'Welcome back',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isSignUp
                  ? 'Join thousands of learners and instructors today'
                  : 'Sign in to continue your learning journey',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),

            // Error banner if any
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Primary Social Buttons ──
            // Continue with Google
            _SocialButton(
              label: 'Continue with Google',
              iconWidget: const _GoogleLogoWidget(size: 20),
              backgroundColor: isDark ? Colors.white : Colors.white,
              textColor: const Color(0xFF1F2937),
              borderColor: const Color(0xFFE5E7EB),
              onTap: _isLoading
                  ? null
                  : () => _handleOAuth(context, clerk.Strategy.oauthGoogle),
            ),
            const SizedBox(height: 12),

            // Continue with GitHub
            _SocialButton(
              label: 'Continue with GitHub',
              iconWidget: Icon(
                Icons.code_rounded,
                size: 20,
                color: isDark ? Colors.white : Colors.white,
              ),
              backgroundColor: const Color(0xFF1E232A),
              textColor: Colors.white,
              borderColor: isDark ? Colors.white12 : Colors.transparent,
              onTap: _isLoading
                  ? null
                  : () => _handleOAuth(context, clerk.Strategy.oauthGithub),
            ),
            const SizedBox(height: 22),

            // ── Divider ──
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR CONTINUE WITH EMAIL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // First & Last Name if Sign Up
            if (_isSignUp) ...[
              Row(
                children: [
                  Expanded(
                    child: _InputField(
                      controller: _firstNameController,
                      hintText: 'First name',
                      prefixIcon: Icons.person_outline_rounded,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InputField(
                      controller: _lastNameController,
                      hintText: 'Last name',
                      prefixIcon: Icons.person_outline_rounded,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // Email Field
            _InputField(
              controller: _emailController,
              hintText: 'Email address',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.mail_outline_rounded,
              isDark: isDark,
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Email is required';
                if (!val.contains('@') || !val.contains('.')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Password Field
            _InputField(
              controller: _passwordController,
              hintText: 'Password',
              obscureText: _obscurePassword,
              prefixIcon: Icons.lock_outline_rounded,
              isDark: isDark,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 19,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Password is required';
                if (val.length < 8) return 'Password must be at least 8 characters';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Primary Submit Button
            _GradientButton(
              label: _isSignUp ? 'Create Free Account' : 'Sign In',
              isLoading: _isLoading,
              onPressed: () => _handleEmailAuth(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSwitcher(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D121F) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'Sign In',
              isActive: !_isSignUp,
              isDark: isDark,
              onTap: () {
                if (_isSignUp) setState(() => _isSignUp = false);
              },
            ),
          ),
          Expanded(
            child: _TabButton(
              label: 'Create Account',
              isActive: _isSignUp,
              isDark: isDark,
              onTap: () {
                if (!_isSignUp) setState(() => _isSignUp = true);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityFooter(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: 15,
          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 6),
        Text(
          'Secured by Clerk • 256-bit SSL encryption',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}

// ── Tab Button ────────────────────────────────────────────────────────────────

class _TabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? const Color(0xFF1E2638) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive
                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                  : (isDark ? Colors.white54 : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Social Button ─────────────────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget iconWidget;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final VoidCallback? onTap;

  const _SocialButton({
    required this.label,
    required this.iconWidget,
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 50,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget,
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Google Logo Vector ────────────────────────────────────────────────────────

class _GoogleLogoWidget extends StatelessWidget {
  final double size;
  const _GoogleLogoWidget({this.size = 20});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.22;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    // Red arc (top)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -math.pi * 0.75, math.pi * 0.5, false, paint);

    // Yellow arc (left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -math.pi * 1.25, math.pi * 0.5, false, paint);

    // Green arc (bottom)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, -math.pi * 1.75, math.pi * 0.5, false, paint);

    // Blue arc & bar (right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -math.pi * 0.25, math.pi * 0.5, false, paint);

    // Horizontal bar for 'G'
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final barRect = Rect.fromLTWH(
      center.dx - 1,
      center.dy - strokeWidth / 2,
      radius + 1,
      strokeWidth,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(barRect, const Radius.circular(2)), barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Input Field ───────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final bool isDark;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    required this.isDark,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontSize: 14,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          fontSize: 13.5,
          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
        ),
        prefixIcon: Icon(
          prefixIcon,
          size: 19,
          color: isDark ? Colors.white54 : const Color(0xFF64748B),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? const Color(0xFF0D121F) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFF6366F1),
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}

// ── Gradient Button ───────────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const _GradientButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
