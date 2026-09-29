import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../courses/domain/course_entity.dart';
import '../../courses/presentation/widgets/course_card.dart';
import 'dashboard_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dashboardAsync = ref.watch(dashboardControllerProvider);
    final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: Breakpoints.getGridCrossAxisCount(context),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      mainAxisExtent: Breakpoints.isCompact(context) ? 350 : null,
      childAspectRatio: 1,
    );
    final slivers = dashboardAsync.when<List<Widget>>(
      loading: () => [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: const [
                Expanded(
                  child: SkeletonLoader(
                    width: double.infinity,
                    height: 80,
                    borderRadius: 12,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: SkeletonLoader(
                    width: double.infinity,
                    height: 80,
                    borderRadius: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverToBoxAdapter(
            child: SkeletonLoader(width: 200, height: 24),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          sliver: SliverGrid(
            gridDelegate: gridDelegate,
            delegate: SliverChildBuilderDelegate(
              (_, _) => const CourseCardSkeleton(youtubeStyle: true),
              childCount: 2,
            ),
          ),
        ),
      ],
      error: (err, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorStateWidget(
            message: err.toString(),
            onRetry: () => ref.invalidate(dashboardControllerProvider),
          ),
        ),
      ],
      data: (data) {
        final inProgress = data.coursesInProgress;
        final completed = data.completedCourses;
        final hasCourses = inProgress.isNotEmpty || completed.isNotEmpty;
        final items = <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.hourglass_top_rounded,
                      iconColor: AppColors.brandSky,
                      iconBgColor: AppColors.brandSky.withValues(alpha: 0.1),
                      label: 'In Progress',
                      count: inProgress.length,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: AppColors.brandEmerald,
                      iconBgColor: AppColors.brandEmerald.withValues(
                        alpha: 0.1,
                      ),
                      label: 'Completed',
                      count: completed.length,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];

        if (!hasCourses) {
          items.add(
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyStateWidget(
                icon: Icons.auto_stories_outlined,
                title: 'No courses found',
                description: 'You have not enrolled in any courses yet. Browse our catalog to get started.',
                actionLabel: 'Browse Courses',
                onAction: () => context.go('/search'),
              ),
            ),
          );
          return items;
        }

        void addCourseSection(String title, List<CourseEntity> courses) {
          if (courses.isEmpty) return;
          items.add(
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              sliver: SliverToBoxAdapter(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
          items.add(
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverGrid(
                gridDelegate: gridDelegate,
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      CourseCard(course: courses[index], youtubeStyle: true),
                  childCount: courses.length,
                ),
              ),
            ),
          );
          items.add(const SliverToBoxAdapter(child: SizedBox(height: 32)));
        }

        addCourseSection('Courses in progress', inProgress);
        addCourseSection('Completed courses', completed);
        return items;
      },
    );

    return ResponsiveLayout(
      title: 'Dashboard',
      currentRoute: '/',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardControllerProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: slivers,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String label;
  final int count;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count ${count == 1 ? "Course" : "Courses"}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
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
