import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/community_local_notification_service.dart';
import 'community_notifications_screen.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _communityEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final values = await Future.wait([
      CommunityLocalNotificationService.communityNotificationsEnabled(userId),
      CommunityLocalNotificationService.soundEnabled(userId),
      CommunityLocalNotificationService.vibrationEnabled(userId),
    ]);
    if (!mounted) return;
    setState(() {
      _communityEnabled = values[0];
      _soundEnabled = values[1];
      _vibrationEnabled = values[2];
      _loading = false;
    });
  }

  Future<void> _setCommunityEnabled(bool value) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    setState(() {
      _communityEnabled = value;
      _saving = true;
    });
    await CommunityLocalNotificationService.setCommunityNotificationsEnabled(
      userId,
      value,
    );
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _setAlertPreferences({bool? sound, bool? vibration}) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    final nextSound = sound ?? _soundEnabled;
    final nextVibration = vibration ?? _vibrationEnabled;
    setState(() {
      _soundEnabled = nextSound;
      _vibrationEnabled = nextVibration;
      _saving = true;
    });
    await CommunityLocalNotificationService.setAlertPreferences(
      userId,
      sound: nextSound,
      vibration: nextVibration,
    );
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _clearNotifications() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    setState(() => _saving = true);
    try {
      await clearCommunityNotifications(ref, userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Community notifications cleared')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not clear notifications. Try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Notification settings'),
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
              children: [
                _SettingsIntro(enabled: _communityEnabled, isSaving: _saving),
                const SizedBox(height: 20),
                _SettingsSection(
                  title: 'COMMUNITY',
                  children: [
                    _NotificationSwitchTile(
                      icon: Icons.campaign_rounded,
                      title: 'Community notifications',
                      subtitle: _communityEnabled
                          ? 'Get an alert when a new post is shared'
                          : 'New community post alerts are paused',
                      value: _communityEnabled,
                      onChanged: _setCommunityEnabled,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: 'ALERT STYLE',
                  children: [
                    _NotificationSwitchTile(
                      icon: Icons.volume_up_rounded,
                      title: 'Notification sound',
                      subtitle: 'Play a sound for new post alerts',
                      value: _soundEnabled,
                      onChanged: (value) => _setAlertPreferences(sound: value),
                      enabled: _communityEnabled,
                    ),
                    Divider(
                      height: 1,
                      color: colors.outlineVariant.withValues(alpha: .6),
                    ),
                    _NotificationSwitchTile(
                      icon: Icons.vibration_rounded,
                      title: 'Vibrate',
                      subtitle: 'Vibrate when a post notification arrives',
                      value: _vibrationEnabled,
                      onChanged: (value) =>
                          _setAlertPreferences(vibration: value),
                      enabled: _communityEnabled,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: 'INBOX',
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.destructive.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.delete_sweep_rounded,
                          color: AppColors.destructive,
                        ),
                      ),
                      title: const Text(
                        'Clear notifications',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Clear this device’s community inbox and alert tray',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _saving ? null : _clearNotifications,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'These settings apply to this device. Clearing notifications does not remove community posts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
    );
  }
}

class _SettingsIntro extends StatelessWidget {
  final bool enabled;
  final bool isSaving;

  const _SettingsIntro({required this.enabled, required this.isSaving});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withValues(alpha: .17),
            colors.surfaceContainerLow,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.primary.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: colors.primary,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stay in the loop',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  isSaving
                      ? 'Saving your preferences…'
                      : enabled
                      ? 'Community alerts are on'
                      : 'Community alerts are off',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (isSaving)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 9),
          child: Text(
            title,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .9,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: .65),
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ],
    );
  }
}

class _NotificationSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _NotificationSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      secondary: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: colors.primary, size: 21),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
      ),
      value: value,
      onChanged: enabled ? onChanged : null,
      activeThumbColor: colors.primary,
    );
  }
}
