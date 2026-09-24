import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/community_repository.dart';
import '../domain/community_entity.dart';

final selectedSpaceProvider = StateProvider.autoDispose<String?>((ref) => null);

final communitySpacesProvider =
    FutureProvider.autoDispose<List<CommunitySpaceEntity>>((ref) async {
  final repo = ref.watch(communityRepositoryProvider);
  return repo.getSpaces();
});

final communityPostsProvider =
    FutureProvider.autoDispose<List<CommunityPostEntity>>((ref) async {
  final repo = ref.watch(communityRepositoryProvider);
  final spaceId = ref.watch(selectedSpaceProvider);
  return repo.getPosts(spaceId: spaceId);
});

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  void _showCreatePostModal(List<CommunitySpaceEntity> spaces) {
    if (spaces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create a space first before posting.')),
      );
      return;
    }

    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String selectedSpaceId = ref.read(selectedSpaceProvider) ?? spaces.first.id;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Create Community Post'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedSpaceId,
                  decoration: const InputDecoration(labelText: 'Space'),
                  items: spaces
                      .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedSpaceId = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'What is on your mind? *'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final content = contentCtrl.text.trim();
                if (title.isNotEmpty && content.isNotEmpty) {
                  Navigator.pop(ctx);
                  await ref.read(communityRepositoryProvider).createPost(selectedSpaceId, title, content);
                  ref.invalidate(communityPostsProvider);
                }
              },
              child: const Text('Publish Post'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentUser = ref.watch(currentUserProvider);
    final isTeacher = currentUser?.isTeacher ?? false;
    final selectedSpace = ref.watch(selectedSpaceProvider);

    final spacesAsync = ref.watch(communitySpacesProvider);
    final postsAsync = ref.watch(communityPostsProvider);

    return ResponsiveLayout(
      title: 'Community',
      currentRoute: isTeacher ? '/teacher/community' : '/community',
      actions: [
        if (isTeacher)
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Community Settings',
            onPressed: () => context.go('/teacher/community/settings'),
          ),
      ],
      floatingActionButton: spacesAsync.maybeWhen(
        data: (spaces) => FloatingActionButton.extended(
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Post'),
          onPressed: () => _showCreatePostModal(spaces),
        ),
        orElse: () => null,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(communitySpacesProvider);
          ref.invalidate(communityPostsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Spaces Horizontal Bar
              spacesAsync.when(
                loading: () => const SkeletonLoader(width: double.infinity, height: 40, borderRadius: 20),
                error: (_, _) => const SizedBox.shrink(),
                data: (spaces) => SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          selected: selectedSpace == null,
                          label: const Text('All Spaces'),
                          showCheckmark: false,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: selectedSpace == null ? colorScheme.primary : colorScheme.outline,
                            ),
                          ),
                          selectedColor: colorScheme.primary,
                          backgroundColor: colorScheme.surface,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selectedSpace == null ? colorScheme.onPrimary : colorScheme.onSurface,
                          ),
                          onSelected: (_) => ref.read(selectedSpaceProvider.notifier).state = null,
                        ),
                      ),
                      ...spaces.map((s) {
                        final isSelected = selectedSpace == s.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            selected: isSelected,
                            label: Text(s.name),
                            showCheckmark: false,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected ? colorScheme.primary : colorScheme.outline,
                              ),
                            ),
                            selectedColor: colorScheme.primary,
                            backgroundColor: colorScheme.surface,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                            ),
                            onSelected: (_) {
                              ref.read(selectedSpaceProvider.notifier).state = isSelected ? null : s.id;
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Posts List
              postsAsync.when(
                loading: () => Column(
                  children: List.generate(
                    3,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: SkeletonLoader(width: double.infinity, height: 140, borderRadius: 12),
                    ),
                  ),
                ),
                error: (err, _) => ErrorStateWidget(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(communityPostsProvider),
                ),
                data: (posts) {
                  if (posts.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.forum_outlined,
                      title: 'No community posts yet',
                      description: 'Be the first to share an update, start a discussion, or ask a question.',
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: posts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return _PostCard(post: post);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostCard extends ConsumerStatefulWidget {
  final CommunityPostEntity post;

  const _PostCard({required this.post});

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> {
  bool _showComments = false;
  final _commentController = TextEditingController();
  List<CommunityCommentEntity> _comments = [];
  bool _loadingComments = false;

  Future<void> _fetchComments() async {
    setState(() => _loadingComments = true);
    try {
      final res = await ref.read(communityRepositoryProvider).getComments(widget.post.id);
      setState(() => _comments = res);
    } catch (_) {
    } finally {
      setState(() => _loadingComments = false);
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _commentController.clear();
    try {
      final c = await ref.read(communityRepositoryProvider).addComment(widget.post.id, text);
      setState(() => _comments.add(c));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add comment: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final post = widget.post;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author header
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.brandSky.withValues(alpha: 0.15),
                  child: Text(
                    (post.authorId.isNotEmpty ? post.authorId[0] : 'U').toUpperCase(),
                    style: const TextStyle(color: AppColors.brandSky, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Member', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          if (post.isPinned) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.brandAmber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('Pinned', style: TextStyle(fontSize: 10, color: Colors.amber[900], fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        DateFormat.yMMMd().format(post.createdAt),
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title & Content
            Text(post.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(post.content, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, height: 1.5)),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Comments Toggle
            InkWell(
              onTap: () {
                final next = !_showComments;
                setState(() => _showComments = next);
                if (next) _fetchComments();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.mode_comment_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _showComments ? 'Hide comments' : 'Comments (${post.commentsCount})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

            // Comments list & form
            if (_showComments) ...[
              const SizedBox(height: 12),
              if (_loadingComments)
                const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
              else ...[
                ..._comments.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(c.content, style: const TextStyle(fontSize: 12)),
                      ),
                    )),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Write a comment...',
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: AppColors.brandSky, size: 20),
                      onPressed: _addComment,
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
