import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../courses/data/course_repository.dart';
import '../../courses/domain/course_entity.dart';
import '../../courses/presentation/search_screen.dart';

final teacherCourseEditorProvider = FutureProvider.autoDispose
    .family<CourseEntity, String>((ref, courseId) async {
  final repo = ref.watch(courseRepositoryProvider);
  return repo.getCourseDetails(courseId);
});

class CourseEditorScreen extends ConsumerStatefulWidget {
  final String courseId;

  const CourseEditorScreen({super.key, required this.courseId});

  @override
  ConsumerState<CourseEditorScreen> createState() => _CourseEditorScreenState();
}

class _CourseEditorScreenState extends ConsumerState<CourseEditorScreen> {
  bool _isActionLoading = false;

  Future<void> _togglePublish(CourseEntity course) async {
    setState(() => _isActionLoading = true);
    try {
      final repo = ref.read(courseRepositoryProvider);
      if (course.isPublished) {
        await repo.unpublishCourse(course.id);
      } else {
        await repo.publishCourse(course.id);
      }
      ref.invalidate(teacherCourseEditorProvider(widget.courseId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(course.isPublished ? 'Course unpublished.' : 'Course published!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _deleteCourse() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Course?'),
        content: const Text('Are you sure you want to delete this course? This action cannot be undone.'),
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
      setState(() => _isActionLoading = true);
      try {
        await ref.read(courseRepositoryProvider).deleteCourse(widget.courseId);
        if (mounted) {
          context.go('/teacher/courses');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete course: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isActionLoading = false);
      }
    }
  }

  void _showEditTitleModal(CourseEntity course) {
    final controller = TextEditingController(text: course.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Course Title'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                Navigator.pop(ctx);
                await ref.read(courseRepositoryProvider).updateCourse(course.id, {'title': newTitle});
                ref.invalidate(teacherCourseEditorProvider(widget.courseId));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditDescriptionModal(CourseEntity course) {
    final controller = TextEditingController(text: course.description ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Course Description'),
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
              await ref.read(courseRepositoryProvider).updateCourse(course.id, {'description': controller.text.trim()});
              ref.invalidate(teacherCourseEditorProvider(widget.courseId));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditImageModal(CourseEntity course) {
    final controller = TextEditingController(text: course.imageUrl ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Course Thumbnail Image URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Image URL'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(courseRepositoryProvider).updateCourse(course.id, {'imageUrl': controller.text.trim()});
              ref.invalidate(teacherCourseEditorProvider(widget.courseId));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditPriceModal(CourseEntity course) {
    final controller = TextEditingController(text: course.price?.toString() ?? '0');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Course Price (USD)'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Price', prefixText: '\$ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final p = double.tryParse(controller.text.trim());
              if (p != null) {
                Navigator.pop(ctx);
                await ref.read(courseRepositoryProvider).updateCourse(course.id, {'price': p});
                ref.invalidate(teacherCourseEditorProvider(widget.courseId));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddChapterModal() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Chapter'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "e.g. 'Introduction to the course'"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final title = controller.text.trim();
              if (title.isNotEmpty) {
                Navigator.pop(ctx);
                await ref.read(courseRepositoryProvider).createChapter(widget.courseId, title);
                ref.invalidate(teacherCourseEditorProvider(widget.courseId));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAddAttachmentModal() {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Attachment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'File Name')),
            const SizedBox(height: 12),
            TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'URL')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final url = urlCtrl.text.trim();
              if (name.isNotEmpty && url.isNotEmpty) {
                Navigator.pop(ctx);
                await ref.read(courseRepositoryProvider).addAttachment(widget.courseId, name, url);
                ref.invalidate(teacherCourseEditorProvider(widget.courseId));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final courseAsync = ref.watch(teacherCourseEditorProvider(widget.courseId));
    final categoriesAsync = ref.watch(categoriesProvider);
    final isCompact = Breakpoints.isCompact(context);

    return ResponsiveLayout(
      title: 'Course Setup',
      currentRoute: '/teacher/courses',
      body: courseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorStateWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(teacherCourseEditorProvider(widget.courseId)),
        ),
        data: (course) {

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Unpublished Banner
                if (!course.isPublished)
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
                        Expanded(
                          child: Text(
                            'This course is unpublished. It will not be visible to students.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber[900],
                            ),
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
                          Text(
                            'Course setup',
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Complete all required fields to publish your course',
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: course.isPublished ? colorScheme.surfaceContainerHighest : AppColors.brandEmerald,
                        foregroundColor: course.isPublished ? colorScheme.onSurface : Colors.white,
                      ),
                      onPressed: _isActionLoading ? null : () => _togglePublish(course),
                      child: Text(course.isPublished ? 'Unpublish' : 'Publish'),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.lightDestructive),
                      onPressed: _isActionLoading ? null : _deleteCourse,
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Grid or Column layout
                isCompact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCustomizeSection(course, categoriesAsync),
                          const SizedBox(height: 24),
                          _buildChaptersSection(course),
                          const SizedBox(height: 24),
                          _buildPriceAndAttachmentsSection(course),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildCustomizeSection(course, categoriesAsync)),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildChaptersSection(course),
                                const SizedBox(height: 24),
                                _buildPriceAndAttachmentsSection(course),
                              ],
                            ),
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

  Widget _buildCustomizeSection(CourseEntity course, AsyncValue<List<CategoryEntity>> categoriesAsync) {
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
            Text('Customize your course', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),

        // Title Box
        Card(
          elevation: 0,
          child: ListTile(
            title: const Text('Course title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            subtitle: Text(course.title, style: const TextStyle(fontSize: 14)),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _showEditTitleModal(course),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Description Box
        Card(
          elevation: 0,
          child: ListTile(
            title: const Text('Course description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            subtitle: Text(
              course.description?.isNotEmpty == true ? course.description! : 'No description provided',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontStyle: course.description?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _showEditDescriptionModal(course),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Image Box
        Card(
          elevation: 0,
          child: ListTile(
            title: const Text('Course image', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            subtitle: Text(
              course.imageUrl?.isNotEmpty == true ? course.imageUrl! : 'No image URL provided',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontStyle: course.imageUrl?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _showEditImageModal(course),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Category Box
        Card(
          elevation: 0,
          child: ListTile(
            title: const Text('Course category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            subtitle: Text(
              course.category?.name ?? 'No category selected',
              style: TextStyle(
                fontSize: 13,
                fontStyle: course.category != null ? FontStyle.normal : FontStyle.italic,
              ),
            ),
            trailing: categoriesAsync.maybeWhen(
              data: (categories) => PopupMenuButton<String>(
                icon: const Icon(Icons.arrow_drop_down_rounded),
                onSelected: (catId) async {
                  await ref.read(courseRepositoryProvider).updateCourse(course.id, {'categoryId': catId});
                  ref.invalidate(teacherCourseEditorProvider(widget.courseId));
                },
                itemBuilder: (ctx) => categories
                    .map((c) => PopupMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChaptersSection(CourseEntity course) {
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
              child: const Icon(Icons.list_alt_rounded, size: 20, color: AppColors.brandSky),
            ),
            const SizedBox(width: 10),
            Text('Course chapters', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add chapter'),
              onPressed: _showAddChapterModal,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: course.chapters.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(
                    child: Text(
                      'No chapters yet. Click "+ Add chapter" above.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: course.chapters.length,
                  // ignore: deprecated_member_use
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final items = List<ChapterEntity>.from(course.chapters);
                    final moved = items.removeAt(oldIndex);
                    items.insert(newIndex, moved);

                    final reorderList = items.asMap().entries.map((e) {
                      return {'id': e.value.id, 'position': e.key + 1};
                    }).toList();

                    await ref.read(courseRepositoryProvider).reorderChapters(course.id, reorderList);
                    ref.invalidate(teacherCourseEditorProvider(widget.courseId));
                  },
                  itemBuilder: (context, index) {
                    final ch = course.chapters[index];
                    return ListTile(
                      key: ValueKey(ch.id),
                      leading: const Icon(Icons.drag_handle_rounded, size: 20),
                      title: Text(ch.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Row(
                        children: [
                          if (ch.isFree)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.brandAmber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('Free', style: TextStyle(fontSize: 10, color: Colors.amber[900], fontWeight: FontWeight.bold)),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ch.isPublished ? AppColors.brandEmerald.withValues(alpha: 0.1) : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              ch.isPublished ? 'Published' : 'Draft',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: ch.isPublished ? AppColors.brandEmerald : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () {
                          context.go('/teacher/courses/${course.id}/chapters/${ch.id}');
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPriceAndAttachmentsSection(CourseEntity course) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Price Card
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.brandSky.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.attach_money_rounded, size: 20, color: AppColors.brandSky),
            ),
            const SizedBox(width: 10),
            Text('Sell your course', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: ListTile(
            title: const Text('Course price', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            subtitle: Text(
              course.price != null ? '\$${course.price!.toStringAsFixed(2)}' : 'Free / Not set',
              style: const TextStyle(fontSize: 14),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _showEditPriceModal(course),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Attachments Card
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.brandSky.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.attach_file_rounded, size: 20, color: AppColors.brandSky),
            ),
            const SizedBox(width: 10),
            Text('Resources & Attachments', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add file'),
              onPressed: _showAddAttachmentModal,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: course.attachments.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text('No attachments added yet.', style: TextStyle(fontStyle: FontStyle.italic)),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: course.attachments.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final att = course.attachments[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.file_present_rounded, size: 20),
                      title: Text(att.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.lightDestructive),
                        onPressed: () async {
                          await ref.read(courseRepositoryProvider).deleteAttachment(course.id, att.id);
                          ref.invalidate(teacherCourseEditorProvider(widget.courseId));
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
