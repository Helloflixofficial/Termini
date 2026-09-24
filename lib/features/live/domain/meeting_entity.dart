class MeetingSessionEntity {
  final String id;
  final String title;
  final String? description;
  final String roomName;
  final String hostId;
  final bool isActive;
  final DateTime createdAt;

  const MeetingSessionEntity({
    required this.id,
    required this.title,
    this.description,
    required this.roomName,
    required this.hostId,
    required this.isActive,
    required this.createdAt,
  });

  factory MeetingSessionEntity.fromJson(Map<String, dynamic> json) {
    return MeetingSessionEntity(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      roomName: json['roomName'] as String? ?? '',
      hostId: json['hostId'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'roomName': roomName,
        'hostId': hostId,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };
}
