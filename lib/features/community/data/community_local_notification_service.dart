import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/community_entity.dart';

class CommunityLocalNotificationService {
  CommunityLocalNotificationService._();

  static const _channel = MethodChannel('termini/local_notifications');
  static String _seenPostsKey(String userId) =>
      'community_system_notifications_seen_$userId';
  static String _enabledKey(String userId) =>
      'community_notifications_enabled_$userId';
  static String _soundKey(String userId) =>
      'community_notification_sound_$userId';
  static String _vibrationKey(String userId) =>
      'community_notification_vibration_$userId';

  static Future<bool> communityNotificationsEnabled(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey(userId)) ?? true;
  }

  static Future<bool> soundEnabled(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundKey(userId)) ?? true;
  }

  static Future<bool> vibrationEnabled(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_vibrationKey(userId)) ?? true;
  }

  static Future<void> setCommunityNotificationsEnabled(
    String userId,
    bool enabled,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey(userId), enabled);
    try {
      final messaging = FirebaseMessaging.instance;
      if (enabled) {
        await messaging.subscribeToTopic('community_students');
      } else {
        await messaging.unsubscribeFromTopic('community_students');
      }
    } catch (_) {
      // The in-app and polling notification paths still honor this preference.
    }
  }

  static Future<void> setAlertPreferences(
    String userId, {
    required bool sound,
    required bool vibration,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey(userId), sound);
    await prefs.setBool(_vibrationKey(userId), vibration);
    try {
      await _channel.invokeMethod<void>('updatePreferences', {
        'sound': sound,
        'vibration': vibration,
      });
    } on PlatformException {
      // Android channel preferences are unavailable on other platforms.
    } on MissingPluginException {
      // Keep preferences saved even without the Android notification channel.
    }
  }

  static Future<void> clearSystemNotifications() async {
    try {
      await _channel.invokeMethod<void>('clear');
    } on PlatformException {
      // The in-app notification list is cleared separately.
    } on MissingPluginException {
      // Notification shade cleanup is Android-only.
    }
  }

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
    List<CommunityPostEntity> posts, {
    bool showNotifications = true,
  }) async {
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

    if (showNotifications && (prefs.getBool(_enabledKey(userId)) ?? true)) {
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
            'sound': prefs.getBool(_soundKey(userId)) ?? true,
            'vibration': prefs.getBool(_vibrationKey(userId)) ?? true,
          });
        } on PlatformException {
          // A notification permission can be disabled by the user.
        } on MissingPluginException {
          return;
        }
      }
    }

    final updated = <String>{...seen, ...newestFirst.map((post) => post.id)};
    await prefs.setStringList(key, updated.take(300).toList());
  }

  static Future<void> showNotification({
    required String id,
    required String title,
    required String body,
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_enabledKey(userId)) ?? true)) return;
    try {
      await _channel.invokeMethod<void>('show', {
        'id': id.hashCode,
        'title': title,
        'body': body,
        'sound': prefs.getBool(_soundKey(userId)) ?? true,
        'vibration': prefs.getBool(_vibrationKey(userId)) ?? true,
      });
    } on PlatformException {
      // Android notification permission can be disabled by the user.
    } on MissingPluginException {
      // Push is supported by the Android app only.
    }
  }
}
