import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:clerk_flutter/clerk_flutter.dart';
// Clerk ships its full profile editor with the Flutter package, but currently
// does not export it for mounting in a dedicated app route.
// ignore: implementation_imports
import 'package:clerk_flutter/src/widgets/user/clerk_user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../auth/presentation/auth_controller.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  bool _signingOut = false;
  bool _updatingPhoto = false;
  ClerkAuthState? _observedClerk;
  String? _lastSyncedProfile;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = ClerkAuth.of(context, listen: false);
    if (identical(auth, _observedClerk)) return;
    _observedClerk?.removeListener(_syncClerkProfile);
    _observedClerk = auth;
    auth.addListener(_syncClerkProfile);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncClerkProfile();
    });
  }

  @override
  void dispose() {
    _observedClerk?.removeListener(_syncClerkProfile);
    super.dispose();
  }

  Future<void> _syncClerkProfile() async {
    final clerkUser = _observedClerk?.user ?? _observedClerk?.client.user;
    final appUser = ref.read(currentUserProvider);
    if (clerkUser == null || appUser == null) return;

    var email = appUser.email;
    final emailAddresses = clerkUser.emailAddresses;
    if (emailAddresses != null) {
      for (final address in emailAddresses) {
        if (address.id == clerkUser.primaryEmailAddressId) {
          email = address.emailAddress;
          break;
        }
      }
      if (email.isEmpty && emailAddresses.isNotEmpty) {
        email = emailAddresses.first.emailAddress;
      }
    }
    final signature =
        '${clerkUser.id}|${clerkUser.firstName}|${clerkUser.lastName}|${clerkUser.imageUrl}|$email';
    if (signature == _lastSyncedProfile) return;
    _lastSyncedProfile = signature;

    final updatedUser = appUser.copyWith(
      email: email,
      firstName: clerkUser.firstName,
      lastName: clerkUser.lastName,
      imageUrl: clerkUser.imageUrl,
    );
    final sessionToken =
        _observedClerk?.session?.lastActiveToken?.jwt ??
        _observedClerk?.session?.id;
    final persistedToken = sessionToken == null || sessionToken.isEmpty
        ? null
        : 'clerk_session_$sessionToken';
    await ref
        .read(authControllerProvider.notifier)
        .setClerkUser(updatedUser, persistedToken);
  }

  Future<void> _signOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.logout_rounded),
        title: const Text('Log out?'),
        content: const Text(
          'You can log back in anytime with your Clerk account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (shouldSignOut != true || !mounted) return;

    setState(() => _signingOut = true);
    try {
      await ClerkAuth.of(context, listen: false).signOut();
      await ref.read(authControllerProvider.notifier).signOut();
      if (mounted) context.go('/sign-in');
    } catch (_) {
      if (!mounted) return;
      setState(() => _signingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not log out. Please try again.')),
      );
    }
  }

  Future<void> _chooseProfilePhoto() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1600,
      );
      if (image == null || !mounted) return;
      setState(() => _updatingPhoto = true);
      final clerk = ClerkAuth.of(context, listen: false);
      await clerk.safelyCall(
        context,
        () => clerk.updateUserImage(File(image.path)),
      );
      if (mounted) setState(() => _updatingPhoto = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _updatingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update your profile photo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final clerk = ClerkAuth.of(context);
    final clerkUser = clerk.user ?? clerk.client.user;
    final appUser = ref.watch(currentUserProvider);
    final name = clerkUser?.name.trim().isNotEmpty == true
        ? clerkUser!.name.trim()
        : appUser?.fullName ?? 'Your account';
    var email = appUser?.email ?? '';
    final emailAddresses = clerkUser?.emailAddresses;
    if (clerkUser != null && emailAddresses != null) {
      for (final address in emailAddresses) {
        if (address.id == clerkUser.primaryEmailAddressId) {
          email = address.emailAddress;
          break;
        }
      }
      if (email.isEmpty && emailAddresses.isNotEmpty) {
        email = emailAddresses.first.emailAddress;
      }
    }
    final avatar = clerkUser?.imageUrl ?? appUser?.imageUrl;

    return ResponsiveLayout(
      title: 'Account settings',
      currentRoute: '/profile/account',
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 27,
                            backgroundColor: colors.primary.withValues(
                              alpha: .13,
                            ),
                            backgroundImage: avatar?.isNotEmpty == true
                                ? CachedNetworkImageProvider(avatar!)
                                : null,
                            child: avatar?.isNotEmpty == true
                                ? null
                                : Text(
                                    name.isEmpty ? 'U' : name[0].toUpperCase(),
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                          Positioned(
                            right: -4,
                            bottom: -3,
                            child: Material(
                              color: colors.primary,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _updatingPhoto
                                    ? null
                                    : _chooseProfilePhoto,
                                child: SizedBox(
                                  width: 25,
                                  height: 25,
                                  child: _updatingPhoto
                                      ? const Padding(
                                          padding: EdgeInsets.all(6),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.camera_alt_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          'CLERK',
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: const ClerkUserProfile(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _signingOut ? null : _signOut,
                    icon: _signingOut
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout_rounded),
                    label: Text(_signingOut ? 'Logging out…' : 'Log out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.destructive,
                      side: BorderSide(
                        color: AppColors.destructive.withValues(alpha: .6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
}
