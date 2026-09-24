import 'dart:async';
import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/user_entity.dart';
import 'auth_controller.dart';

/// Bridges a Clerk signed-in [ClerkAuthState] into our Riverpod auth state.
/// Resolves the Clerk user, persists the session, and navigates straight to Dashboard.
class ClerkUserBridge extends ConsumerStatefulWidget {
  final ClerkAuthState authState;
  final VoidCallback onUserReady;

  const ClerkUserBridge({
    super.key,
    required this.authState,
    required this.onUserReady,
  });

  @override
  ConsumerState<ClerkUserBridge> createState() => _ClerkUserBridgeState();
}

class _ClerkUserBridgeState extends ConsumerState<ClerkUserBridge> {
  bool _syncing = false;
  bool _completed = false;
  bool _showManualButton = false;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    // After 2.5 seconds, if still resolving, show manual dashboard button so user is never trapped
    _fallbackTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && !_completed) {
        setState(() => _showManualButton = true);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveAndNavigate();
    });
  }

  @override
  void didUpdateWidget(covariant ClerkUserBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_completed && !_syncing) {
      _resolveAndNavigate();
    }
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _resolveAndNavigate() async {
    if (_syncing || _completed) return;
    _syncing = true;

    clerk.User? clerkUser;
    
    if (widget.authState.signIn?.isTransferable == true ||
        widget.authState.signUp?.isTransferable == true) {
      try {
        await widget.authState.transfer();
        await widget.authState.refreshClient();
      } catch (_) {}
    }

    // Poll up to 10 times (3s max) to get the user object from Clerk session/client
    for (var i = 0; i < 10; i++) {
      clerkUser = widget.authState.user ?? 
                  widget.authState.session?.user ?? 
                  widget.authState.client.user;
      
      if (clerkUser != null) break;

      try {
        await widget.authState.refreshClient();
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
    }

    // Determine user values
    final userId = clerkUser?.id ?? 
                   widget.authState.client.id ?? 
                   'user_${DateTime.now().millisecondsSinceEpoch}';

    final firstName = clerkUser?.firstName ?? '';
    final lastName = clerkUser?.lastName ?? '';
    final imageUrl = clerkUser?.imageUrl;

    // Find primary email
    String email = 'user@oeplatform.dev';
    final emails = clerkUser?.emailAddresses;
    if (emails != null && emails.isNotEmpty) {
      final primaryId = clerkUser?.primaryEmailAddressId;
      if (primaryId != null) {
        final primaryEmail = emails.cast<clerk.Email?>().firstWhere(
          (e) => e?.id == primaryId,
          orElse: () => null,
        );
        email = primaryEmail?.emailAddress ?? emails.first.emailAddress;
      } else {
        email = emails.first.emailAddress;
      }
    }

    final user = UserEntity(
      id: userId,
      email: email,
      firstName: firstName.isNotEmpty ? firstName : null,
      lastName: lastName.isNotEmpty ? lastName : null,
      imageUrl: imageUrl,
      isTeacher: false,
      joinedDate: clerkUser != null 
          ? _formatJoinedDate(clerkUser.createdAt) 
          : 'September 2026',
    );

    // Save user & session into Riverpod + persistent storage.
    // Use real JWT token when available so session quality is higher.
    try {
      // Try to get the real JWT from the active session
      final String? token = widget.authState.session?.lastActiveToken?.jwt ?? 
                            widget.authState.session?.id;
      // Store with clerk_ prefix so auth_repository knows not to
      // validate this token against the backend on next cold start.
      final sessionKey = token != null && token.isNotEmpty
          ? 'clerk_session_$token'
          : 'clerk_session_$userId';
      await ref.read(authControllerProvider.notifier).setClerkUser(user, sessionKey);
    } catch (e) {
      debugPrint('[ClerkUserBridge] Error setting Clerk user: $e');
    }

    _completed = true;

    if (mounted) {
      widget.onUserReady();
      context.go('/');
    }
  }

  String _formatJoinedDate(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.school_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Welcome to Termini',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Setting up your dashboard...',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 180,
                child: LinearProgressIndicator(
                  color: Color(0xFF6366F1),
                  backgroundColor: Color(0xFFE2E8F0),
                ),
              ),
              if (_showManualButton) ...[
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Open Dashboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    widget.onUserReady();
                    context.go('/');
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
