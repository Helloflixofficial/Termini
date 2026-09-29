import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/breakpoints.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../data/course_repository.dart';
import '../domain/course_entity.dart';
import 'widgets/course_card.dart';

final selectedCategoryProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final categoriesProvider = FutureProvider.autoDispose<List<CategoryEntity>>((
  ref,
) {
  final repo = ref.watch(courseRepositoryProvider);
  return repo.getCategories();
});

final searchCoursesProvider = FutureProvider.autoDispose<List<CourseEntity>>((
  ref,
) {
  final repo = ref.watch(courseRepositoryProvider);
  final categoryId = ref.watch(selectedCategoryProvider);
  final title = ref.watch(searchQueryProvider);
  return repo.getCourses(title: title, categoryId: categoryId);
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('computer') ||
        lower.contains('tech') ||
        lower.contains('code')) {
      return Icons.computer_rounded;
    }
    if (lower.contains('music')) {
      return Icons.music_note_rounded;
    }
    if (lower.contains('fitness') || lower.contains('sport')) {
      return Icons.fitness_center_rounded;
    }
    if (lower.contains('photo')) {
      return Icons.camera_alt_rounded;
    }
    if (lower.contains('account') || lower.contains('business')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (lower.contains('film') || lower.contains('video')) {
      return Icons.videocam_rounded;
    }
    if (lower.contains('engineering')) {
      return Icons.precision_manufacturing_rounded;
    }
    return Icons.category_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final coursesAsync = ref.watch(searchCoursesProvider);

    return ResponsiveLayout(
      title: 'Search',
      currentRoute: '/search',
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
            sliver: SliverToBoxAdapter(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for a course...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(searchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                ),
                onChanged: (val) {
                  ref.read(searchQueryProvider.notifier).state = val.trim();
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(
              child: categoriesAsync.when(
                loading: () => SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 6,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, _) => const SkeletonLoader(
                      width: 100,
                      height: 36,
                      borderRadius: 20,
                    ),
                  ),
                ),
                error: (_, _) => const SizedBox.shrink(),
                data: (categories) => SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        final isSelected = selectedCategory == null;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: isSelected,
                            label: const Text('All'),
                            showCheckmark: false,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.outline,
                              ),
                            ),
                            selectedColor: colorScheme.primary,
                            backgroundColor: colorScheme.surface,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurface,
                            ),
                            onSelected: (_) =>
                                ref
                                        .read(selectedCategoryProvider.notifier)
                                        .state =
                                    null,
                          ),
                        );
                      }
                      final category = categories[index - 1];
                      final isSelected = selectedCategory == category.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          avatar: Icon(
                            _getCategoryIcon(category.name),
                            size: 16,
                            color: isSelected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant,
                          ),
                          label: Text(category.name),
                          showCheckmark: false,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.outline,
                            ),
                          ),
                          selectedColor: colorScheme.primary,
                          backgroundColor: colorScheme.surface,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                          ),
                          onSelected: (_) =>
                              ref
                                  .read(selectedCategoryProvider.notifier)
                                  .state = isSelected
                              ? null
                              : category.id,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
          coursesAsync.when(
            loading: () => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverGrid(
                gridDelegate: _courseGridDelegate(context),
                delegate: SliverChildBuilderDelegate(
                  (_, _) => const CourseCardSkeleton(),
                  childCount: 6,
                ),
              ),
            ),
            error: (err, _) => SliverToBoxAdapter(
              child: ErrorStateWidget(
                message: err.toString(),
                onRetry: () => ref.invalidate(searchCoursesProvider),
              ),
            ),
            data: (courses) {
              if (courses.isEmpty) {
                return const SliverToBoxAdapter(
                  child: EmptyStateWidget(
                    icon: Icons.search_off_rounded,
                    title: 'No courses found',
                    description: 'Try adjusting your search or category filter to find what you are looking for.',
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverGrid(
                  gridDelegate: _courseGridDelegate(context),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => CourseCard(course: courses[index]),
                    childCount: courses.length,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

SliverGridDelegateWithFixedCrossAxisCount _courseGridDelegate(
  BuildContext context,
) {
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: Breakpoints.getGridCrossAxisCount(context),
    crossAxisSpacing: 16,
    mainAxisSpacing: 16,
    mainAxisExtent: Breakpoints.isCompact(context) ? 124 : null,
    childAspectRatio: 1,
  );
}
