import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:termini/core/theme/app_colors.dart';
import 'package:termini/core/utils/breakpoints.dart';

import '../../domain/course_entity.dart';

class CourseCard extends StatelessWidget {
  final CourseEntity course;
  final bool youtubeStyle;

  const CourseCard({
    super.key,
    required this.course,
    this.youtubeStyle = false,
  });

  Widget _thumbnail(BuildContext context, {double? width, double? height}) {
    final colorScheme = Theme.of(context).colorScheme;
    final image = course.imageUrl?.trim();
    return SizedBox(
      width: width,
      height: height,
      child: image != null && image.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: image,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                color: colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const Icon(Icons.image_outlined, size: 26),
              ),
              errorWidget: (_, _, _) => Container(
                color: colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined, size: 26),
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
              alignment: Alignment.center,
              child: const Icon(
                Icons.school_outlined,
                size: 32,
                color: AppColors.brandSky,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final enrolled = course.isPurchased || course.progress != null;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/course/${course.id}'),
        child: Breakpoints.isCompact(context) && youtubeStyle
            ? _buildYoutubeCard(context, enrolled)
            : Breakpoints.isCompact(context)
            ? _buildCompact(context, enrolled)
            : _buildGridCard(context, enrolled),
      ),
    );
  }

  Widget _buildYoutubeCard(BuildContext context, bool enrolled) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = ((course.progress ?? 0) / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            AspectRatio(aspectRatio: 16 / 9, child: _thumbnail(context)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: enrolled ? progress : 0,
                minHeight: 4,
                backgroundColor: Colors.black.withValues(alpha: 0.35),
                valueColor: AlwaysStoppedAnimation(
                  course.progress == 100
                      ? AppColors.brandEmerald
                      : AppColors.brandSky,
                ),
              ),
            ),
            Positioned(
              left: 10,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  course.category?.name ?? 'Course',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${course.chaptersCount} ${course.chaptersCount == 1 ? 'lesson' : 'lessons'}  ·  ${course.category?.name ?? 'Course'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(
                      course.progress == 100
                          ? Icons.check_circle_rounded
                          : Icons.play_circle_outline_rounded,
                      size: 17,
                      color: course.progress == 100
                          ? AppColors.brandEmerald
                          : colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        course.progress == 100
                            ? 'Course completed'
                            : 'Continue learning',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: course.progress == 100
                              ? AppColors.brandEmerald
                              : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (enrolled)
                      Text(
                        '${(course.progress ?? 0).toInt()}%',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: course.progress == 100
                              ? AppColors.brandEmerald
                              : colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompact(BuildContext context, bool enrolled) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 122,
          height: double.infinity,
          child: _thumbnail(context),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
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
                    const SizedBox(height: 5),
                    Text(
                      '${course.category?.name ?? 'Course'}  ·  ${course.chaptersCount} ${course.chaptersCount == 1 ? 'lesson' : 'lessons'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (enrolled) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ((course.progress ?? 0) / 100).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        course.progress == 100
                            ? AppColors.brandEmerald
                            : AppColors.brandSky,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        course.progress == 100
                            ? 'Completed'
                            : 'Continue learning',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: course.progress == 100
                              ? AppColors.brandEmerald
                              : colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ] else
                  Row(
                    children: [
                      Text(
                        course.price == null || course.price == 0
                            ? 'Free'
                            : '\$${course.price!.toStringAsFixed(2)}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: course.price == null || course.price == 0
                              ? AppColors.brandEmerald
                              : colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridCard(BuildContext context, bool enrolled) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(aspectRatio: 16 / 9, child: _thumbnail(context)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
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
                const SizedBox(height: 4),
                Text(
                  '${course.category?.name ?? 'Course'}  ·  ${course.chaptersCount} ${course.chaptersCount == 1 ? 'lesson' : 'lessons'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (enrolled) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ((course.progress ?? 0) / 100).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        course.progress == 100
                            ? AppColors.brandEmerald
                            : AppColors.brandSky,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    course.progress == 100
                        ? 'Completed'
                        : '${(course.progress ?? 0).toInt()}% complete',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: course.progress == 100
                          ? AppColors.brandEmerald
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ] else
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
            ),
          ),
        ),
      ],
    );
  }
}
