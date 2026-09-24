import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../courses/data/course_repository.dart';
import '../../courses/domain/course_entity.dart';
import '../../player/presentation/chapter_player_screen.dart';
import '../../player/presentation/widgets/mux_video_player.dart';

class ChapterEditorScreen extends ConsumerStatefulWidget {
  final String courseId;
  final String chapterId;

  const ChapterEditorScreen({
    super.key,
    required this.courseId,
    required this.chapterId,
  });

  @override
  ConsumerState<ChapterEditorScreen> createState() => _ChapterEditorScreenState();
}

class _ChapterEditorScreenState extends ConsumerState<ChapterEditorScreen> {
  bool _isLoading = false;

  Future<void> _togglePublish(ChapterEntity chapter) async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(courseRepositoryProvider);
      if (chapter.isPublished) {
        await repo.unpublishChapter(widget.courseId, widget.chapterId);
      } else {
        await repo.publishChapter(widget.courseId, widget.chapterId);
      }
      ref.invalidate(chapterDetailsProvider((courseId: widget.courseId, chapterId: widget.chapterId)));
      ref.invalidate(courseDetailsProvider(widget.courseId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(chapter.isPublished ? 'Chapter unpublished' : 'Chapter published!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteChapter() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chapter?'),
        content: const Text('Are you sure you want to delete this chapter? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.lightDestructive),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await ref.read(courseRepositoryProvider).deleteChapter(widget.courseId, widget.chapterId);
        if (mounted) {
          context.go('/teacher/courses/${widget.courseId}');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete chapter: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showEditTitleModal(ChapterEntity chapter) {
    final controller = TextEditingController(text: chapter.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Chapter Title'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Title')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                await ref.read(courseRepositoryProvider).updateChapter(
                  widget.courseId,
                  widget.chapterId,
                  {'title': controller.text.trim()},
                );
                ref.invalidate(chapterDetailsProvider((courseId: widget.courseId, chapterId: widget.chapterId)));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditDescriptionModal(ChapterEntity chapter) {
    final controller = TextEditingController(text: chapter.description ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Chapter Description'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Description (Markdown supported)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(courseRepositoryProvider).updateChapter(
                widget.courseId,
                widget.chapterId,
                {'description': controller.text.trim()},
              );
              ref.invalidate(chapterDetailsProvider((courseId: widget.courseId, chapterId: widget.chapterId)));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditVideoModal(ChapterEntity chapter) {
    final controller = TextEditingController(text: chapter.videoUrl ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upload / Set Video URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter video URL (e.g. from UploadThing/storage). The server will process it through Mux.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(controller: controller, decoration: const InputDecoration(labelText: 'Video URL')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final url = controller.text.trim();
              Navigator.pop(ctx);
              await ref.read(courseRepositoryProvider).updateChapter(
                widget.courseId,
                widget.chapterId,
                {'videoUrl': url},
              );
              ref.invalidate(chapterDetailsProvider((courseId: widget.courseId, chapterId: widget.chapterId)));
            },
            child: const Text('Save & Process'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompact = Breakpoints.isCompact(context);

    final chapterAsync = ref.watch(chapterDetailsProvider((
      courseId: widget.courseId,
      chapterId: widget.chapterId,
    )));

    return ResponsiveLayout(
      title: 'Chapter Setup',
      currentRoute: '/teacher/courses',
      body: chapterAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorStateWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(chapterDetailsProvider((courseId: widget.courseId, chapterId: widget.chapterId))),
        ),
        data: (data) {
          final chapter = data['chapter'] != null
              ? ChapterEntity.fromJson(data['chapter'] as Map<String, dynamic>)
              : null;
          final muxPlaybackId = data['muxData']?['playbackId'] as String?;

          if (chapter == null) {
            return const EmptyStateWidget(
              icon: Icons.error_outline_rounded,
              title: 'Chapter not found',
              description: 'This chapter does not exist or has been removed.',
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back link
                InkWell(
                  onTap: () => context.go('/teacher/courses/${widget.courseId}'),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.arrow_back_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Back to course setup', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Draft banner
                if (!chapter.isPublished)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.brandAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.brandAmber),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'This chapter is unpublished. It will not be visible in the course.',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.amber),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Top Header with Actions
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Chapter Creation', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Complete all fields (title, description, and video)', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: chapter.isPublished ? colorScheme.surfaceContainerHighest : AppColors.brandEmerald,
                        foregroundColor: chapter.isPublished ? colorScheme.onSurface : Colors.white,
                      ),
                      onPressed: _isLoading ? null : () => _togglePublish(chapter),
                      child: Text(chapter.isPublished ? 'Unpublish' : 'Publish'),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.lightDestructive),
                      onPressed: _isLoading ? null : _deleteChapter,
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // 2 Columns or single stack
                isCompact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailsCard(chapter),
                          const SizedBox(height: 24),
                          _buildAccessCard(chapter),
                          const SizedBox(height: 24),
                          _buildVideoCard(chapter, muxPlaybackId),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailsCard(chapter),
                                const SizedBox(height: 24),
                                _buildAccessCard(chapter),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildVideoCard(chapter, muxPlaybackId),
                          ),
                        ],
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailsCard(ChapterEntity chapter) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.brandSky.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.dashboard_customize_rounded, size: 20, color: AppColors.brandSky),
            ),
            const SizedBox(width: 10),
            Text('Customize your chapter', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          child: ListTile(
            title: const Text('Chapter title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            subtitle: Text(chapter.title, style: const TextStyle(fontSize: 14)),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _showEditTitleModal(chapter),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: ListTile(
            title: const Text('Chapter description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            subtitle: Text(
              chapter.description?.isNotEmpty == true ? chapter.description! : 'No description provided',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontStyle: chapter.description?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _showEditDescriptionModal(chapter),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccessCard(ChapterEntity chapter) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.brandSky.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.visibility_rounded, size: 20, color: AppColors.brandSky),
            ),
            const SizedBox(width: 10),
            Text('Access Settings', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          child: CheckboxListTile(
            value: chapter.isFree,
            title: const Text('Free Preview', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: const Text(
              'Check this box if you want to make this chapter free for preview without purchasing.',
              style: TextStyle(fontSize: 12),
            ),
            onChanged: (val) async {
              if (val != null) {
                await ref.read(courseRepositoryProvider).updateChapter(
                  widget.courseId,
                  widget.chapterId,
                  {'isFree': val},
                );
                ref.invalidate(chapterDetailsProvider((courseId: widget.courseId, chapterId: widget.chapterId)));
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVideoCard(ChapterEntity chapter, String? muxPlaybackId) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.brandSky.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.video_call_rounded, size: 20, color: AppColors.brandSky),
            ),
            const SizedBox(width: 10),
            Text('Add a video', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(chapter.videoUrl != null ? 'Change video' : 'Add video'),
              onPressed: () => _showEditVideoModal(chapter),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (muxPlaybackId != null && muxPlaybackId.isNotEmpty)
                MuxVideoPlayer(playbackId: muxPlaybackId)
              else
                Container(
                  height: 200,
                  color: colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.video_library_outlined, size: 40, color: colorScheme.onSurfaceVariant),
                      const SizedBox(height: 10),
                      Text(
                        chapter.videoUrl != null
                            ? 'Processing video with Mux...'
                            : 'No video uploaded yet.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'Videos are processed using Mux for optimal HLS adaptive bitrate streaming.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
