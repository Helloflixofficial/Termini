import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../dashboard/presentation/dashboard_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              // Sign out from both Clerk and local Riverpod state
              try {
                final clerkAuth = ClerkAuth.of(ctx);
                await clerkAuth.signOut();
              } catch (_) {
                // Clerk may not be active if demo mode was used
              }
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/sign-in');
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, dynamic user) {
    final firstCtrl = TextEditingController(text: user.firstName ?? '');
    final lastCtrl = TextEditingController(text: user.lastName ?? '');
    final bioCtrl = TextEditingController(text: user.bio ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstCtrl,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: lastCtrl,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: bioCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Bio & Headline',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await ref.read(authControllerProvider.notifier).updateProfile(
                firstName: firstCtrl.text.trim(),
                lastName: lastCtrl.text.trim(),
                bio: bioCtrl.text.trim(),
              );
              if (context.mounted && ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated successfully!')),
                );
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final dashboardData = ref.watch(dashboardControllerProvider).valueOrNull;

    if (user == null) {
      return ResponsiveLayout(
        title: 'Profile',
        currentRoute: '/profile',
        body: Center(
          child: EmptyState(
            icon: Icons.person_off_rounded,
            title: 'Not Signed In',
            description: 'Please sign in to access your profile and learning progress.',
            actionLabel: 'Sign In',
            onAction: () => context.go('/sign-in'),
          ),
        ),
      );
    }

    final enrolledCount = (dashboardData?.coursesInProgress.length ?? 0) +
        (dashboardData?.completedCourses.length ?? 0);
    final completedCount = dashboardData?.completedCourses.length ?? 0;

    return ResponsiveLayout(
      title: 'Profile & Settings',
      currentRoute: '/profile',
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(authControllerProvider.notifier).refreshProfile();
          ref.invalidate(dashboardControllerProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outline),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: user.isTeacher
                                ? [AppColors.brandIndigo, AppColors.brandSky]
                                : [AppColors.brandSky, const Color(0xFF10B981)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brandIndigo.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            user.fullName.isNotEmpty
                                ? user.fullName.substring(0, 1).toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),

                      // User Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  user.fullName,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (user.isTeacher ? AppColors.brandIndigo : AppColors.brandSky)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: (user.isTeacher ? AppColors.brandIndigo : AppColors.brandSky)
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    user.isTeacher ? 'TEACHER / ADMIN' : 'STUDENT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: user.isTeacher
                                          ? (isDark ? AppColors.brandIndigoLight : AppColors.brandIndigo)
                                          : (isDark ? AppColors.brandSkyLight : AppColors.brandSky),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.email,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (user.bio != null && user.bio!.isNotEmpty) ...[
                              Container(
                                margin: const EdgeInsets.only(top: 6, bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  user.bio!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                            Wrap(
                              spacing: 10,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'ID: ${user.id}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                    fontFamily: 'monospace',
                                    fontSize: 10.5,
                                  ),
                                ),
                                if (user.joinedDate != null) ...[
                                  Text(
                                    'Joined: ${user.joinedDate}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.edit_rounded, size: 16),
                              label: const Text('Edit Profile'),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _showEditProfileDialog(context, ref, user),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Stats Cards
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colorScheme.outline),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.brandSky.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.play_lesson_rounded,
                                color: isDark ? AppColors.brandSkyLight : AppColors.brandSky,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$enrolledCount',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'Enrolled',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colorScheme.outline),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF10B981),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$completedCount',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'Completed',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Preferences & Theme Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'APP PREFERENCES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Theme selection
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                        ),
                        title: const Text(
                          'Appearance / Theme',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          'Current: ${themeMode == ThemeMode.dark ? "Dark" : themeMode == ThemeMode.light ? "Light" : "System Default"}',
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                        ),
                        trailing: const ThemeToggleButton(),
                      ),
                      const Divider(),

                      // Demo Profile Switcher
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            user.isTeacher ? Icons.school_rounded : Icons.cast_for_education_rounded,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                        ),
                        title: const Text(
                          'Demo Account Role',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          'Switch between Teacher and Student experience',
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                        ),
                        trailing: FilledButton.tonal(
                          onPressed: () async {
                            await ref
                                .read(authControllerProvider.notifier)
                                .signInAsDemo(isTeacher: !user.isTeacher);
                          },
                          child: Text(user.isTeacher ? 'Switch to Student' : 'Switch to Teacher'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Server Connection Info
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BACKEND CONNECTION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Active Endpoint',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Text(
                          AppEnv.apiBaseUrl,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Platform Target:',
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                          Text(
                            kIsWeb ? 'Web' : defaultTargetPlatform.name,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Sign Out Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showSignOutDialog(context, ref),
                    icon: const Icon(Icons.logout_rounded, color: AppColors.destructive, size: 20),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: AppColors.destructive,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppColors.destructive),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
