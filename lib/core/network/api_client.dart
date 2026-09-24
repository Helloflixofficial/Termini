import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env.dart';
import '../error/failures.dart';

const String _authTokenKey = 'auth_session_token';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;

  AuthInterceptor(this._storage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: _authTokenKey);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['Accept'] = 'application/json';
    options.headers['Content-Type'] = 'application/json';
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[API Error] ${err.requestOptions.method} ${err.requestOptions.uri}');
      debugPrint('[Status] ${err.response?.statusCode}: ${err.response?.data}');
    }
    return handler.next(err);
  }
}

class NetworkFallbackInterceptor extends Interceptor {
  final Dio _dio;
  static const String _primaryUrl = 'http://127.0.0.1:3000';
  static const String _fallbackUrl = 'http://192.168.1.12:3000';

  NetworkFallbackInterceptor(this._dio);

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout) {
      final isPrimary = _dio.options.baseUrl.contains('127.0.0.1');
      final alternateHost = isPrimary ? _fallbackUrl : _primaryUrl;

      final alreadyRetried = err.requestOptions.extra['retried_fallback'] == true;
      if (!alreadyRetried) {
        try {
          err.requestOptions.extra['retried_fallback'] = true;
          final altDio = Dio(
            BaseOptions(
              baseUrl: alternateHost,
              connectTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 5),
            ),
          );

          final res = await altDio.request(
            err.requestOptions.path,
            data: err.requestOptions.data,
            queryParameters: err.requestOptions.queryParameters,
            options: Options(
              method: err.requestOptions.method,
              headers: err.requestOptions.headers,
              responseType: err.requestOptions.responseType,
            ),
          );

          // Update baseUrl so future requests hit the working endpoint directly
          _dio.options.baseUrl = alternateHost;
          return handler.resolve(res);
        } catch (_) {}
      }
    }
    return handler.next(err);
  }
}

final apiClientProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppEnv.apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  dio.interceptors.add(AuthInterceptor(storage));
  dio.interceptors.add(NetworkFallbackInterceptor(dio));

  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestHeader: false,
        requestBody: true,
        responseHeader: false,
        responseBody: false,
      ),
    );
  }

  return dio;
});

Failure handleDioError(DioException error) {
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.connectionError) {
    return const NetworkFailure();
  }

  final statusCode = error.response?.statusCode;
  if (statusCode == 401) {
    return const AuthFailure();
  } else if (statusCode == 404) {
    return const NotFoundFailure();
  } else if (statusCode != null && statusCode >= 400 && statusCode < 500) {
    final msg = error.response?.data?.toString() ?? 'Client error';
    return ServerFailure(msg, statusCode: statusCode);
  } else if (statusCode != null && statusCode >= 500) {
    return ServerFailure('Server error. Please try again.', statusCode: statusCode);
  }

  return UnexpectedFailure(error.message ?? 'Unknown error');
}
