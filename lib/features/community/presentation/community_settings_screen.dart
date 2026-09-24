import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../data/community_repository.dart';

final communitySettingsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(communityRepositoryProvider);
  return repo.getSettings();
});

class CommunitySettingsScreen extends ConsumerStatefulWidget {
  const CommunitySettingsScreen({super.key});

  @override
  ConsumerState<CommunitySettingsScreen> createState() => _CommunitySettingsScreenState();
}

class _CommunitySettingsScreenState extends ConsumerState<CommunitySettingsScreen> {
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _welcomeController = TextEditingController();

  bool _allowStudentPosts = true;
  bool _allowStudentComments = true;
  bool _requirePostApproval = false;
  bool _showMemberCount = true;

  bool _isInitialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _welcomeController.dispose();
    super.dispose();
  }

  void _populateData(Map<String, dynamic> data) {
    if (_isInitialized) return;
    _nameController.text = data['communityName'] as String? ?? 'OEPlatform Community';
    _taglineController.text = data['tagline'] as String? ?? 'Learn, share, and connect with peers';
    _welcomeController.text = data['welcomeMessage'] as String? ?? '';
    _allowStudentPosts = data['allowStudentPosts'] as bool? ?? true;
    _allowStudentComments = data['allowStudentComments'] as bool? ?? true;
    _requirePostApproval = data['requirePostApproval'] as bool? ?? false;
    _showMemberCount = data['showMemberCount'] as bool? ?? true;
    _isInitialized = true;
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final repo = ref.read(communityRepositoryProvider);
      final payload = {
        'communityName': _nameController.text.trim(),
        'tagline': _taglineController.text.trim(),
        'welcomeMessage': _welcomeController.text.trim(),
        'allowStudentPosts': _allowStudentPosts,
        'allowStudentComments': _allowStudentComments,
        'requirePostApproval': _requirePostApproval,
        'showMemberCount': _showMemberCount,
      };

      await repo.updateSettings(payload);
      ref.invalidate(communitySettingsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Community settings saved successfully'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: AppColors.destructive,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final settingsAsync = ref.watch(communitySettingsProvider);

    return ResponsiveLayout(
      title: 'Community Settings',
      currentRoute: '/teacher/community/settings',
      body: settingsAsync.when(
        loading: () => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SkeletonLoader(width: 250, height: 32),
              SizedBox(height: 12),
              SkeletonLoader(width: 380, height: 18),
              SizedBox(height: 32),
              SkeletonLoader(width: double.infinity, height: 260, borderRadius: 16),
              SizedBox(height: 24),
              SkeletonLoader(width: double.infinity, height: 300, borderRadius: 16),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Failed to load settings',
            description: err.toString(),
            actionLabel: 'Try Again',
            onAction: () => ref.invalidate(communitySettingsProvider),
          ),
        ),
        data: (data) {
          _populateData(data);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with back link
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => context.go('/community'),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('Back to community'),
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Title & Save Action
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.brandSky.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.brandSky.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.shield_outlined,
                                      size: 14,
                                      color: isDark ? AppColors.brandSkyLight : AppColors.brandSky,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'ADMIN CONTROLS',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                        color: isDark ? AppColors.brandSkyLight : AppColors.brandSky,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Community Settings',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Shape the student experience and configure permissions.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        FilledButton.icon(
                          onPressed: _isSaving ? null : _saveSettings,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save_rounded, size: 18),
                          label: Text(_isSaving ? 'Saving...' : 'Save changes'),
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Section 1: Identity & Welcome
                    Container(
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
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.brandSky.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 20,
                                  color: isDark ? AppColors.brandSkyLight : AppColors.brandSky,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Identity and Welcome',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'These details are shown to students in the community view.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'COMMUNITY NAME',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _nameController,
                            maxLength: 80,
                            decoration: InputDecoration(
                              hintText: 'e.g. Masterclass Community',
                              counterText: '',
                              filled: true,
                              fillColor: colorScheme.surfaceContainerLowest,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: colorScheme.outline),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: colorScheme.outline),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'TAGLINE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _taglineController,
                            maxLength: 160,
                            decoration: InputDecoration(
                              hintText: 'e.g. Learn together, build real projects',
                              counterText: '',
                              filled: true,
                              fillColor: colorScheme.surfaceContainerLowest,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: colorScheme.outline),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: colorScheme.outline),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'WELCOME MESSAGE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _welcomeController,
                            maxLines: 4,
                            maxLength: 600,
                            decoration: InputDecoration(
                              hintText: 'Welcome students and explain how to participate...',
                              filled: true,
                              fillColor: colorScheme.surfaceContainerLowest,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: colorScheme.outline),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: colorScheme.outline),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section 2: Member Permissions
                    Container(
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
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.brandIndigo.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.people_outline_rounded,
                                  size: 20,
                                  color: isDark ? AppColors.brandIndigoLight : AppColors.brandIndigo,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Member Permissions',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'Control what students are permitted to do in discussions.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Allow student posts',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              'Students can publish new discussions in your spaces.',
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                            value: _allowStudentPosts,
                            onChanged: (val) => setState(() => _allowStudentPosts = val),
                          ),
                          const Divider(),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Allow student comments',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              'Students can reply to approved posts.',
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                            value: _allowStudentComments,
                            onChanged: (val) => setState(() => _allowStudentComments = val),
                          ),
                          const Divider(),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Require post approval',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              'New student posts stay hidden until a teacher approves them.',
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                            value: _requirePostApproval,
                            onChanged: (val) => setState(() => _requirePostApproval = val),
                          ),
                          const Divider(),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Show member count',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              'Display community member and activity stats in the student view.',
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                            value: _showMemberCount,
                            onChanged: (val) => setState(() => _showMemberCount = val),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Teachers always retain full moderation access, including approving, pinning, announcing, and deleting posts.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.4,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
