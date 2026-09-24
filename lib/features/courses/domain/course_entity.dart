class CategoryEntity {
  final String id;
  final String name;

  const CategoryEntity({
    required this.id,
    required this.name,
  });

  factory CategoryEntity.fromJson(Map<String, dynamic> json) {
    return CategoryEntity(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class AttachmentEntity {
  final String id;
  final String name;
  final String url;
  final String courseId;

  const AttachmentEntity({
    required this.id,
    required this.name,
    required this.url,
    required this.courseId,
  });

  factory AttachmentEntity.fromJson(Map<String, dynamic> json) {
    return AttachmentEntity(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      courseId: json['courseId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'courseId': courseId,
      };
}

class ChapterEntity {
  final String id;
  final String title;
  final String? description;
  final String? videoUrl;
  final int position;
  final bool isPublished;
  final bool isFree;
  final String courseId;
  final String? muxPlaybackId;
  final bool isCompleted;

  const ChapterEntity({
    required this.id,
    required this.title,
    this.description,
    this.videoUrl,
    required this.position,
    this.isPublished = false,
    this.isFree = false,
    required this.courseId,
    this.muxPlaybackId,
    this.isCompleted = false,
  });

  factory ChapterEntity.fromJson(Map<String, dynamic> json) {
    String? playbackId;
    if (json['muxData'] != null && json['muxData'] is Map) {
      playbackId = json['muxData']['playbackId'] as String?;
    }

    bool completed = false;
    if (json['userProgress'] != null) {
      if (json['userProgress'] is List && (json['userProgress'] as List).isNotEmpty) {
        completed = json['userProgress'][0]['isCompleted'] == true;
      } else if (json['userProgress'] is Map) {
        completed = json['userProgress']['isCompleted'] == true;
      }
    }

    return ChapterEntity(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      videoUrl: json['videoUrl'] as String?,
      position: json['position'] as int? ?? 0,
      isPublished: json['isPublished'] as bool? ?? false,
      isFree: json['isFree'] as bool? ?? false,
      courseId: json['courseId'] as String? ?? '',
      muxPlaybackId: playbackId,
      isCompleted: completed,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'videoUrl': videoUrl,
        'position': position,
        'isPublished': isPublished,
        'isFree': isFree,
        'courseId': courseId,
        'muxPlaybackId': muxPlaybackId,
        'isCompleted': isCompleted,
      };

  ChapterEntity copyWith({
    String? id,
    String? title,
    String? description,
    String? videoUrl,
    int? position,
    bool? isPublished,
    bool? isFree,
    String? courseId,
    String? muxPlaybackId,
    bool? isCompleted,
  }) {
    return ChapterEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      position: position ?? this.position,
      isPublished: isPublished ?? this.isPublished,
      isFree: isFree ?? this.isFree,
      courseId: courseId ?? this.courseId,
      muxPlaybackId: muxPlaybackId ?? this.muxPlaybackId,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class CourseEntity {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? imageUrl;
  final double? price;
  final bool isPublished;
  final String? categoryId;
  final CategoryEntity? category;
  final int chaptersCount;
  final double? progress;
  final List<ChapterEntity> chapters;
  final List<AttachmentEntity> attachments;
  final bool isPurchased;

  const CourseEntity({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.imageUrl,
    this.price,
    this.isPublished = false,
    this.categoryId,
    this.category,
    this.chaptersCount = 0,
    this.progress,
    this.chapters = const [],
    this.attachments = const [],
    this.isPurchased = false,
  });

  factory CourseEntity.fromJson(Map<String, dynamic> json) {
    CategoryEntity? cat;
    if (json['category'] != null && json['category'] is Map) {
      cat = CategoryEntity.fromJson(json['category'] as Map<String, dynamic>);
    }

    List<ChapterEntity> chapList = [];
    int chCount = 0;
    if (json['chapters'] != null && json['chapters'] is List) {
      chapList = (json['chapters'] as List)
          .map((c) => ChapterEntity.fromJson(c as Map<String, dynamic>))
          .toList();
      chCount = chapList.length;
    }

    List<AttachmentEntity> attList = [];
    if (json['attachments'] != null && json['attachments'] is List) {
      attList = (json['attachments'] as List)
          .map((a) => AttachmentEntity.fromJson(a as Map<String, dynamic>))
          .toList();
    }

    bool purchased = false;
    if (json['purchases'] != null && json['purchases'] is List) {
      purchased = (json['purchases'] as List).isNotEmpty;
    }

    double? prog;
    if (json['progress'] != null) {
      prog = (json['progress'] as num).toDouble();
    }

    return CourseEntity(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      isPublished: json['isPublished'] as bool? ?? false,
      categoryId: json['categoryId'] as String?,
      category: cat,
      chaptersCount: chCount,
      progress: prog,
      chapters: chapList,
      attachments: attList,
      isPurchased: purchased,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'description': description,
        'imageUrl': imageUrl,
        'price': price,
        'isPublished': isPublished,
        'categoryId': categoryId,
        'category': category?.toJson(),
        'chaptersCount': chaptersCount,
        'progress': progress,
        'chapters': chapters.map((c) => c.toJson()).toList(),
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'isPurchased': isPurchased,
      };
}
