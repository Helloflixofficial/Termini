class UserStats {
  final int enrolledCoursesCount;
  final int completedChaptersCount;
  final int certificatesCount;
  final double hoursLearned;

  const UserStats({
    this.enrolledCoursesCount = 0,
    this.completedChaptersCount = 0,
    this.certificatesCount = 0,
    this.hoursLearned = 0.0,
  });

  factory UserStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserStats();
    return UserStats(
      enrolledCoursesCount: (json['enrolledCoursesCount'] as num?)?.toInt() ?? 0,
      completedChaptersCount: (json['completedChaptersCount'] as num?)?.toInt() ?? 0,
      certificatesCount: (json['certificatesCount'] as num?)?.toInt() ?? 0,
      hoursLearned: (json['hoursLearned'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'enrolledCoursesCount': enrolledCoursesCount,
        'completedChaptersCount': completedChaptersCount,
        'certificatesCount': certificatesCount,
        'hoursLearned': hoursLearned,
      };
}

class UserEntity {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? imageUrl;
  final bool isTeacher;
  final String? bio;
  final String? joinedDate;
  final UserStats stats;

  const UserEntity({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.imageUrl,
    this.isTeacher = false,
    this.bio,
    this.joinedDate,
    this.stats = const UserStats(),
  });

  String get fullName {
    if (firstName != null && firstName!.isNotEmpty) {
      if (lastName != null && lastName!.isNotEmpty) {
        return '$firstName $lastName';
      }
      return firstName!;
    }
    return email.split('@').first;
  }

  UserEntity copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? imageUrl,
    bool? isTeacher,
    String? bio,
    String? joinedDate,
    UserStats? stats,
  }) {
    return UserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      imageUrl: imageUrl ?? this.imageUrl,
      isTeacher: isTeacher ?? this.isTeacher,
      bio: bio ?? this.bio,
      joinedDate: joinedDate ?? this.joinedDate,
      stats: stats ?? this.stats,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'imageUrl': imageUrl,
        'isTeacher': isTeacher,
        'bio': bio,
        'joinedDate': joinedDate,
        'stats': stats.toJson(),
      };

  factory UserEntity.fromJson(Map<String, dynamic> json) {
    return UserEntity(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isTeacher: json['isTeacher'] as bool? ?? false,
      bio: json['bio'] as String?,
      joinedDate: json['joinedDate'] as String?,
      stats: json['stats'] != null
          ? UserStats.fromJson(json['stats'] as Map<String, dynamic>)
          : const UserStats(),
    );
  }
}

