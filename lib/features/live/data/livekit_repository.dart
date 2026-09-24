import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../domain/meeting_entity.dart';

abstract class LiveKitRepository {
  Future<List<MeetingSessionEntity>> getSessions();
  Future<MeetingSessionEntity> createSession(String title, {String? description});
  Future<void> endSession(String id);
  Future<({String token, String participantName, bool isHost})> getToken(String roomName);
}

class LiveKitRepositoryImpl implements LiveKitRepository {
  final Dio _dio;

  LiveKitRepositoryImpl(this._dio);

  @override
  Future<List<MeetingSessionEntity>> getSessions() async {
    try {
      final res = await _dio.get(ApiConstants.liveKitSessions);
      final list = res.data as List;
      return list.map((json) => MeetingSessionEntity.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<MeetingSessionEntity> createSession(String title, {String? description}) async {
    try {
      final res = await _dio.post(
        ApiConstants.liveKitSessions,
        data: {'title': title, 'description': ?description},
      );
      return MeetingSessionEntity.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<void> endSession(String id) async {
    try {
      await _dio.delete(ApiConstants.liveKitSession(id));
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<({String token, String participantName, bool isHost})> getToken(String roomName) async {
    try {
      final res = await _dio.get(
        ApiConstants.liveKitToken,
        queryParameters: {'room': roomName},
      );
      final data = res.data as Map<String, dynamic>;
      return (
        token: data['token'] as String,
        participantName: data['participantName'] as String? ?? 'Participant',
        isHost: data['isHost'] as bool? ?? false,
      );
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }
}

final liveKitRepositoryProvider = Provider<LiveKitRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return LiveKitRepositoryImpl(dio);
});
