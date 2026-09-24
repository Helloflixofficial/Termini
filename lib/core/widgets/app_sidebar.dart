import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/domain/user_entity.dart';
import '../theme/theme_provider.dart';

class SidebarItemData {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final String route;
  final String? badge;
  final Color? badgeColor;

  const SidebarItemData({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.route,
    this.badge,
    this.badgeColor,
  });
}

const List<SidebarItemData> studentRoutes = [
  SidebarItemData(
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard_rounded,
    label: 'Dashboard',
    route: '/',
  ),
  SidebarItemData(
    icon: Icons.explore_outlined,
    activeIcon: Icons.explore_rounded,
    label: 'Browse Catalog',
    route: '/search',
  ),
  SidebarItemData(
    icon: Icons.forum_outlined,
    activeIcon: Icons.forum_rounded,
    label: 'Community',
    route: '/community',
    badge: 'Hub',
    badgeColor: Color(0xFF0284C7),
  ),
];

const List<SidebarItemData> teacherRoutes = [
  SidebarItemData(
    icon: Icons.list_alt_rounded,
    activeIcon: Icons.list_alt_rounded,
    label: 'Course Studio',
    route: '/teacher/courses',
  ),
  SidebarItemData(
    icon: Icons.bar_chart_rounded,
    activeIcon: Icons.bar_chart_rounded,
    label: 'Analytics',
    route: '/teacher/analytics',
  ),
  SidebarItemData(
    icon: Icons.forum_outlined,
    activeIcon: Icons.forum_rounded,
    label: 'Community',
    route: '/teacher/community',
  ),
  SidebarItemData(
    icon: Icons.videocam_outlined,
    activeIcon: Icons.videocam_rounded,
    label: 'Live ShortMeet',
    route: '/teacher/meet',
    badge: 'LIVE',
    badgeColor: Color(0xFFEF4444),
  ),
];

class AppSidebar extends ConsumerWidget {
  final String currentRoute;
  final bool isCollapsed;
  final VoidCallback? onNavigate;

