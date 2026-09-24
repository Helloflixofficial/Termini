import '../../courses/domain/course_entity.dart';

class DashboardEntity {
  final List<CourseEntity> completedCourses;
  final List<CourseEntity> coursesInProgress;

  const DashboardEntity({
    this.completedCourses = const [],
    this.coursesInProgress = const [],
  });

  factory DashboardEntity.fromJson(Map<String, dynamic> json) {
    List<CourseEntity> completed = [];
    if (json['completedCourses'] != null && json['completedCourses'] is List) {
      completed = (json['completedCourses'] as List)
          .map((c) => CourseEntity.fromJson(c as Map<String, dynamic>))
          .toList();
    }

    List<CourseEntity> inProgress = [];
    if (json['coursesInProgress'] != null && json['coursesInProgress'] is List) {
      inProgress = (json['coursesInProgress'] as List)
          .map((c) => CourseEntity.fromJson(c as Map<String, dynamic>))
          .toList();
    }

    return DashboardEntity(
      completedCourses: completed,
      coursesInProgress: inProgress,
    );
  }
}
