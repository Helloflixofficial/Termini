import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/community/data/community_local_notification_service.dart';
import '../../features/community/presentation/community_notifications_screen.dart';
import '../theme/theme_provider.dart';
import '../utils/breakpoints.dart';

class TopNavbar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  final String title;
  final bool showSearch;
  final VoidCallback? onSearchTap;
  final List<Widget>? actions;

  const TopNavbar({
    super.key,
    required this.title,
    this.showSearch = false,
    this.onSearchTap,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  ConsumerState<TopNavbar> createState() => _TopNavbarState();
}

class _TopNavbarState extends ConsumerState<TopNavbar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  Timer? _notificationRefreshTimer;
  late final Future<void> _notificationSetup;
  bool _avatarHovered = false;
  bool _searchHovered = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _notificationSetup = _prepareCommunityNotifications();
    _notificationRefreshTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _refreshCommunityNotifications(),
    );
  }

  Future<void> _prepareCommunityNotifications() async {
    await CommunityLocalNotificationService.initialize();
    final user = ref.read(currentUserProvider);
    if (user == null || user.isTeacher != false) return;
    try {
      final posts = await ref.read(communityNotificationPostsProvider.future);
      await CommunityLocalNotificationService.rememberCurrentPosts(
        user.id,
        posts,
      );
    } catch (_) {
      // A failed initial fetch is retried by the regular refresh timer.
    }
  }

  Future<void> _refreshCommunityNotifications() async {
    if (!mounted) return;
    final user = ref.read(currentUserProvider);
    if (user == null || user.isTeacher != false) return;
    await _notificationSetup;
    if (!mounted) return;
    ref.invalidate(communityNotificationPostsProvider);
    ref.invalidate(communityUnreadCountProvider);
    try {
      final posts = await ref.read(communityNotificationPostsProvider.future);
      await CommunityLocalNotificationService.notifyForNewPosts(user.id, posts);
    } catch (_) {
      // The next timer tick retries if the backend is temporarily unavailable.
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _notificationRefreshTimer?.cancel();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 21) return 'Good evening';
    return 'Good night';
  }

  String get _greetingEmoji {
    final h = DateTime.now().hour;
    if (h < 12) return '🌅';
    if (h < 17) return '☀️';
    if (h < 21) return '🌆';
    return '🌙';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isCompact = Breakpoints.isCompact(context);
    final currentUser = ref.watch(currentUserProvider);
    final canTeach = currentUser?.isTeacher ?? false;
    final unreadCount = canTeach
        ? 0
        : ref.watch(communityUnreadCountProvider).valueOrNull ?? 0;

    final initials = currentUser?.firstName?.isNotEmpty == true
        ? currentUser!.firstName![0].toUpperCase()
        : (currentUser?.email.isNotEmpty == true
              ? currentUser!.email[0].toUpperCase()
              : 'U');

    final sidebarBg = isDark ? const Color(0xFF131720) : Colors.white;

    return SafeArea(
      top: true,
      bottom: false,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
        height: widget.preferredSize.height,
        decoration: BoxDecoration(
          color: sidebarBg,
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.07),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 20),
        child: Row(
          children: [
            // Hamburger
            if (isCompact) ...[
              _iconBtn(
                icon: Icons.menu_rounded,
                isDark: isDark,
                colorScheme: colorScheme,
                onTap: () => Scaffold.of(context).openDrawer(),
              ),
              const SizedBox(width: 10),
            ],

            // Title / Greeting
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCompact && currentUser != null) ...[
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$_greeting ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          TextSpan(
                            text: _greetingEmoji,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentUser.firstName?.isNotEmpty == true
                          ? currentUser.firstName!
                          : widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else ...[
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Search (non-compact)
            if (widget.showSearch && !isCompact) ...[
              const SizedBox(width: 16),
              MouseRegion(
                onEnter: (_) => setState(() => _searchHovered = true),
                onExit: (_) => setState(() => _searchHovered = false),
                child: GestureDetector(
                  onTap: widget.onSearchTap ?? () => context.go('/search'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _searchHovered ? 300 : 260,
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _searchHovered
                          ? (isDark
                                ? Colors.white.withValues(alpha: 0.07)
                                : Colors.black.withValues(alpha: 0.04))
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : Colors.black.withValues(alpha: 0.02)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _searchHovered
                            ? colorScheme.primary.withValues(alpha: 0.4)
                            : isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.1),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 17,
                          color: _searchHovered
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Search courses, topics...',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.07)
                                : Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '⌘K',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(width: 6),
            ...?widget.actions,

            // Theme toggle
            const ThemeToggleButton(),
            const SizedBox(width: 8),

            // User avatar button
            MouseRegion(
              onEnter: (_) => setState(() => _avatarHovered = true),
              onExit: (_) => setState(() => _avatarHovered = false),
              child: GestureDetector(
                onTap: () => context.go('/profile'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _avatarHovered
                        ? colorScheme.primary.withValues(alpha: 0.08)
                        : isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _avatarHovered
                          ? colorScheme.primary.withValues(alpha: 0.25)
                          : isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Avatar circle
                      Stack(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: currentUser?.imageUrl == null
                                  ? LinearGradient(
                                      colors: canTeach
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
                                  color:
                                      (canTeach
                                              ? const Color(0xFF8B5CF6)
                                              : const Color(0xFF0284C7))
                                          .withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: currentUser?.imageUrl != null
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: currentUser!.imageUrl!,
                                      width: 32,
                                      height: 32,
                                      memCacheWidth: 96,
                                      memCacheHeight: 96,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, _, _) => Center(
                                        child: Text(
                                          initials,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                          ),
                          // Online dot
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: sidebarBg,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              top: -3,
                              right: -4,
                              child: Tooltip(
                                message: 'Community notifications',
                                child: Material(
                                  color: const Color(0xFFEF4444),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => context.push('/notifications'),
                                    child: Container(
                                      width: 19,
                                      height: 19,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: sidebarBg,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.notifications_rounded,
                                        color: Colors.white,
                                        size: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (!isCompact) ...[
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentUser?.firstName?.isNotEmpty == true
                                  ? currentUser!.firstName!
                                  : 'User',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (canTeach
                                            ? const Color(0xFF8B5CF6)
                                            : const Color(0xFF0284C7))
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                canTeach ? 'INSTRUCTOR' : 'STUDENT',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: canTeach
                                      ? const Color(0xFFA78BFA)
                                      : const Color(0xFF38BDF8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
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
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required bool isDark,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
