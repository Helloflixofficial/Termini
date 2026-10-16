import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/community_local_notification_service.dart';
import '../data/community_repository.dart';
import '../domain/community_entity.dart';

String _lastSeenKey(String userId) => 'community_notifications_seen_$userId';
String _readIdsKey(String userId) => 'community_notifications_read_ids_$userId';
String _clearedIdsKey(String userId) =>
    'community_notifications_cleared_ids_$userId';

final communityNotificationPostsProvider =
    FutureProvider.autoDispose<List<CommunityPostEntity>>((ref) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) return const [];
      final notifications = await ref
          .watch(communityRepositoryProvider)
          .getNotifications(userId: user.id);
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final prefs = await SharedPreferences.getInstance();
      final clearedIds =
          (prefs.getStringList(_clearedIdsKey(user.id)) ?? const <String>[])
              .toSet();
      return notifications
          .where((post) => !clearedIds.contains(post.id))
          .take(100)
          .toList();
    });

final communityNotificationReadIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
      final userId = ref.watch(currentUserProvider)?.id;
      if (userId == null) return const {};
      final prefs = await SharedPreferences.getInstance();
      final savedIds = prefs.getStringList(_readIdsKey(userId));
      if (savedIds != null) return savedIds.toSet();

      // Migrate installs using the old timestamp-only read state. On a fresh
      // install, treat the posts already present as the initial read baseline.
      final posts = await ref.watch(communityNotificationPostsProvider.future);
      final idsSetWhileLoading = prefs.getStringList(_readIdsKey(userId));
      if (idsSetWhileLoading != null) return idsSetWhileLoading.toSet();
      final savedLastSeen = prefs.getInt(_lastSeenKey(userId));
      final initialReadIds = savedLastSeen == null
          ? posts.map((post) => post.id).toSet()
          : posts
                .where(
                  (post) => !post.createdAt.isAfter(
                    DateTime.fromMillisecondsSinceEpoch(savedLastSeen),
                  ),
                )
                .map((post) => post.id)
                .toSet();
      await prefs.setStringList(
        _readIdsKey(userId),
        initialReadIds.toList(growable: false),
      );
      return initialReadIds;
    });

final communityUnreadNotificationIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
      final posts = await ref.watch(communityNotificationPostsProvider.future);
      final readIds = await ref.watch(
        communityNotificationReadIdsProvider.future,
      );
      return posts
          .where((post) => !readIds.contains(post.id))
          .map((post) => post.id)
          .toSet();
    });

final communityUnreadCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final unreadIds = await ref.watch(
    communityUnreadNotificationIdsProvider.future,
  );
  return unreadIds.length;
});