  const AppSidebar({
    super.key,
    required this.currentRoute,
    this.isCollapsed = false,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);
    final canTeach = currentUser?.isTeacher ?? false;
    final isTeacherMode = currentRoute.startsWith('/teacher');

    final activeRoutes = isTeacherMode ? teacherRoutes : studentRoutes;

    return Container(
      width: isCollapsed ? 76 : 260,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF131720), const Color(0xFF0C0E14)]
              : [Colors.white, const Color(0xFFF8FAFC)],
        ),
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Stylish Brand Header
          Container(
            height: 70,
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 20),
            alignment: isCollapsed ? Alignment.center : Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              'TERMINI',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primary.withValues(alpha: 0.2),
                                    colorScheme.secondary.withValues(alpha: 0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: colorScheme.primary.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'LMS',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Learning Platform',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          Divider(
            height: 1,
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
          ),

          // 2. Mode Switcher Card (Back to Learning / Open Studio)
          if (true) ...[
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? 8 : 14,
                vertical: 14,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  onNavigate?.call();
                  if (isTeacherMode) {
                    context.go('/');
                  } else {
                    context.go('/teacher/courses');
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCollapsed ? 8 : 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isTeacherMode
                          ? [
                              const Color(0xFF6366F1).withValues(alpha: 0.15),
                              const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                            ]
                          : [
                              const Color(0xFF0284C7).withValues(alpha: 0.15),
                              const Color(0xFF38BDF8).withValues(alpha: 0.08),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isTeacherMode
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
                          : const Color(0xFF0284C7).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: (isTeacherMode ? const Color(0xFF8B5CF6) : const Color(0xFF0284C7))
                              .withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isTeacherMode ? Icons.auto_stories_rounded : Icons.admin_panel_settings_rounded,
                          size: 16,
                          color: isTeacherMode ? const Color(0xFFA78BFA) : const Color(0xFF38BDF8),
                        ),
                      ),
                      if (!isCollapsed) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isTeacherMode ? 'Back to Student' : 'Teacher Studio',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                              Text(
                                isTeacherMode ? 'Switch to learner' : 'Manage your courses',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.swap_horiz_rounded,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],

          // 3. Navigation Links Section
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 8 : 14,
              vertical: 6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isCollapsed)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4, bottom: 8),
                    child: Text(
                      isTeacherMode ? 'CREATOR STUDIO' : 'LEARNING SUITE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ...activeRoutes.map((item) {
                  final isActive = currentRoute == item.route ||
                      (item.route != '/' && currentRoute.startsWith(item.route));

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        onNavigate?.call();
                        context.go(item.route);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? colorScheme.primary.withValues(alpha: isDark ? 0.14 : 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                                ? colorScheme.primary.withValues(alpha: 0.3)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: isCollapsed
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.start,
                          children: [
                            if (isActive && !isCollapsed) ...[
                              Container(
                                width: 3.5,
                                height: 18,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withValues(alpha: 0.6),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            Icon(
                              isActive ? (item.activeIcon ?? item.icon) : item.icon,
                              size: 20,
                              color: isActive
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            if (!isCollapsed) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: isActive
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isActive
                                        ? (isDark ? Colors.white : Colors.black87)
                                        : colorScheme.onSurfaceVariant,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                              if (item.badge != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (item.badgeColor ?? colorScheme.primary).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: (item.badgeColor ?? colorScheme.primary).withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    item.badge!,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                      color: item.badgeColor ?? colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // Direct Settings Item in Sidebar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      onNavigate?.call();
                      context.go('/profile');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: currentRoute == '/profile'
                            ? colorScheme.primary.withValues(alpha: isDark ? 0.14 : 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: currentRoute == '/profile'
                              ? colorScheme.primary.withValues(alpha: 0.3)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: isCollapsed
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.start,
                        children: [
                          if (currentRoute == '/profile' && !isCollapsed) ...[
                            Container(
                              width: 3.5,
                              height: 18,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Icon(
                            currentRoute == '/profile' ? Icons.settings_rounded : Icons.settings_outlined,
                            size: 20,
                            color: currentRoute == '/profile'
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          if (!isCollapsed) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Settings & Account',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: currentRoute == '/profile'
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: currentRoute == '/profile'
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : colorScheme.onSurfaceVariant,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // 4. Premium User Profile Footer
          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
          _SidebarProfileCard(
            currentUser: currentUser,
            canTeach: canTeach,
            isCollapsed: isCollapsed,
            isDark: isDark,
            colorScheme: colorScheme,
            onNavigate: onNavigate,
            onProfileTap: () {
              onNavigate?.call();
              context.go('/profile');
            },
            onSignOut: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) context.go('/sign-in');
            },
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
//  Premium sidebar profile card
// ──────────────────────────────────────────────────────────────────────

class _SidebarProfileCard extends StatefulWidget {
  final UserEntity? currentUser;
  final bool canTeach;
  final bool isCollapsed;
  final bool isDark;
  final ColorScheme colorScheme;
  final VoidCallback? onNavigate;
  final VoidCallback onProfileTap;
  final Future<void> Function() onSignOut;

  const _SidebarProfileCard({
    required this.currentUser,
    required this.canTeach,
    required this.isCollapsed,
    required this.isDark,
    required this.colorScheme,
    required this.onNavigate,
    required this.onProfileTap,
    required this.onSignOut,
  });

  @override
  State<_SidebarProfileCard> createState() => _SidebarProfileCardState();
}

class _SidebarProfileCardState extends State<_SidebarProfileCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.currentUser;
    final initials = user?.firstName?.isNotEmpty == true
        ? user!.firstName![0].toUpperCase()
        : (user?.email.isNotEmpty == true
            ? user!.email[0].toUpperCase()
            : 'U');

    final bgColor = widget.isDark
        ? const Color(0xFF131720)
        : Colors.white;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          widget.isCollapsed ? 8 : 12,
          8,
          widget.isCollapsed ? 8 : 12,
          12),
      child: widget.isCollapsed
          // Collapsed: just show avatar
          ? GestureDetector(
              onTap: widget.onProfileTap,
              child: Center(
                child: Stack(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: user?.imageUrl == null
                            ? LinearGradient(
                                colors: widget.canTeach
                                    ? [
                                        const Color(0xFF8B5CF6),
                                        const Color(0xFF6366F1),
                                      ]
                                    : [
                                        const Color(0xFF0284C7),
                                        const Color(0xFF38BDF8),
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: (widget.canTeach
                                    ? const Color(0xFF8B5CF6)
                                    : const Color(0xFF0284C7))
                                .withValues(alpha: 0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: user?.imageUrl != null
                          ? ClipOval(
                              child: Image.network(user!.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                      child: Text(initials,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)))),
                            )
                          : Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      bottom: 1,
                      right: 1,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: bgColor, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          // Expanded: full profile card
          : MouseRegion(
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _hovered
                      ? (widget.isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04))
                      : (widget.isDark
                          ? Colors.white.withValues(alpha: 0.03)
                          : Colors.black.withValues(alpha: 0.02)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _hovered
                        ? widget.colorScheme.primary.withValues(alpha: 0.2)
                        : widget.isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  children: [
                    // Top row: avatar + info + logout
                    Row(
                      children: [
                        // Avatar
                        GestureDetector(
                          onTap: widget.onProfileTap,
                          child: Stack(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: user?.imageUrl == null
                                      ? LinearGradient(
                                          colors: widget.canTeach
                                              ? [
                                                  const Color(0xFF8B5CF6),
                                                  const Color(0xFF6366F1),
                                                ]
                                              : [
                                                  const Color(0xFF0284C7),
                                                  const Color(0xFF38BDF8),
                                                ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (widget.canTeach
                                              ? const Color(0xFF8B5CF6)
                                              : const Color(0xFF0284C7))
                                          .withValues(alpha: 0.4),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: user?.imageUrl != null
                                    ? ClipOval(
                                        child: Image.network(
                                          user!.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Center(
                                            child: Text(initials,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          initials,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                              ),
                              // Online dot
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 11,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: bgColor, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Name + email + badge
                        Expanded(
                          child: GestureDetector(
                            onTap: widget.onProfileTap,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.fullName ?? 'Guest User',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: widget.isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (user?.email != null) ...[
                                  const SizedBox(height: 1),
                                  Text(
                                    user!.email,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: widget.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.75),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: widget.canTeach
                                          ? [
                                              const Color(0xFF8B5CF6)
                                                  .withValues(alpha: 0.25),
                                              const Color(0xFF6366F1)
                                                  .withValues(alpha: 0.15),
                                            ]
                                          : [
                                              const Color(0xFF0284C7)
                                                  .withValues(alpha: 0.25),
                                              const Color(0xFF38BDF8)
                                                  .withValues(alpha: 0.15),
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: widget.canTeach
                                          ? const Color(0xFF8B5CF6)
                                              .withValues(alpha: 0.35)
                                          : const Color(0xFF0284C7)
                                              .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Text(
                                    widget.canTeach ? '✦ INSTRUCTOR' : '✦ STUDENT',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                      color: widget.canTeach
                                          ? const Color(0xFFA78BFA)
                                          : const Color(0xFF38BDF8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Log out icon
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: widget.onSignOut,
                          child: Tooltip(
                            message: 'Sign out',
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.25),
                                ),
                              ),
                              child: const Icon(
                                Icons.logout_rounded,
                                size: 15,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Stats mini-row
                    if (user != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        height: 1,
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatChip(
                            label: 'Courses',
                            value: '${user.stats.enrolledCoursesCount}',
                            icon: Icons.menu_book_rounded,
                            color: const Color(0xFF0284C7),
                            isDark: widget.isDark,
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            color: widget.isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06),
                          ),
                          _StatChip(
                            label: 'Hours',
                            value: user.stats.hoursLearned
                                .toStringAsFixed(1),
                            icon: Icons.schedule_rounded,
                            color: const Color(0xFF10B981),
                            isDark: widget.isDark,
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            color: widget.isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06),
                          ),
                          _StatChip(
                            label: 'Certs',
                            value:
                                '${user.stats.certificatesCount}',
                            icon: Icons.workspace_premium_rounded,
                            color: const Color(0xFFF59E0B),
                            isDark: widget.isDark,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
            color: isDark
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}
