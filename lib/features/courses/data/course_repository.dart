import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../domain/course_entity.dart';

abstract class CourseRepository {
  Future<List<CourseEntity>> getCourses({String? title, String? categoryId});
  Future<List<CategoryEntity>> getCategories();
  Future<CourseEntity> getCourseDetails(String courseId);
  Future<Map<String, dynamic>> getChapterDetails(String courseId, String chapterId);
  Future<void> updateChapterProgress(String courseId, String chapterId, bool isCompleted);
  Future<String> createCheckoutSession(String courseId, {String? returnUrl});

  // Teacher actions
  Future<List<CourseEntity>> getTeacherCourses();
  Future<CourseEntity> createCourse(String title);
  Future<CourseEntity> updateCourse(String courseId, Map<String, dynamic> data);
  Future<void> deleteCourse(String courseId);
  Future<void> publishCourse(String courseId);
  Future<void> unpublishCourse(String courseId);

  // Chapter management
  Future<ChapterEntity> createChapter(String courseId, String title);
  Future<void> reorderChapters(String courseId, List<Map<String, dynamic>> list);
  Future<ChapterEntity> updateChapter(String courseId, String chapterId, Map<String, dynamic> data);
  Future<void> deleteChapter(String courseId, String chapterId);
  Future<void> publishChapter(String courseId, String chapterId);
  Future<void> unpublishChapter(String courseId, String chapterId);

  // Attachments
  Future<AttachmentEntity> addAttachment(String courseId, String name, String url);
  Future<void> deleteAttachment(String courseId, String attachmentId);
}

class CourseRepositoryImpl implements CourseRepository {
  final Dio _dio;

  CourseRepositoryImpl(this._dio);

  @override
  Future<List<CourseEntity>> getCourses({String? title, String? categoryId}) async {
    try {
      final res = await _dio.get(
        ApiConstants.courses,
        queryParameters: {
          if (title != null && title.isNotEmpty) 'title': title,
          if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
        },
      );
      final list = res.data as List;
      return list.map((json) => CourseEntity.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<List<CategoryEntity>> getCategories() async {
    try {
      final res = await _dio.get(ApiConstants.categories);
      final list = res.data as List;
      return list.map((json) => CategoryEntity.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<CourseEntity> getCourseDetails(String courseId) async {
    try {
      final res = await _dio.get(ApiConstants.course(courseId));
      return CourseEntity.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> getChapterDetails(String courseId, String chapterId) async {
    try {
      final res = await _dio.get(ApiConstants.chapter(courseId, chapterId));
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<void> updateChapterProgress(String courseId, String chapterId, bool isCompleted) async {
    try {
      await _dio.put(
        ApiConstants.chapterProgress(courseId, chapterId),
        data: {'isCompleted': isCompleted},
      );
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<String> createCheckoutSession(String courseId, {String? returnUrl}) async {
    try {
      final res = await _dio.post(
        ApiConstants.checkout(courseId),
        data: {
          'returnUrl': ?returnUrl,
        },
      );
      final url = res.data['url'] as String;
      return url;
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<List<CourseEntity>> getTeacherCourses() async {
    try {
      final res = await _dio.get(ApiConstants.teacherCourses);
      final list = res.data as List;
      return list.map((json) => CourseEntity.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<CourseEntity> createCourse(String title) async {
    try {
      final res = await _dio.post(
        ApiConstants.courses,
        data: {'title': title},
      );
      return CourseEntity.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<CourseEntity> updateCourse(String courseId, Map<String, dynamic> data) async {
    try {
      final res = await _dio.patch(
        ApiConstants.course(courseId),
        data: data,
      );
      return CourseEntity.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<void> deleteCourse(String courseId) async {
    try {
      await _dio.delete(ApiConstants.course(courseId));
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<void> publishCourse(String courseId) async {
    try {
      await _dio.patch(ApiConstants.coursePublish(courseId));
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<void> unpublishCourse(String courseId) async {
    try {
      await _dio.patch(ApiConstants.courseUnpublish(courseId));
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<ChapterEntity> createChapter(String courseId, String title) async {
    try {
      final res = await _dio.post(
        ApiConstants.courseChapters(courseId),
        data: {'title': title},
      );
      return ChapterEntity.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<void> reorderChapters(String courseId, List<Map<String, dynamic>> list) async {
    try {
      await _dio.put(
        ApiConstants.chaptersReorder(courseId),
        data: {'list': list},
      );
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<ChapterEntity> updateChapter(String courseId, String chapterId, Map<String, dynamic> data) async {
    try {
      final res = await _dio.patch(
        ApiConstants.chapter(courseId, chapterId),
        data: data,
      );
      return ChapterEntity.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<void> deleteChapter(String courseId, String chapterId) async {
    try {
      await _dio.delete(ApiConstants.chapter(courseId, chapterId));
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<void> publishChapter(String courseId, String chapterId) async {
    try {
      await _dio.patch(ApiConstants.chapterPublish(courseId, chapterId));
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<void> unpublishChapter(String courseId, String chapterId) async {
    try {
      await _dio.patch(ApiConstants.chapterUnpublish(courseId, chapterId));
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<AttachmentEntity> addAttachment(String courseId, String name, String url) async {
    try {
      final res = await _dio.post(
        ApiConstants.courseAttachments(courseId),
        data: {'name': name, 'url': url},
      );
      return AttachmentEntity.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<void> deleteAttachment(String courseId, String attachmentId) async {
    try {
      await _dio.delete(ApiConstants.courseAttachment(courseId, attachmentId));
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }
}

final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return CourseRepositoryImpl(dio);
});