Future<void> markCommunityNotificationsRead(
  WidgetRef ref,
  String userId, {
  required Iterable<CommunityPostEntity> posts,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final key = _readIdsKey(userId);
  final readIds = (prefs.getStringList(key) ?? const <String>[]).toSet()
    ..addAll(posts.map((post) => post.id));
  final savedIds = readIds.toList(growable: false);
  await prefs.setStringList(
    key,
    savedIds.length > 300 ? savedIds.sublist(savedIds.length - 300) : savedIds,
  );
  await prefs.setInt(
    _lastSeenKey(userId),
    DateTime.now().millisecondsSinceEpoch,
  );

  ref.invalidate(communityNotificationReadIdsProvider);
  ref.invalidate(communityUnreadNotificationIdsProvider);
  ref.invalidate(communityUnreadCountProvider);
}

Future<void> clearCommunityNotifications(WidgetRef ref, String userId) async {
  final posts = await ref.read(communityNotificationPostsProvider.future);
  final prefs = await SharedPreferences.getInstance();
  final clearedIds = [
    ...?prefs.getStringList(_clearedIdsKey(userId)),
    ...posts.map((post) => post.id),
  ];
  final savedIds = clearedIds.toSet().toList(growable: false);
  await prefs.setStringList(
    _clearedIdsKey(userId),
    savedIds.length > 500 ? savedIds.sublist(savedIds.length - 500) : savedIds,
  );
  await markCommunityNotificationsRead(ref, userId, posts: posts);
  await CommunityLocalNotificationService.clearSystemNotifications();
  ref.invalidate(communityNotificationPostsProvider);
}

class CommunityNotificationsScreen extends ConsumerStatefulWidget {
  const CommunityNotificationsScreen({super.key});

  @override
  ConsumerState<CommunityNotificationsScreen> createState() =>
      _CommunityNotificationsScreenState();
}

class _CommunityNotificationsScreenState
    extends ConsumerState<CommunityNotificationsScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (mounted) ref.invalidate(communityNotificationPostsProvider);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_markVisibleNotificationsRead());
    });
  }

  Future<void> _markVisibleNotificationsRead() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    try {
      final posts = await ref.read(communityNotificationPostsProvider.future);
      if (!mounted) return;
      await markCommunityNotificationsRead(ref, userId, posts: posts);
    } catch (_) {
      // The page's retry action can mark notifications after a successful load.
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(communityNotificationPostsProvider);
    try {
      final posts = await ref.read(communityNotificationPostsProvider.future);
      final userId = ref.read(currentUserProvider)?.id;
      if (userId != null && mounted) {
        await markCommunityNotificationsRead(ref, userId, posts: posts);
      }
    } catch (_) {
      // The error state below stays available for another retry.
    }
  }

  Future<void> _openPost(CommunityPostEntity post) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId != null) {
      await markCommunityNotificationsRead(ref, userId, posts: [post]);
    }
    if (!mounted) return;
    context.push('/community/post/${post.id}', extra: post);
  }

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(communityNotificationPostsProvider);
    final unreadIds = ref.watch(communityUnreadNotificationIdsProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: posts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 100),
              Icon(Icons.wifi_off_rounded, size: 42, color: colors.outline),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Could not load notifications',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: _refresh,
                  child: const Text('Try again'),
                ),
              ),
            ],
          ),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: items.isEmpty ? 2 : items.length + 1,
            separatorBuilder: (_, index) =>
                SizedBox(height: index == 0 ? 16 : 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _NotificationsHeader(
                  unreadCount: unreadIds.valueOrNull?.length ?? 0,
                );
              }
              if (items.isEmpty) return const _NotificationsEmptyState();
              final post = items[index - 1];
              return _NotificationCard(
                post: post,
                isUnread: unreadIds.valueOrNull?.contains(post.id) ?? false,
                onTap: () => _openPost(post),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  final int unreadCount;

  const _NotificationsHeader({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = colors.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: .15),
            colors.surfaceContainerHighest.withValues(alpha: .48),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: .16)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.notifications_active_rounded, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community updates',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  unreadCount == 0
                      ? 'You’re all caught up'
                      : '$unreadCount new ${unreadCount == 1 ? 'post' : 'posts'} to see',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount new',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final CommunityPostEntity post;
  final bool isUnread;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.post,
    required this.isUnread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = post.authorName?.trim().isNotEmpty == true
        ? post.authorName!.trim()
        : 'A learner';

    return Material(
      color: isUnread
          ? const Color(0xFFEF4444).withValues(alpha: .07)
          : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isUnread
                  ? const Color(0xFFEF4444).withValues(alpha: .28)
                  : colors.outline.withValues(alpha: .35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NotificationAvatar(name: name, imageUrl: post.authorImageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$name shared a post',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      post.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    if (post.content.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        post.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat.MMMd().add_jm().format(post.createdAt),
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (post.mediaUrl?.isNotEmpty == true) ...[
                          const SizedBox(width: 10),
                          Icon(
                            Icons.image_outlined,
                            size: 14,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Photo',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(top: 11),
                child: Icon(Icons.chevron_right_rounded, color: colors.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationsEmptyState extends StatelessWidget {
  const _NotificationsEmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 36),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outline.withValues(alpha: .3)),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 30,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'You’re all caught up',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'New community posts from your teacher will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _NotificationAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;

  const _NotificationAvatar({required this.name, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final image = imageUrl?.trim();
    if (image != null && image.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: image,
          width: 44,
          height: 44,
          memCacheWidth: 132,
          memCacheHeight: 132,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => _fallback(),
          placeholder: (_, _) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() => CircleAvatar(
    radius: 22,
    backgroundColor: AppColors.brandSky.withValues(alpha: .15),
    child: Text(
      name.isEmpty ? 'U' : name[0].toUpperCase(),
      style: const TextStyle(
        color: AppColors.brandSky,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
