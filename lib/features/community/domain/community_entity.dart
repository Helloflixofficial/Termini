class CommunitySpaceEntity {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String color;

  const CommunitySpaceEntity({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.color = '#bd8956',
  });

  factory CommunitySpaceEntity.fromJson(Map<String, dynamic> json) {
    return CommunitySpaceEntity(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      color: json['color'] as String? ?? '#bd8956',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'description': description,
        'color': color,
      };
}

class CommunityPostEntity {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String spaceId;
  final bool isPinned;
  final bool isAnnouncement;
  final bool isApproved;
  final DateTime createdAt;
  final String? authorName;
  final String? authorImageUrl;
  final String? mediaUrl;
  final String? mediaType;
  final String? linkUrl;
  final String? linkTitle;
  final int likesCount;
  final bool isLikedByMe;
  final List<CommunityCommentEntity> comments;
  final int commentsCount;

  const CommunityPostEntity({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.spaceId,
    this.isPinned = false,
    this.isAnnouncement = false,
    this.isApproved = true,
    required this.createdAt,
    this.authorName,
    this.authorImageUrl,
    this.mediaUrl,
    this.mediaType,
    this.linkUrl,
    this.linkTitle,
    this.likesCount = 0,
    this.isLikedByMe = false,
    this.comments = const [],
    this.commentsCount = 0,
  });

  factory CommunityPostEntity.fromJson(Map<String, dynamic> json) {
    final comments = (json['comments'] as List? ?? const [])
        .whereType<Map>()
        .map((comment) => CommunityCommentEntity.fromJson(
              Map<String, dynamic>.from(comment),
            ))
        .toList();
    return CommunityPostEntity(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      spaceId: json['spaceId'] as String? ?? '',
      isPinned: json['isPinned'] as bool? ?? false,
      isAnnouncement: json['isAnnouncement'] as bool? ?? false,
      isApproved: json['isApproved'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      authorName: json['authorName'] as String?,
      authorImageUrl: json['authorImageUrl'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      mediaType: json['mediaType'] as String?,
      linkUrl: json['linkUrl'] as String?,
      linkTitle: json['linkTitle'] as String?,
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      isLikedByMe: json['isLikedByMe'] as bool? ?? false,
      comments: comments,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? comments.length,
    );
  }

  CommunityPostEntity copyWith({int? likesCount, bool? isLikedByMe}) =>
      CommunityPostEntity(
        id: id,
        title: title,
        content: content,
        authorId: authorId,
        spaceId: spaceId,
        isPinned: isPinned,
        isAnnouncement: isAnnouncement,
        isApproved: isApproved,
        createdAt: createdAt,
        authorName: authorName,
        authorImageUrl: authorImageUrl,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        linkUrl: linkUrl,
        linkTitle: linkTitle,
        likesCount: likesCount ?? this.likesCount,
        isLikedByMe: isLikedByMe ?? this.isLikedByMe,
        comments: comments,
        commentsCount: commentsCount,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'authorId': authorId,
        'spaceId': spaceId,
        'isPinned': isPinned,
        'isAnnouncement': isAnnouncement,
        'isApproved': isApproved,
        'createdAt': createdAt.toIso8601String(),
        'authorName': authorName,
        'authorImageUrl': authorImageUrl,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'linkUrl': linkUrl,
        'linkTitle': linkTitle,
        'likesCount': likesCount,
        'isLikedByMe': isLikedByMe,
        'comments': comments.map((comment) => comment.toJson()).toList(),
      };
}

class CommunityCommentEntity {
  final String id;
  final String content;
  final String authorId;
  final String? authorName;
  final String? authorImageUrl;
  final String postId;
  final DateTime createdAt;

  const CommunityCommentEntity({
    required this.id,
    required this.content,
    required this.authorId,
    required this.postId,
    this.authorName,
    this.authorImageUrl,
    required this.createdAt,
  });

  factory CommunityCommentEntity.fromJson(Map<String, dynamic> json) {
    return CommunityCommentEntity(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String?,
      authorImageUrl: json['authorImageUrl'] as String?,
      postId: json['postId'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'authorId': authorId,
        'authorName': authorName,
        'authorImageUrl': authorImageUrl,
        'postId': postId,
        'createdAt': createdAt.toIso8601String(),
      };
}
