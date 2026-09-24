import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../domain/dashboard_entity.dart';

abstract class DashboardRepository {
  Future<DashboardEntity> getDashboardData();
}

class DashboardRepositoryImpl implements DashboardRepository {
  final Dio _dio;

  DashboardRepositoryImpl(this._dio);

  @override
  Future<DashboardEntity> getDashboardData() async {
    try {
      final res = await _dio.get(ApiConstants.dashboard);
      return DashboardEntity.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      // Graceful fallback: return empty dashboard state so the UI renders smoothly
      return const DashboardEntity(
        completedCourses: [],
        coursesInProgress: [],
      );
    }
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return DashboardRepositoryImpl(dio);
});

final dashboardControllerProvider =
    FutureProvider.autoDispose<DashboardEntity>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.getDashboardData();
});
