import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../data/course_repository.dart';
import '../domain/course_entity.dart';
import '../../dashboard/presentation/dashboard_controller.dart';

final courseDetailProvider = FutureProvider.autoDispose
    .family<CourseEntity, String>((ref, courseId) async {
      final repo = ref.watch(courseRepositoryProvider);
      return repo.getCourseDetails(courseId);
    });

class CourseDetailScreen extends ConsumerWidget {
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final courseAsync = ref.watch(courseDetailProvider(courseId));

    return ResponsiveLayout(
      title: 'Course Details',
      currentRoute: '/course/$courseId',
      body: courseAsync.when(
        loading: () => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SkeletonLoader(
                width: double.infinity,
                height: 260,
                borderRadius: 16,
              ),
              SizedBox(height: 24),
              SkeletonLoader(width: 300, height: 32),
              SizedBox(height: 12),
              SkeletonLoader(width: double.infinity, height: 80),
              SizedBox(height: 24),
              SkeletonLoader(
                width: double.infinity,
                height: 200,
                borderRadius: 12,
              ),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Course not found',
            description: err.toString(),
            actionLabel: 'Back to Browse',
            onAction: () => context.go('/search'),
          ),
        ),
        data: (course) {
          final publishedChapters = course.chapters
              .where((c) => c.isPublished)
              .toList();
          final firstChapter = publishedChapters.isNotEmpty
              ? publishedChapters.first
              : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Course Hero Card
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colorScheme.outline),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.35 : 0.05,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Thumbnail Banner
                          if (course.imageUrl != null &&
                              course.imageUrl!.isNotEmpty)
                            AspectRatio(
                              aspectRatio: 21 / 9,
                              child: CachedNetworkImage(
                                imageUrl: course.imageUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (ctx, url, err) => Container(
                                  color: colorScheme.surfaceContainerHighest,
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image_rounded,
                                      size: 36,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              height: 140,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.brandSky.withValues(alpha: 0.2),
                                    AppColors.brandIndigo.withValues(
                                      alpha: 0.3,
                                    ),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.school_rounded,
                                  size: 48,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),

                          // Header Info
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (course.category != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.brandSky.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          course.category!.name,
                                          style: TextStyle(
                                            color: isDark
                                                ? AppColors.brandSkyLight
                                                : AppColors.brandSky,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    const Spacer(),
                                    if (course.isPurchased)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.brandEmerald
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle_rounded,
                                              size: 16,
                                              color: AppColors.brandEmerald,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'Enrolled',
                                              style: TextStyle(
                                                color: AppColors.brandEmerald,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Text(
                                        course.price == null ||
                                                course.price == 0
                                            ? 'Free'
                                            : '\$${course.price!.toStringAsFixed(2)}',
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              color:
                                                  course.price == null ||
                                                      course.price == 0
                                                  ? const Color(0xFF10B981)
                                                  : null,
                                            ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  course.title,
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                      ),
                                ),
                                if (course.description != null &&
                                    course.description!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    course.description!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),
                                if (!course.isPurchased &&
                                    firstChapter != null) ...[
                                  _EnrollCourseButton(
                                    courseId: course.id,
                                    price: course.price,
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                SizedBox(
                                  width: double.infinity,
                                  child: firstChapter == null
                                      ? OutlinedButton(
                                          onPressed: null,
                                          child: const Text(
                                            'No chapters published yet',
                                          ),
                                        )
                                      : course.isPurchased
                                      ? FilledButton.icon(
                                          onPressed: () => context.push(
                                            '/course/${course.id}/chapters/${firstChapter.id}',
                                          ),
                                          icon: const Icon(
                                            Icons.play_arrow_rounded,
                                            size: 22,
                                          ),
                                          label: const Text(
                                            'Continue Learning',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        )
                                      : OutlinedButton.icon(
                                          onPressed: () => context.push(
                                            '/course/${course.id}/chapters/${firstChapter.id}',
                                          ),
                                          icon: const Icon(
                                            Icons.play_circle_outline_rounded,
                                          ),
                                          label: const Text(
                                            'Preview first lesson',
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Syllabus / Chapters List
                    Text(
                      'Course Syllabus (${publishedChapters.length} chapters)',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (publishedChapters.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outline),
                        ),
                        child: const Center(
                          child: Text(
                            'Instructor is preparing chapter content for this course.',
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: publishedChapters.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final chapter = publishedChapters[index];
                          final isFirst = index == 0;
                          return InkWell(
                            onTap: () {
                              context.push(
                                '/course/${course.id}/chapters/${chapter.id}',
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colorScheme.outline),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color:
                                          colorScheme.surfaceContainerHighest,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          chapter.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (chapter.isFree)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              'Free Preview',
                                              style: TextStyle(
                                                color: isDark
                                                    ? AppColors.brandSkyLight
                                                    : AppColors.brandSky,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    chapter.isFree || isFirst
                                        ? Icons.play_circle_outline_rounded
                                        : Icons.lock_outline_rounded,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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

class _EnrollCourseButton extends ConsumerStatefulWidget {
  final String courseId;
  final double? price;

  const _EnrollCourseButton({required this.courseId, required this.price});

  @override
  ConsumerState<_EnrollCourseButton> createState() =>
      _EnrollCourseButtonState();
}

class _EnrollCourseButtonState extends ConsumerState<_EnrollCourseButton> {
  bool _isStartingCheckout = false;

  Future<void> _startCheckout() async {
    setState(() => _isStartingCheckout = true);
    try {
      final result = await ref
          .read(courseRepositoryProvider)
          .createCheckoutSession(
            widget.courseId,
            returnUrl:
                'termini://course/${Uri.encodeComponent(widget.courseId)}',
          );
      if (result.enrolled) {
        ref.invalidate(dashboardControllerProvider);
        ref.invalidate(courseDetailProvider(widget.courseId));
        if (mounted) context.go('/');
        return;
      }

      final checkoutUrl = result.checkoutUrl;
      final uri = checkoutUrl == null ? null : Uri.tryParse(checkoutUrl);
      if (uri == null || !uri.hasAuthority || !uri.scheme.startsWith('http')) {
        throw Exception(
          'The server did not return a valid Stripe checkout link.',
        );
      }
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open Stripe Checkout.');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start checkout: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingCheckout = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFree = widget.price == null || widget.price == 0;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isStartingCheckout ? null : _startCheckout,
        icon: _isStartingCheckout
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.lock_outline_rounded),
        label: Text(
          _isStartingCheckout
              ? 'Preparing secure checkout…'
              : isFree
              ? 'Enroll for Free'
              : 'Enroll for \$${widget.price!.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
