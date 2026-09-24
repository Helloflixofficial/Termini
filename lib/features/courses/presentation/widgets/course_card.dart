import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:termini/core/theme/app_colors.dart';
import '../../domain/course_entity.dart';

class CourseCard extends StatelessWidget {
  final CourseEntity course;

  const CourseCard({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.go('/course/${course.id}');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            AspectRatio(
              aspectRatio: 16 / 9,
              child: course.imageUrl != null && course.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: course.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: Icon(Icons.image_outlined, size: 28),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined, size: 28),
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.brandSky.withValues(alpha: 0.15),
                            AppColors.brandIndigo.withValues(alpha: 0.25),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.school_outlined,
                          size: 36,
                          color: AppColors.brandSky,
                        ),
                      ),
                    ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Category
                  if (course.category != null)
                    Text(
                      course.category!.name,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Chapter count
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.brandSky.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_stories_outlined,
                          size: 14,
                          color: AppColors.brandSky,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${course.chaptersCount} ${course.chaptersCount == 1 ? "Chapter" : "Chapters"}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Progress Bar or Price
                  if (course.progress != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (course.progress! / 100).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          course.progress! == 100
                              ? AppColors.brandEmerald
                              : AppColors.brandSky,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${course.progress!.toInt()}% Complete',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: course.progress! == 100
                            ? AppColors.brandEmerald
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ] else ...[
                    Text(
                      course.price == null || course.price == 0
                          ? 'Free'
                          : '\$${course.price!.toStringAsFixed(2)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
