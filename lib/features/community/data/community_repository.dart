import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../domain/community_entity.dart';

abstract class CommunityRepository {
  Future<List<CommunitySpaceEntity>> getSpaces();
  Future<CommunitySpaceEntity> createSpace(String name, String slug, {String? description, String? color});
  Future<List<CommunityPostEntity>> getPosts({String? spaceId, String? userId});
  Future<List<CommunityPostEntity>> getNotifications({required String userId});
  Future<CommunityPostEntity> createPost(
    String spaceId,
    String title,
    String content, {
    String? authorId,
    String? authorName,
    String? authorImageUrl,
  });
  Future<List<CommunityCommentEntity>> getComments(String postId);
  Future<CommunityCommentEntity> addComment(
    String postId,
    String content, {
    String? authorId,
    String? authorName,
    String? authorImageUrl,
  });
  Future<Map<String, dynamic>> toggleLike(String postId, String userId);
  Future<Map<String, dynamic>> getSettings();
  Future<void> updateSettings(Map<String, dynamic> data);
}

class CommunityRepositoryImpl implements CommunityRepository {
  final Dio _dio;

  CommunityRepositoryImpl(this._dio);

  @override
  Future<List<CommunitySpaceEntity>> getSpaces() async {
    try {
      final res = await _dio.get(ApiConstants.communitySpaces);
      final list = res.data as List;
      return list.map((json) => CommunitySpaceEntity.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<CommunitySpaceEntity> createSpace(String name, String slug, {String? description, String? color}) async {
    try {
      final res = await _dio.post(
        ApiConstants.communitySpaces,
        data: {
          'name': name,
          'slug': slug,
          'description': ?description,
          'color': ?color,
        },
      );
      return CommunitySpaceEntity.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<List<CommunityPostEntity>> getPosts({String? spaceId, String? userId}) async {
    try {
      final res = await _dio.get(
        ApiConstants.communityPosts,
        queryParameters: {
          if (spaceId != null && spaceId.isNotEmpty) 'spaceId': spaceId,
          if (userId != null && userId.isNotEmpty) 'userId': userId,
        },
      );
      final list = res.data as List;
      return list.map((json) => CommunityPostEntity.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<List<CommunityPostEntity>> getNotifications({required String userId}) async {
    try {
      final res = await _dio.get(
        ApiConstants.communityNotifications,
        queryParameters: {'userId': userId},
      );
      final list = res.data as List;
      return list
          .map((json) => CommunityPostEntity.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<CommunityPostEntity> createPost(
    String spaceId,
    String title,
    String content, {
    String? authorId,
    String? authorName,
    String? authorImageUrl,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.communityPosts,
        data: {
          'spaceId': spaceId,
          'title': title,
          'content': content,
          if (authorId != null) 'authorId': authorId,
          if (authorName != null) 'authorName': authorName,
          if (authorImageUrl != null) 'authorImageUrl': authorImageUrl,
        },
      );
      return CommunityPostEntity.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<List<CommunityCommentEntity>> getComments(String postId) async {
    try {
      final res = await _dio.get(ApiConstants.communityComments(postId));
      final list = res.data as List;
      return list.map((json) => CommunityCommentEntity.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<CommunityCommentEntity> addComment(
    String postId,
    String content, {
    String? authorId,
    String? authorName,
    String? authorImageUrl,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.communityComments(postId),
        data: {
          'content': content,
          if (authorId != null) 'authorId': authorId,
          if (authorName != null) 'authorName': authorName,
          if (authorImageUrl != null) 'authorImageUrl': authorImageUrl,
        },
      );
      return CommunityCommentEntity.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> toggleLike(String postId, String userId) async {
    try {
      final res = await _dio.post(
        ApiConstants.communityLikes(postId),
        data: {'userId': userId},
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final res = await _dio.get(ApiConstants.communitySettings);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<void> updateSettings(Map<String, dynamic> data) async {
    try {
      await _dio.patch(ApiConstants.communitySettings, data: data);
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }
}

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return CommunityRepositoryImpl(dio);
});
