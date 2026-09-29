import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
      final userId = ref.watch(currentUserProvider)?.id;
      return repo.getPosts(spaceId: spaceId, userId: userId);
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
        const SnackBar(
          content: Text('Please create a space first before posting.'),
        ),
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
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: .5),
            ),
          ),
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.brandSky.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: AppColors.brandSky,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create a post', style: TextStyle(fontSize: 18)),
                    SizedBox(height: 3),
                    Text(
                      'Start a conversation',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedSpaceId,
                  decoration: const InputDecoration(labelText: 'Space'),
                  items: spaces
                      .map(
                        (s) =>
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedSpaceId = val);
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'What is on your mind? *',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final content = contentCtrl.text.trim();
                if (title.isNotEmpty && content.isNotEmpty) {
                  Navigator.pop(ctx);
                  final user = ref.read(currentUserProvider);
                  await ref
                      .read(communityRepositoryProvider)
                      .createPost(
                        selectedSpaceId,
                        title,
                        content,
                        authorId: user?.id,
                        authorName: user?.fullName,
                        authorImageUrl: user?.imageUrl,
                      );
                  ref.invalidate(communityPostsProvider);
                }
              },
              child: const Text('Publish Post'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      titleCtrl.dispose();
      contentCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
      floatingActionButton: isTeacher
          ? spacesAsync.maybeWhen(
              data: (spaces) => FloatingActionButton.extended(
                icon: const Icon(Icons.add_rounded),
                label: const Text('New Post'),
                onPressed: () => _showCreatePostModal(spaces),
              ),
              orElse: () => null,
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(communitySpacesProvider);
          ref.invalidate(communityPostsProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: spacesAsync.when(
                      loading: () => const SkeletonLoader(
                        width: double.infinity,
                        height: 44,
                        borderRadius: 24,
                      ),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (spaces) => SizedBox(
                        height: 46,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: spaces.length + 1,
                          itemBuilder: (context, index) {
                            final space = index == 0 ? null : spaces[index - 1];
                            final isSelected = space == null
                                ? selectedSpace == null
                                : selectedSpace == space.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 9),
                              child: FilterChip(
                                selected: isSelected,
                                avatar: Icon(
                                  space == null
                                      ? Icons.dynamic_feed_rounded
                                      : Icons.tag_rounded,
                                  size: 17,
                                  color: isSelected
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurfaceVariant,
                                ),
                                label: Text(space?.name ?? 'All spaces'),
                                showCheckmark: false,
                                shape: StadiumBorder(
                                  side: BorderSide(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : colorScheme.outline.withValues(alpha: .55),
                                  ),
                                ),
                                selectedColor: colorScheme.primary,
                                backgroundColor: colorScheme.surface,
                                labelStyle: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurface,
                                ),
                                onSelected: (_) => ref
                                    .read(selectedSpaceProvider.notifier)
                                    .state = space == null || isSelected
                                    ? null
                                    : space.id,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: postsAsync.when<Widget>(
                loading: () => SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, _) => Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: SkeletonLoader(
                            width: double.infinity,
                            height: 170,
                            borderRadius: 20,
                          ),
                        ),
                      ),
                    ),
                    childCount: 3,
                  ),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: ErrorStateWidget(
                        message: err.toString(),
                        onRetry: () => ref.invalidate(communityPostsProvider),
                      ),
                    ),
                  ),
                ),
                data: (posts) => posts.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 820),
                            child: const Padding(
                              padding: EdgeInsets.only(top: 36),
                              child: EmptyStateWidget(
                                icon: Icons.forum_outlined,
                                title: 'Your community starts here',
                                description: 'Share an update, start a discussion, or ask the group a question.',
                              ),
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 820),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _PostCard(post: posts[index]),
                              ),
                            ),
                          ),
                          childCount: posts.length,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends ConsumerStatefulWidget {
  final CommunityPostEntity post;
  final bool openCommentsOnStart;
  final bool expandImage;
  final bool openable;

  const _PostCard({
    required this.post,
    this.openCommentsOnStart = false,
    this.expandImage = false,
    this.openable = true,
  });

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> {
  bool _showComments = false;
  final _commentController = TextEditingController();
  List<CommunityCommentEntity> _comments = [];
  bool _loadingComments = false;
  int _likesCount = 0;
  bool _isLikedByMe = false;
  bool _liking = false;

  @override
  void initState() {
    super.initState();
    _comments = widget.post.comments;
    _likesCount = widget.post.likesCount;
    _isLikedByMe = widget.post.isLikedByMe;
    _showComments = widget.openCommentsOnStart;
    if (_showComments) _fetchComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    setState(() => _loadingComments = true);
    try {
      final res = await ref
          .read(communityRepositoryProvider)
          .getComments(widget.post.id);
      if (mounted) setState(() => _comments = res);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(currentUserProvider);
    _commentController.clear();
    try {
      final c = await ref
          .read(communityRepositoryProvider)
          .addComment(
            widget.post.id,
            text,
            authorId: user?.id,
            authorName: user?.fullName,
            authorImageUrl: user?.imageUrl,
          );
      if (mounted) setState(() => _comments = [..._comments, c]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to add comment: $e')));
      }
    }
  }

  Future<void> _toggleLike() async {
    final user = ref.read(currentUserProvider);
    if (user == null || _liking) return;

    setState(() => _liking = true);
    try {
      final response = await ref
          .read(communityRepositoryProvider)
          .toggleLike(widget.post.id, user.id);
      if (!mounted) return;
      setState(() {
        _likesCount = (response['likesCount'] as num?)?.toInt() ?? _likesCount;
        _isLikedByMe = response['isLikedByMe'] as bool? ?? _isLikedByMe;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not update like: $e')));
      }
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  void _showFullImage(String imageUrl) {
    final imageTag = 'community-post-image-${widget.post.id}';
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) {
        final screenSize = MediaQuery.sizeOf(dialogContext);
        final pixelRatio = MediaQuery.devicePixelRatioOf(dialogContext);
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Hero(
                  tag: imageTag,
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: screenSize.width,
                        height: screenSize.height,
                        fit: BoxFit.contain,
                        memCacheWidth: (screenSize.width * pixelRatio).round(),
                        memCacheHeight: (screenSize.height * pixelRatio)
                            .round(),
                        placeholder: (_, _) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        errorWidget: (_, _, _) => const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white70,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: IconButton.filledTonal(
                    tooltip: 'Close image',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _profileAvatar(String name, String? imageUrl, {double radius = 18}) {
    final image = imageUrl?.trim();
    if (image != null && image.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: image,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          memCacheWidth: (radius * 6).round(),
          memCacheHeight: (radius * 6).round(),
          placeholder: (_, _) => _avatarFallback(name, radius),
          errorWidget: (_, _, _) => _avatarFallback(name, radius),
        ),
      );
    }

    return _avatarFallback(name, radius);
  }

  Widget _avatarFallback(String name, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.brandSky.withValues(alpha: 0.15),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(
          color: AppColors.brandSky,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final post = widget.post;
    final currentUser = ref.watch(currentUserProvider);
    final isOwnPost = currentUser?.id == post.authorId;
    final postAuthorName = isOwnPost
        ? currentUser!.fullName
        : (post.authorName?.trim().isNotEmpty == true
              ? post.authorName!.trim()
              : 'Community member');
    final postAuthorImage = isOwnPost
        ? currentUser!.imageUrl
        : post.authorImageUrl;

    final radius = BorderRadius.circular(20);
    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: colorScheme.outline.withValues(alpha: .7)),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: widget.openable
            ? () => context.push(
                '/community/post/${post.id}',
                extra: post,
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author header
            Row(
              children: [
                _profileAvatar(postAuthorName, postAuthorImage),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              postAuthorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (post.isPinned) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brandAmber.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Pinned',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.amber[900],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            DateFormat.yMMMd().format(post.createdAt),
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                          if (post.isAnnouncement) ...[
                            const SizedBox(width: 7),
                            Icon(
                              Icons.campaign_rounded,
                              size: 13,
                              color: AppColors.brandAmber,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Announcement',
                              style: TextStyle(
                                color: AppColors.brandAmber,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title & Content
            Text(
              post.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              post.content,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (post.mediaUrl?.trim().isNotEmpty == true &&
                (post.mediaType == null ||
                    post.mediaType!.toLowerCase() == 'image')) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _CommunityPostImage(
                  imageUrl: post.mediaUrl!,
                  imageTag: 'community-post-image-${post.id}',
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  maxHeight: widget.expandImage ? null : 520,
                  onTap: () => _showFullImage(post.mediaUrl!),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Divider(height: 1, color: colorScheme.outline.withValues(alpha: .45)),
            const SizedBox(height: 5),

            Row(
              children: [
                TextButton.icon(
                  onPressed: _liking ? null : _toggleLike,
                  icon: Icon(
                    _isLikedByMe
                        ? Icons.thumb_up_alt
                        : Icons.thumb_up_alt_outlined,
                    size: 17,
                    color: _isLikedByMe
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  label: Text('$_likesCount'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    final next = !_showComments;
                    setState(() => _showComments = next);
                    if (next) _fetchComments();
                  },
                  icon: Icon(
                    _showComments
                        ? Icons.mode_comment_rounded
                        : Icons.mode_comment_outlined,
                    size: 17,
                  ),
                  label: Text(
                    _showComments
                        ? 'Hide comments'
                        : 'Comments (${_comments.isEmpty ? post.commentsCount : _comments.length})',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(44, 40),
                    shape: const StadiumBorder(),
                  ),
                ),
              ],
            ),

            // Comments list & form
            if (_showComments) ...[
              const SizedBox(height: 12),
              if (_loadingComments)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else ...[
                ..._comments.map((c) {
                  final isOwnComment = currentUser?.id == c.authorId;
                  final commentName = isOwnComment
                      ? currentUser!.fullName
                      : (c.authorName?.trim().isNotEmpty == true
                            ? c.authorName!.trim()
                            : 'Community member');
                  final commentImage = isOwnComment
                      ? currentUser!.imageUrl
                      : c.authorImageUrl;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _profileAvatar(commentName, commentImage, radius: 15),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  commentName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  c.content,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
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
                      icon: const Icon(
                        Icons.send_rounded,
                        color: AppColors.brandSky,
                        size: 20,
                      ),
                      onPressed: _addComment,
                    ),
                  ],
                ),
              ],
            ],
          ],
          ),
        ),
      ),
    );
  }
}

class CommunityPostDetailScreen extends StatelessWidget {
  final CommunityPostEntity post;

  const CommunityPostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        leading: IconButton(
          tooltip: 'Back to community',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: _PostCard(
                    post: post,
                    openable: false,
                    openCommentsOnStart: true,
                    expandImage: true,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityPostImage extends StatefulWidget {
  final String imageUrl;
  final String imageTag;
  final Color backgroundColor;
  final VoidCallback onTap;
  final double? maxHeight;

  const _CommunityPostImage({
    required this.imageUrl,
    required this.imageTag,
    required this.backgroundColor,
    required this.onTap,
    this.maxHeight = 520,
  });

  @override
  State<_CommunityPostImage> createState() => _CommunityPostImageState();
}

class _CommunityPostImageState extends State<_CommunityPostImage> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  double? _aspectRatio;
  bool _didResolveInitialImage = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didResolveInitialImage) {
      _didResolveInitialImage = true;
      _readImageSize();
    }
  }

  @override
  void didUpdateWidget(covariant _CommunityPostImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _removeImageListener();
      _aspectRatio = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _readImageSize();
      });
    }
  }

  void _readImageSize() {
    final provider = ResizeImage(
      CachedNetworkImageProvider(widget.imageUrl),
      width: 1200,
    );
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((imageInfo, _) {
      final image = imageInfo.image;
      if (image.width == 0 || image.height == 0) return;
      final ratio = image.width / image.height;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _aspectRatio == ratio) return;
        setState(() => _aspectRatio = ratio);
      });
    }, onError: (_, _) {});
    _imageStream = stream;
    _imageListener = listener;
    stream.addListener(listener);
  }

  void _removeImageListener() {
    final stream = _imageStream;
    final listener = _imageListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageListener = null;
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final ratio = _aspectRatio;
        final height = ratio == null
            ? (width * 9 / 16).clamp(120.0, widget.maxHeight ?? 520).toDouble()
            : widget.maxHeight == null
            ? width / ratio
            : (width / ratio).clamp(120.0, widget.maxHeight!).toDouble();

        return Material(
          color: widget.backgroundColor,
          child: InkWell(
            onTap: widget.onTap,
            child: Hero(
              tag: widget.imageTag,
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: widget.imageUrl,
                      fit: BoxFit.contain,
                      memCacheWidth: 1200,
                      placeholder: (_, _) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (_, _, _) => const Center(
                        child: Icon(Icons.broken_image_outlined, size: 36),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.open_in_full_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
