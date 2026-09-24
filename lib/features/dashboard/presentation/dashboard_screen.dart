import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../courses/presentation/widgets/course_card.dart';
import 'dashboard_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dashboardAsync = ref.watch(dashboardControllerProvider);

    return ResponsiveLayout(
      title: 'Dashboard',
      currentRoute: '/',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardControllerProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: dashboardAsync.when(
            loading: () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Expanded(child: SkeletonLoader(width: double.infinity, height: 80, borderRadius: 12)),
                    SizedBox(width: 16),
                    Expanded(child: SkeletonLoader(width: double.infinity, height: 80, borderRadius: 12)),
                  ],
                ),
                const SizedBox(height: 32),
                const SkeletonLoader(width: 200, height: 24),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: Breakpoints.getGridCrossAxisCount(context),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: 4,
                  itemBuilder: (context, index) => const CourseCardSkeleton(),
                ),
              ],
            ),
            error: (err, st) => ErrorStateWidget(
              message: err.toString(),
              onRetry: () => ref.invalidate(dashboardControllerProvider),
            ),
            data: (data) {
              final inProgress = data.coursesInProgress;
              final completed = data.completedCourses;
              final hasCourses = inProgress.isNotEmpty || completed.isNotEmpty;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Cards Row
                  Row(
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
                          iconBgColor: AppColors.brandEmerald.withValues(alpha: 0.1),
                          label: 'Completed',
                          count: completed.length,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  if (!hasCourses) ...[
                    EmptyStateWidget(
                      icon: Icons.auto_stories_outlined,
                      title: 'No courses found',
                      description: 'You have not enrolled in any courses yet. Browse our catalog to get started.',
                      actionLabel: 'Browse Courses',
                      onAction: () => context.go('/search'),
                    ),
                  ] else ...[
                    // Courses in Progress
                    if (inProgress.isNotEmpty) ...[
                      Text(
                        'Courses in progress',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: Breakpoints.getGridCrossAxisCount(context),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: inProgress.length,
                        itemBuilder: (context, index) => CourseCard(course: inProgress[index]),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Completed Courses
                    if (completed.isNotEmpty) ...[
                      Text(
                        'Completed courses',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: Breakpoints.getGridCrossAxisCount(context),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: completed.length,
                        itemBuilder: (context, index) => CourseCard(course: completed[index]),
                      ),
                    ],
                  ],
                ],
              );
            },
          ),
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
