import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/widgets/empty_state.dart';
import '../../courses/data/course_repository.dart';
import '../../courses/domain/course_entity.dart';
import 'widgets/mux_video_player.dart';

final chapterDetailsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({String courseId, String chapterId})>((
      ref,
      arg,
    ) async {
      final repo = ref.watch(courseRepositoryProvider);
      return repo.getChapterDetails(arg.courseId, arg.chapterId);
    });

final courseDetailsProvider = FutureProvider.autoDispose
    .family<CourseEntity, String>((ref, courseId) async {
      final repo = ref.watch(courseRepositoryProvider);
      return repo.getCourseDetails(courseId);
    });

class ChapterPlayerScreen extends ConsumerStatefulWidget {
  final String courseId;
  final String chapterId;

  const ChapterPlayerScreen({
    super.key,
    required this.courseId,
    required this.chapterId,
  });

  @override
  ConsumerState<ChapterPlayerScreen> createState() =>
      _ChapterPlayerScreenState();
}

class _ChapterPlayerScreenState extends ConsumerState<ChapterPlayerScreen> {
  bool _isTogglingProgress = false;
  bool _isCheckingOut = false;

  Future<void> _handleProgressToggle(bool currentCompleted) async {
    setState(() => _isTogglingProgress = true);
    try {
      final repo = ref.read(courseRepositoryProvider);
      await repo.updateChapterProgress(
        widget.courseId,
        widget.chapterId,
        !currentCompleted,
      );
      ref.invalidate(
        chapterDetailsProvider((
          courseId: widget.courseId,
          chapterId: widget.chapterId,
        )),
      );
      ref.invalidate(courseDetailsProvider(widget.courseId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !currentCompleted
                  ? 'Chapter marked as completed!'
                  : 'Progress updated.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update progress: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingProgress = false);
    }
  }

  Future<void> _handleCheckout() async {
    setState(() => _isCheckingOut = true);
    try {
      final repo = ref.read(courseRepositoryProvider);
      final checkoutUrl = await repo.createCheckoutSession(
        widget.courseId,
        returnUrl: 'termini://course/${widget.courseId}',
      );
      final uri = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch checkout URL';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompact = Breakpoints.isCompact(context);

    final chapterAsync = ref.watch(
      chapterDetailsProvider((
        courseId: widget.courseId,
        chapterId: widget.chapterId,
      )),
    );

    final courseAsync = ref.watch(courseDetailsProvider(widget.courseId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/course/${widget.courseId}'),
        ),
        title: courseAsync.maybeWhen(
          data: (course) => Text(
            course.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          orElse: () => const Text('Course Player'),
        ),
        actions: [
          const ThemeToggleButton(),
          if (isCompact)
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.playlist_play_rounded),
                tooltip: 'Course Chapters',
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      endDrawer: isCompact
          ? Drawer(
              child: SafeArea(
                child: _CourseSidebar(
                  courseId: widget.courseId,
                  currentChapterId: widget.chapterId,
                ),
              ),
            )
          : null,
      body: chapterAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorStateWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(
            chapterDetailsProvider((
              courseId: widget.courseId,
              chapterId: widget.chapterId,
            )),
          ),
        ),
        data: (data) {
          final chapter = data['chapter'] != null
              ? ChapterEntity.fromJson(data['chapter'] as Map<String, dynamic>)
              : null;
          final course = data['course'] != null
              ? CourseEntity.fromJson(data['course'] as Map<String, dynamic>)
              : null;
          final purchase = data['purchase'];
          final isPurchased = purchase != null;
          final isFree = chapter?.isFree ?? false;
          final hasAccess = isFree || isPurchased;

          final muxPlaybackId = data['muxData']?['playbackId'] as String?;
          final muxPlaybackToken = data['muxData']?['playbackToken'] as String?;
          final nextChapter = data['nextChapter'] != null
              ? ChapterEntity.fromJson(
                  data['nextChapter'] as Map<String, dynamic>,
                )
              : null;

          final isCompleted = data['userProgress']?['isCompleted'] == true;

          final attachments = (data['attachments'] as List? ?? [])
              .map((a) => AttachmentEntity.fromJson(a as Map<String, dynamic>))
              .toList();

          if (chapter == null) {
            return const EmptyStateWidget(
              icon: Icons.error_outline_rounded,
              title: 'Chapter not found',
              description: 'This chapter may have been deleted or unpublished.',
            );
          }

          final mainContent = SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Video Player or Lock Banner
                if (hasAccess &&
                    ((muxPlaybackId != null && muxPlaybackId.isNotEmpty) ||
                        (chapter.videoUrl != null &&
                            chapter.videoUrl!.isNotEmpty)))
                  MuxVideoPlayer(
                    chapterId: chapter.id,
                    playbackId: muxPlaybackId,
                    playbackToken: muxPlaybackToken,
                    fallbackVideoUrl: chapter.videoUrl,
                    onVideoEnd: () {
                      if (!isCompleted) _handleProgressToggle(false);
                    },
                  )
                else if (hasAccess)
                  Container(
                    height: 240,
                    color: Colors.black87,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.video_camera_back_outlined,
                          size: 48,
                          color: Colors.white54,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No video uploaded for this chapter yet.',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                else
                  // Locked Banner
                  Container(
                    height: 280,
                    color: colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.lock_rounded,
                              size: 36,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'This chapter is locked',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'You need to purchase this course to watch this chapter.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(
                              Icons.shopping_bag_outlined,
                              size: 18,
                            ),
                            label: _isCheckingOut
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    course?.price != null
                                        ? 'Enroll for \$${course!.price!.toStringAsFixed(2)}'
                                        : 'Enroll Now',
                                  ),
                            onPressed: _isCheckingOut ? null : _handleCheckout,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Free preview banner (if preview)
                if (isFree && !isPurchased)
                  Container(
                    width: double.infinity,
                    color: AppColors.brandAmber.withValues(alpha: 0.15),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: AppColors.brandAmber,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'This is a free preview chapter of this course.',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.amber[900],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Chapter Details & Action Buttons
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  chapter.title,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (course != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    course.title,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Actions
                          if (isPurchased) ...[
                            OutlinedButton.icon(
                              icon: Icon(
                                isCompleted
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                size: 18,
                                color: isCompleted
                                    ? AppColors.brandEmerald
                                    : null,
                              ),
                              label: Text(
                                isCompleted ? 'Completed' : 'Mark as complete',
                                style: TextStyle(
                                  color: isCompleted
                                      ? AppColors.brandEmerald
                                      : null,
                                ),
                              ),
                              onPressed: _isTogglingProgress
                                  ? null
                                  : () => _handleProgressToggle(isCompleted),
                            ),
                          ] else ...[
                            ElevatedButton(
                              onPressed: _isCheckingOut
                                  ? null
                                  : _handleCheckout,
                              child: _isCheckingOut
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      course?.price != null
                                          ? 'Enroll for \$${course!.price!.toStringAsFixed(2)}'
                                          : 'Enroll Now',
                                    ),
                            ),
                          ],
                          if (nextChapter != null && hasAccess) ...[
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.skip_next_rounded),
                              tooltip: 'Next: ${nextChapter.title}',
                              onPressed: () {
                                context.go(
                                  '/course/${widget.courseId}/chapters/${nextChapter.id}',
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Description Markdown
                      if (chapter.description != null &&
                          chapter.description!.isNotEmpty) ...[
                        Text(
                          'About this chapter',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        MarkdownBody(
                          data: chapter.description!,
                          styleSheet: MarkdownStyleSheet.fromTheme(theme)
                              .copyWith(
                                p: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.6,
                                ),
                              ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Course Attachments
                      if (attachments.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: colorScheme.outline),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.folder_open_rounded,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Files & documents',
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        Text(
                                          '${attachments.length} course ${attachments.length == 1 ? 'resource' : 'resources'}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...attachments.map((att) {
                                final extension = att.name.contains('.')
                                    ? att.name.split('.').last.toLowerCase()
                                    : '';
                                final isSource = const {
                                  'zip',
                                  'rar',
                                  '7z',
                                  'tar',
                                  'gz',
                                  'js',
                                  'jsx',
                                  'ts',
                                  'tsx',
                                  'py',
                                  'java',
                                  'c',
                                  'cpp',
                                  'html',
                                  'css',
                                  'json',
                                  'md',
                                }.contains(extension);
                                final isVideo = const {
                                  'mp4',
                                  'mov',
                                  'm4v',
                                  'webm',
                                  'mkv',
                                  'avi',
                                }.contains(extension);
                                final fileType = switch (extension) {
                                  'mp4' ||
                                  'mov' ||
                                  'm4v' ||
                                  'webm' ||
                                  'mkv' ||
                                  'avi' => 'Video file',
                                  'pdf' => 'PDF document',
                                  'doc' || 'docx' => 'Word document',
                                  'ppt' || 'pptx' => 'Presentation',
                                  'xls' || 'xlsx' || 'csv' => 'Spreadsheet',
                                  'zip' || 'rar' || '7z' => 'Archive',
                                  _ when isSource => 'Source code',
                                  _ => 'Course resource',
                                };
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Material(
                                    color: colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(11),
                                    child: ListTile(
                                      onTap: () async {
                                        final uri = Uri.parse(att.url);
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(
                                            uri,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        }
                                      },
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 3,
                                          ),
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          isVideo
                                              ? Icons.video_file_outlined
                                              : isSource
                                              ? Icons.code_rounded
                                              : Icons.description_outlined,
                                          color: colorScheme.primary,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        att.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        fileType,
                                        style: theme.textTheme.labelSmall,
                                      ),
                                      trailing: Icon(
                                        Icons.download_rounded,
                                        color: colorScheme.primary,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );

          if (isCompact) {
            return mainContent;
          }

          // Desktop/Tablet split layout with side chapter navigation
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: mainContent),
              VerticalDivider(width: 1, color: colorScheme.outline),
              Expanded(
                flex: 3,
                child: _CourseSidebar(
                  courseId: widget.courseId,
                  currentChapterId: widget.chapterId,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CourseSidebar extends ConsumerWidget {
  final String courseId;
  final String currentChapterId;

  const _CourseSidebar({
    required this.courseId,
    required this.currentChapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final courseAsync = ref.watch(courseDetailsProvider(courseId));

    return courseAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading chapters: $e')),
      data: (course) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (course.isPurchased && course.progress != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (course.progress! / 100).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.brandEmerald,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${course.progress!.toInt()}% Complete',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.brandEmerald,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: course.chapters.length,
                itemBuilder: (context, index) {
                  final ch = course.chapters[index];
                  final isActive = ch.id == currentChapterId;
                  final isLocked = !ch.isFree && !course.isPurchased;

                  return ListTile(
                    selected: isActive,
                    selectedTileColor: colorScheme.primary.withValues(
                      alpha: 0.08,
                    ),
                    leading: Icon(
                      ch.isCompleted
                          ? Icons.check_circle_rounded
                          : (isLocked
                                ? Icons.lock_outline_rounded
                                : Icons.play_circle_outline_rounded),
                      size: 20,
                      color: ch.isCompleted
                          ? AppColors.brandEmerald
                          : (isActive
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant),
                    ),
                    title: Text(
                      ch.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isActive ? colorScheme.primary : null,
                      ),
                    ),
                    trailing: ch.isFree && !course.isPurchased
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brandAmber.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Free',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[900],
                              ),
                            ),
                          )
                        : null,
                    onTap: isLocked
                        ? null
                        : () {
                            context.go('/course/$courseId/chapters/${ch.id}');
                          },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
