import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../utils/breakpoints.dart';

class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF262626) : const Color(0xFFE5E5E5),
      highlightColor: isDark
          ? const Color(0xFF333333)
          : const Color(0xFFF5F5F5),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class CourseCardSkeleton extends StatelessWidget {
  final bool youtubeStyle;

  const CourseCardSkeleton({super.key, this.youtubeStyle = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      child: Breakpoints.isCompact(context) && youtubeStyle
          ? Column(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: SizedBox.expand(
                    child: const SkeletonLoader(
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: 0,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonLoader(width: 210, height: 18),
                        SizedBox(height: 7),
                        SkeletonLoader(width: 150, height: 14),
                        Spacer(),
                        SkeletonLoader(width: double.infinity, height: 5),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : Breakpoints.isCompact(context)
          ? SizedBox.expand(
              child: Row(
                children: [
                  const SizedBox(
                    width: 122,
                    height: double.infinity,
                    child: SkeletonLoader(
                      width: 122,
                      height: double.infinity,
                      borderRadius: 0,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SkeletonLoader(width: 150, height: 18),
                          SkeletonLoader(width: 120, height: 14),
                          SkeletonLoader(width: double.infinity, height: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLoader(
                  width: double.infinity,
                  height: 160,
                  borderRadius: 0,
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonLoader(width: 80, height: 16),
                      SizedBox(height: 10),
                      SkeletonLoader(width: double.infinity, height: 20),
                      SizedBox(height: 8),
                      SkeletonLoader(width: 140, height: 16),
                      SizedBox(height: 14),
                      SkeletonLoader(width: 60, height: 18),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
