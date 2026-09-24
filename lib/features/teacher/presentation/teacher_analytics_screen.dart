import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/skeleton_loader.dart';

final teacherAnalyticsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(apiClientProvider);
  try {
    final res = await dio.get(ApiConstants.teacherAnalytics);
    return res.data as Map<String, dynamic>;
  } on DioException catch (e) {
    throw handleDioError(e);
  }
});

class TeacherAnalyticsScreen extends ConsumerWidget {
  const TeacherAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final analyticsAsync = ref.watch(teacherAnalyticsProvider);

    return ResponsiveLayout(
      title: 'Analytics',
      currentRoute: '/teacher/analytics',
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(teacherAnalyticsProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: analyticsAsync.when(
            loading: () => Column(
              children: const [
                SkeletonLoader(width: double.infinity, height: 100, borderRadius: 12),
                SizedBox(height: 20),
                SkeletonLoader(width: double.infinity, height: 260, borderRadius: 12),
              ],
            ),
            error: (err, _) => ErrorStateWidget(
              message: err.toString(),
              onRetry: () => ref.invalidate(teacherAnalyticsProvider),
            ),
            data: (data) {
              final totalRevenue = (data['totalRevenue'] as num?)?.toDouble() ?? 0.0;
              final totalSales = (data['totalSales'] as num?)?.toInt() ?? 0;
              final uniqueLearners = (data['uniqueLearners'] as num?)?.toInt() ?? 0;

              final monthly = (data['monthly'] as List? ?? [])
                  .map((m) => m as Map<String, dynamic>)
                  .toList();

              final coursePerformance = (data['coursePerformance'] as List? ?? [])
                  .map((c) => c as Map<String, dynamic>)
                  .toList();

              final maxRevenue = monthly.fold<double>(
                1.0,
                (prev, elem) {
                  final rev = (elem['revenue'] as num?)?.toDouble() ?? 0.0;
                  return rev > prev ? rev : prev;
                },
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      if (isMobile) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _MetricCard(
                                    title: 'Total Revenue',
                                    value: '\$${totalRevenue.toStringAsFixed(2)}',
                                    icon: Icons.attach_money_rounded,
                                    color: AppColors.brandEmerald,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _MetricCard(
                                    title: 'Total Sales',
                                    value: totalSales.toString(),
                                    icon: Icons.shopping_bag_outlined,
                                    color: AppColors.brandSky,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _MetricCard(
                              title: 'Unique Learners',
                              value: uniqueLearners.toString(),
                              icon: Icons.people_outline_rounded,
                              color: AppColors.brandIndigo,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              title: 'Total Revenue',
                              value: '\$${totalRevenue.toStringAsFixed(2)}',
                              icon: Icons.attach_money_rounded,
                              color: AppColors.brandEmerald,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _MetricCard(
                              title: 'Total Sales',
                              value: totalSales.toString(),
                              icon: Icons.shopping_bag_outlined,
                              color: AppColors.brandSky,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _MetricCard(
                              title: 'Unique Learners',
                              value: uniqueLearners.toString(),
                              icon: Icons.people_outline_rounded,
                              color: AppColors.brandIndigo,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Monthly Revenue Chart Card
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Monthly Revenue Overview', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Revenue trajectory across recent months', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
                          const SizedBox(height: 24),
                          if (monthly.isEmpty)
                            const Center(child: Text('No revenue data yet.'))
                          else
                            SizedBox(
                              height: 180,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: monthly.map((m) {
                                  final label = m['label'] as String? ?? '';
                                  final rev = (m['revenue'] as num?)?.toDouble() ?? 0.0;
                                  final fraction = maxRevenue > 0 ? (rev / maxRevenue).clamp(0.05, 1.0) : 0.05;

                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        '\$${rev.toInt()}',
                                        style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        width: 32,
                                        height: 120 * fraction,
                                        decoration: BoxDecoration(
                                          color: rev > 0 ? AppColors.chart1 : colorScheme.surfaceContainerHighest,
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Course Performance Table
                  if (coursePerformance.isNotEmpty) ...[
                    Text('Course Performance', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: coursePerformance.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final c = coursePerformance[index];
                          return ListTile(
                            title: Text(c['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${c['category'] ?? "No category"} · ${c['sales'] ?? 0} sales'),
                            trailing: Text(
                              '\$${((c['revenue'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          );
                        },
                      ),
                    ),
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
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(icon, size: 20, color: color),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
