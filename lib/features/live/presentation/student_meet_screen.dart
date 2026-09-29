import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../data/livekit_repository.dart';
import '../domain/meeting_entity.dart';

final studentSessionsProvider =
    FutureProvider.autoDispose<List<MeetingSessionEntity>>((ref) async {
  final repo = ref.watch(liveKitRepositoryProvider);
  return repo.getSessions();
});

class StudentMeetScreen extends ConsumerStatefulWidget {
  const StudentMeetScreen({super.key});

  @override
  ConsumerState<StudentMeetScreen> createState() => _StudentMeetScreenState();
}

class _StudentMeetScreenState extends ConsumerState<StudentMeetScreen> {
  final _joinCodeController = TextEditingController();

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  void _handleJoinInput() {
    final text = _joinCodeController.text.trim();
    if (text.isEmpty) return;
    String roomName = text;
    if (text.contains('/meet/')) {
      roomName = text.split('/meet/').last;
    }
    context.go('/meet/$roomName');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final sessionsAsync = ref.watch(studentSessionsProvider);

    return ResponsiveLayout(
      title: 'ShortMeet',
      currentRoute: '/shortmeet',
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(studentSessionsProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero join banner
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'JOIN A LIVE CLASS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Connect with your teacher',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Paste a room code or meeting link to instantly join a live class.',
                            style: TextStyle(fontSize: 13.5, color: Colors.white70, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 32),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Join by code input
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outline),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.brandSky.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.meeting_room_rounded, color: AppColors.brandSky, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Enter Room Code or Meeting Link',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _joinCodeController,
                            decoration: InputDecoration(
                              hintText: 'e.g. xyz-abc-123 or paste full link',
                              filled: true,
                              fillColor: colorScheme.surfaceContainerLowest,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: colorScheme.outline),
                              ),
                              prefixIcon: const Icon(Icons.link_rounded, size: 20),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            onSubmitted: (_) => _handleJoinInput(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.videocam_rounded, size: 18),
                            label: const Text('Join Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandSky,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _handleJoinInput,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Active sessions from teacher
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.brandEmerald,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Active Live Sessions',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.fiber_manual_record, size: 8, color: Color(0xFFEF4444)),
                        SizedBox(width: 4),
                        Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFEF4444), letterSpacing: 0.6)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              sessionsAsync.when(
                loading: () => Column(
                  children: const [
                    SkeletonLoader(width: double.infinity, height: 100, borderRadius: 14),
                    SizedBox(height: 12),
                    SkeletonLoader(width: double.infinity, height: 100, borderRadius: 14),
                  ],
                ),
                error: (err, _) => ErrorStateWidget(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(studentSessionsProvider),
                ),
                data: (sessions) {
                  final active = sessions.where((s) => s.isActive).toList();

                  if (active.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: const EmptyStateWidget(
                        icon: Icons.videocam_off_outlined,
                        title: 'No live sessions right now',
                        description: 'Your teacher hasn\'t started a session yet. Check back soon or use a room code to join.',
                      ),
                    );
                  }

                  return Column(
                    children: active.map((s) => _StudentSessionCard(
                      session: s,
                      onJoin: () => context.go('/meet/${s.roomName}'),
                      isDark: isDark,
                      colorScheme: colorScheme,
                      theme: theme,
                    )).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentSessionCard extends StatelessWidget {
  final MeetingSessionEntity session;
  final VoidCallback onJoin;
  final bool isDark;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _StudentSessionCard({
    required this.session,
    required this.onJoin,
    required this.isDark,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.brandEmerald.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandEmerald.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Live indicator
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandEmerald.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (session.description != null && session.description!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    session.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 5),
                Text(
                  'Started ${DateFormat.jm().format(session.createdAt)} • ${session.roomName}',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Join button
          ElevatedButton.icon(
            icon: const Icon(Icons.videocam_rounded, size: 16),
            label: const Text('Join'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandEmerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: onJoin,
          ),
        ],
      ),
    );
  }
}
