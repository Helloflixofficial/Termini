import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../live/data/livekit_repository.dart';
import '../../live/domain/meeting_entity.dart';

final liveSessionsProvider =
    FutureProvider.autoDispose<List<MeetingSessionEntity>>((ref) async {
  final repo = ref.watch(liveKitRepositoryProvider);
  return repo.getSessions();
});

class TeacherMeetScreen extends ConsumerStatefulWidget {
  const TeacherMeetScreen({super.key});

  @override
  ConsumerState<TeacherMeetScreen> createState() => _TeacherMeetScreenState();
}

class _TeacherMeetScreenState extends ConsumerState<TeacherMeetScreen> {
  final _joinCodeController = TextEditingController();
  final String _searchQuery = '';

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  void _showCreateSessionModal() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool startImmediately = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.video_call_rounded, color: AppColors.brandSky),
              SizedBox(width: 8),
              Text('New Meeting Session'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Session Title *',
                  hintText: "e.g. 'Intro to React – Live Session'",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'What will this session cover?',
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: startImmediately,
                title: const Text('Open meeting room immediately', style: TextStyle(fontSize: 13)),
                onChanged: (val) {
                  if (val != null) setModalState(() => startImmediately = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isNotEmpty) {
                  Navigator.pop(ctx);
                  final session = await ref.read(liveKitRepositoryProvider).createSession(
                    title,
                    description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                  );
                  ref.invalidate(liveSessionsProvider);
                  if (!context.mounted) return;
                  if (startImmediately) {
                    context.go('/meet/${session.roomName}');
                  }
                }
              },
              child: const Text('Create Session'),
            ),
          ],
        ),
      ),
    );
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
    final sessionsAsync = ref.watch(liveSessionsProvider);

    return ResponsiveLayout(
      title: 'ShortMeet',
      currentRoute: '/teacher/meet',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Session'),
            onPressed: _showCreateSessionModal,
          ),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(liveSessionsProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: sessionsAsync.when(
            loading: () => Column(
              children: const [
                SkeletonLoader(width: double.infinity, height: 120, borderRadius: 16),
                SizedBox(height: 20),
                SkeletonLoader(width: double.infinity, height: 80, borderRadius: 12),
              ],
            ),
            error: (err, _) => ErrorStateWidget(
              message: err.toString(),
              onRetry: () => ref.invalidate(liveSessionsProvider),
            ),
            data: (sessions) {
              final active = sessions.where((s) => s.isActive).toList();
              final ended = sessions.where((s) => !s.isActive).toList();

              final filteredActive = active.where((s) {
                if (_searchQuery.isEmpty) return true;
                return s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    s.roomName.toLowerCase().contains(_searchQuery.toLowerCase());
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Start Banner
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _showCreateSessionModal,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0284C7), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
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
                                  'QUICK START',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: Colors.white70,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Start a live class now',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Create a room, preview your camera and mic, and invite students in seconds.',
                                  style: TextStyle(fontSize: 13, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Join existing room box
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.meeting_room_outlined, color: AppColors.brandSky),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _joinCodeController,
                              decoration: const InputDecoration(
                                hintText: 'Paste a meeting link or room code',
                                isDense: true,
                              ),
                              onSubmitted: (_) => _handleJoinInput(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _handleJoinInput,
                            child: const Text('Join'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stats counters
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.check_circle_outline_rounded,
                          color: AppColors.brandEmerald,
                          label: 'Active',
                          count: active.length,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.highlight_off_rounded,
                          color: colorScheme.onSurfaceVariant,
                          label: 'Ended',
                          count: ended.length,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.videocam_outlined,
                          color: AppColors.brandSky,
                          label: 'Total',
                          count: sessions.length,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Active Sessions List
                  Text(
                    'Active Sessions (${filteredActive.length})',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (filteredActive.isEmpty)
                    const EmptyStateWidget(
                      icon: Icons.videocam_off_outlined,
                      title: 'No active sessions',
                      description: 'Start a new session or check your ended sessions.',
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: Breakpoints.getGridCrossAxisCount(context),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.3,
                      ),
                      itemCount: filteredActive.length,
                      itemBuilder: (context, index) {
                        final s = filteredActive[index];
                        return _SessionCard(
                          session: s,
                          onJoin: () => context.go('/meet/${s.roomName}'),
                          onEnd: () async {
                            await ref.read(liveKitRepositoryProvider).endSession(s.id);
                            ref.invalidate(liveSessionsProvider);
                          },
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int count;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    count.toString(),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final MeetingSessionEntity session;
  final VoidCallback onJoin;
  final VoidCallback onEnd;

  const _SessionCard({
    required this.session,
    required this.onJoin,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            color: session.isActive ? AppColors.brandEmerald : colorScheme.outline,
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: session.isActive
                            ? AppColors.brandEmerald.withValues(alpha: 0.1)
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        session.isActive ? 'Active' : 'Ended',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: session.isActive ? AppColors.brandEmerald : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      DateFormat.yMMMd().format(session.createdAt),
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (session.description != null && session.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    session.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.videocam_rounded, size: 16),
                        label: const Text('Start / Join'),
                        onPressed: onJoin,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: 'Copy room code',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: session.roomName));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Room code copied to clipboard!')),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton.outlined(
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.lightDestructive),
                      tooltip: 'End session',
                      onPressed: onEnd,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
