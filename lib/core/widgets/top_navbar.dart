import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/domain/user_entity.dart';
import '../../features/community/data/community_local_notification_service.dart';
import '../../features/community/presentation/community_notifications_screen.dart';
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
  StreamSubscription<RemoteMessage>? _foregroundPushSubscription;
  StreamSubscription<RemoteMessage>? _openedPushSubscription;
  StreamSubscription<String>? _pushTokenRefreshSubscription;
  late final Future<void> _notificationSetup;
  bool _firebasePushReady = false;
  String? _notificationUserId;
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
    final user = ref.read(currentUserProvider);
    await _configurePushForUser(user);
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

  Future<void> _configurePushForUser(UserEntity? user) async {
    if (_notificationUserId == user?.id) return;
    _notificationUserId = user?.id;
    await _foregroundPushSubscription?.cancel();
    await _openedPushSubscription?.cancel();
    await _pushTokenRefreshSubscription?.cancel();
    _foregroundPushSubscription = null;
    _openedPushSubscription = null;
    _pushTokenRefreshSubscription = null;
    _firebasePushReady = false;

    if (user == null || user.isTeacher != false) {
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic(
          'community_students',
        );
      } catch (_) {
        // Firebase may not be configured on this installation yet.
      }
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final prefs = await SharedPreferences.getInstance();
      const tokenRefreshKey = 'community_push_token_refresh_v1';
      if (!(prefs.getBool(tokenRefreshKey) ?? false)) {
        // Refresh any registration created before the production sender was
        // configured. Firebase can leave an invalid token cached locally.
        await messaging.deleteToken();
      }
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        throw StateError('Firebase did not provide a registration token');
      }
      final communityEnabled =
          prefs.getBool('community_notifications_enabled_${user.id}') ?? true;
      if (communityEnabled) {
        await messaging.subscribeToTopic('community_students');
      } else {
        await messaging.unsubscribeFromTopic('community_students');
      }
      await prefs.setBool(tokenRefreshKey, true);
      _pushTokenRefreshSubscription = messaging.onTokenRefresh.listen((_) {
        unawaited(() async {
          final latestPrefs = await SharedPreferences.getInstance();
          if (latestPrefs.getBool(
                'community_notifications_enabled_${user.id}',
              ) ??
              true) {
            await messaging.subscribeToTopic('community_students');
          } else {
            await messaging.unsubscribeFromTopic('community_students');
          }
        }());
      });
      _firebasePushReady = true;
      _foregroundPushSubscription = FirebaseMessaging.onMessage.listen((
        message,
      ) {
        final notification = message.notification;
        final postId =
            message.data['postId']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString();
        unawaited(
          CommunityLocalNotificationService.showNotification(
            id: postId,
            title: notification?.title ?? 'New post from Termini',
            body:
                notification?.body ??
                'A teacher shared a new post in Community.',
            userId: user.id,
          ),
        );
        unawaited(_refreshCommunityNotifications());
      });
      _openedPushSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (_) => _openCommunityNotifications(),
      );
      if (await messaging.getInitialMessage() != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openCommunityNotifications();
        });
      }
    } catch (error) {
      // Foreground polling remains available until Firebase app setup is present.
      debugPrint('[Termini Push] Firebase messaging unavailable: $error');
      await CommunityLocalNotificationService.initialize();
    }
  }

  void _openCommunityNotifications() {
    if (mounted) context.push('/notifications');
  }

  Future<void> _refreshCommunityNotifications() async {
    if (!mounted) return;
    final user = ref.read(currentUserProvider);
    if (user == null || user.isTeacher != false) return;
    await _notificationSetup;
    if (_notificationUserId != user.id) {
      await _configurePushForUser(user);
    }
    if (!mounted) return;
    ref.invalidate(communityNotificationPostsProvider);
    ref.invalidate(communityUnreadCountProvider);
    try {
      final posts = await ref.read(communityNotificationPostsProvider.future);
      await CommunityLocalNotificationService.notifyForNewPosts(
        user.id,
        posts,
        showNotifications: !_firebasePushReady,
      );
    } catch (_) {
      // The next timer tick retries if the backend is temporarily unavailable.
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _notificationRefreshTimer?.cancel();
    _foregroundPushSubscription?.cancel();
    _openedPushSubscription?.cancel();
    _pushTokenRefreshSubscription?.cancel();
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
    ref.listen(currentUserProvider, (previous, next) {
      if (previous?.id != next?.id) {
        unawaited(_configurePushForUser(next));
      }
    });
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isCompact = Breakpoints.isCompact(context);
    final currentUser = ref.watch(currentUserProvider);
    final canTeach = currentUser?.isTeacher ?? false;
    final unreadCount = canTeach
        ? 0
        : ref.watch(communityUnreadCountProvider).valueOrNull ?? 0;

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
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
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

              const SizedBox(width: 4),

              // Notifications
              Tooltip(
                message: unreadCount > 0
                    ? 'Notifications ($unreadCount unread)'
                    : 'Notifications',
                child: IconButton(
                  onPressed: _openCommunityNotifications,
                  style: IconButton.styleFrom(
                    fixedSize: const Size(42, 42),
                    backgroundColor: unreadCount > 0
                        ? const Color(0xFFEF4444).withValues(alpha: 0.10)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.04)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.notifications_rounded,
                        size: 22,
                        color: unreadCount > 0
                            ? const Color(0xFFEF4444)
                            : colorScheme.onSurfaceVariant,
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          top: -8,
                          right: -9,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: sidebarBg, width: 1.5),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              unreadCount > 9 ? '9+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
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
