import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/utils/breakpoints.dart';
import '../../courses/data/course_repository.dart';
import '../../courses/domain/course_entity.dart';

final teacherCoursesProvider =
    FutureProvider.autoDispose<List<CourseEntity>>((ref) async {
  final repo = ref.watch(courseRepositoryProvider);
  return repo.getTeacherCourses();
});

class TeacherCoursesScreen extends ConsumerWidget {
  const TeacherCoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final coursesAsync = ref.watch(teacherCoursesProvider);

    return ResponsiveLayout(
      title: 'Teacher Courses',
      currentRoute: '/teacher/courses',
      actions: [
        if (Breakpoints.isCompact(context))
          IconButton(
            tooltip: 'New Course',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.go('/teacher/create'),
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New Course'),
              onPressed: () => context.go('/teacher/create'),
            ),
          ),
      ],
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(teacherCoursesProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: coursesAsync.when(
            loading: () => Column(
              children: List.generate(
                4,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: SkeletonLoader(width: double.infinity, height: 68, borderRadius: 12),
                ),
              ),
            ),
            error: (err, _) => ErrorStateWidget(
              message: err.toString(),
              onRetry: () => ref.invalidate(teacherCoursesProvider),
            ),
            data: (courses) {
              if (courses.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.list_alt_rounded,
                  title: 'No courses created yet',
                  description: 'Create your first course to share your knowledge with students.',
                  actionLabel: 'New Course',
                  onAction: () => context.go('/teacher/create'),
                );
              }

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outline),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: courses.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final course = courses[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      title: Text(
                        course.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        course.price != null
                            ? '\$${course.price!.toStringAsFixed(2)} · ${course.chaptersCount} chapters'
                            : 'Free · ${course.chaptersCount} chapters',
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: course.isPublished
                                  ? AppColors.brandEmerald.withValues(alpha: 0.1)
                                  : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              course.isPublished ? 'Published' : 'Draft',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: course.isPublished
                                    ? AppColors.brandEmerald
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded, size: 20),
                        ],
                      ),
                      onTap: () {
                        context.go('/teacher/courses/${course.id}');
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
