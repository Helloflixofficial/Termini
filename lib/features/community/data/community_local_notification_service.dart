import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/community_entity.dart';

class CommunityLocalNotificationService {
  CommunityLocalNotificationService._();

  static const _channel = MethodChannel('termini/local_notifications');
  static String _seenPostsKey(String userId) =>
      'community_system_notifications_seen_$userId';

  static Future<void> initialize() async {
    try {
      await _channel.invokeMethod<void>('requestPermission');
    } on PlatformException {
      // Notifications are only supported on Android in this project.
    } on MissingPluginException {
      // Keep the app usable on platforms without the Android channel.
    }
  }

  static Future<void> rememberCurrentPosts(
    String userId,
    List<CommunityPostEntity> posts,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _seenPostsKey(userId);
    if (prefs.containsKey(key)) return;
    await prefs.setStringList(
      key,
      posts.take(100).map((post) => post.id).toList(),
    );
  }

  static Future<void> notifyForNewPosts(
    String userId,
    List<CommunityPostEntity> posts,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _seenPostsKey(userId);
    if (!prefs.containsKey(key)) {
      await prefs.setStringList(
        key,
        posts.take(100).map((post) => post.id).toList(),
      );
      return;
    }
    final seen = (prefs.getStringList(key) ?? const <String>[]).toSet();
    final newestFirst = [...posts]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final newPosts = newestFirst
        .where((post) => !seen.contains(post.id))
        .toList();
    if (newPosts.isEmpty) return;

    for (final post in newPosts.reversed) {
      final title = post.title.trim();
      final body = title.isEmpty
          ? 'A teacher shared a new post in Community.'
          : 'A teacher shared "$title" in Community.';
      try {
        await _channel.invokeMethod<void>('show', {
          'id': post.id.hashCode,
          'title': 'New post from Termini',
          'body': body,
        });
      } on PlatformException {
        // A notification permission can be disabled in Android settings.
      } on MissingPluginException {
        return;
      }
    }

    final updated = <String>{...seen, ...newestFirst.map((post) => post.id)};
    await prefs.setStringList(key, updated.take(300).toList());
  }
}
