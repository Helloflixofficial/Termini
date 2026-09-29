import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/community_repository.dart';
import '../domain/community_entity.dart';

String _lastSeenKey(String userId) => 'community_notifications_seen_$userId';

final communityNotificationPostsProvider =
    FutureProvider.autoDispose<List<CommunityPostEntity>>((ref) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) return const [];
      final notifications = await ref
          .watch(communityRepositoryProvider)
          .getNotifications(userId: user.id);
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications.take(100).toList();
    });

final communityNotificationsLastSeenProvider =
    FutureProvider.autoDispose<DateTime?>((ref) async {
      final userId = ref.watch(currentUserProvider)?.id;
      if (userId == null) return null;
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_lastSeenKey(userId));
      if (saved != null) return DateTime.fromMillisecondsSinceEpoch(saved);
      final firstSeen = DateTime.now();
      await prefs.setInt(
        _lastSeenKey(userId),
        firstSeen.millisecondsSinceEpoch,
      );
      return firstSeen;
    });

final communityUnreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final posts = await ref.watch(communityNotificationPostsProvider.future);
  final lastSeen = await ref.watch(communityNotificationsLastSeenProvider.future);
  if (lastSeen == null) return 0;
  return posts.where((post) => post.createdAt.isAfter(lastSeen)).length;
});

Future<void> markCommunityNotificationsRead(WidgetRef ref, String userId) async {
  final now = DateTime.now();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_lastSeenKey(userId), now.millisecondsSinceEpoch);
  ref.invalidate(communityNotificationsLastSeenProvider);
  ref.invalidate(communityUnreadCountProvider);
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
      final userId = ref.read(currentUserProvider)?.id;
      if (userId != null) markCommunityNotificationsRead(ref, userId);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(communityNotificationPostsProvider);
    await ref.read(communityNotificationPostsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(communityNotificationPostsProvider);
    final lastSeen = ref.watch(communityNotificationsLastSeenProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: posts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 120),
              Icon(Icons.wifi_off_rounded, size: 42, color: colors.outline),
              const SizedBox(height: 12),
              const Center(child: Text('Could not load notifications')),
              Center(
                child: TextButton(
                  onPressed: _refresh,
                  child: const Text('Try again'),
                ),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Icon(Icons.notifications_none_rounded,
                      size: 54, color: colors.onSurfaceVariant),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      'You’re all caught up',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'New community posts from other learners will show here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final post = items[index];
                final seenAt = lastSeen.valueOrNull;
                final isNew = seenAt != null && post.createdAt.isAfter(seenAt);
                final name = post.authorName?.trim().isNotEmpty == true
                    ? post.authorName!.trim()
                    : 'A learner';
                return Material(
                  color: isNew
                      ? AppColors.brandSky.withValues(alpha: .09)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => context.push(
                      '/community/post/${post.id}',
                      extra: post,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: colors.outline.withValues(alpha: .55),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _NotificationAvatar(
                            name: name,
                            imageUrl: post.authorImageUrl,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '$name shared a community post',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    if (isNew) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFEF4444),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 5),
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
                                const SizedBox(height: 3),
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
                                const SizedBox(height: 7),
                                Text(
                                  DateFormat.MMMd().add_jm().format(post.createdAt),
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded,
                              color: colors.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
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
          width: 42,
          height: 42,
          memCacheWidth: 126,
          memCacheHeight: 126,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => _fallback(),
          placeholder: (_, _) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() => CircleAvatar(
        radius: 21,
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
