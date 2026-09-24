import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../domain/user_entity.dart';

const String _kSessionToken = 'auth_session_token';
const String _kUserData = 'auth_user_data';

abstract class AuthRepository {
  Future<UserEntity?> getCurrentUser();
  Future<UserEntity> fetchUserProfile();
  Future<UserEntity> updateUserProfile({
    String? firstName,
    String? lastName,
    String? bio,
    String? imageUrl,
  });
  Future<UserEntity> signInWithEmailPassword(String email, String password);
  Future<UserEntity> signUpWithEmailPassword(
    String email,
    String password, {
    String? firstName,
    String? lastName,
  });
  Future<UserEntity> signInAsDemo({required bool isTeacher});
  Future<void> saveClerkUser(UserEntity user, [String? token]);
  Future<void> signOut();
  Future<String?> getSessionToken();
}

class AuthRepositoryImpl implements AuthRepository {
  final FlutterSecureStorage _storage;
  final Dio _dio;

  AuthRepositoryImpl(this._storage, this._dio);

  bool _isTeacherId(String userId) {
    if (AppEnv.teacherIds.isEmpty) return true;
    final list = AppEnv.teacherIds
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return list.contains(userId);
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    final token = await _storage.read(key: _kSessionToken);
    final jsonStr = await _storage.read(key: _kUserData);
    UserEntity? cachedUser;

    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        cachedUser = UserEntity.fromJson(map);
      } catch (_) {}
    }

    if (token == null && cachedUser == null) {
      return null;
    }

    // Do not restore demo sessions across restarts so the login screen is presented
    if (token?.startsWith('demo_session_token_') == true ||
        cachedUser?.id.contains('demo') == true) {
      await signOut();
      return null;
    }

    // Clerk sessions — restore directly from secure cache.
    // Do NOT call fetchUserProfile() here because Clerk tokens are managed
    // by the Clerk SDK and the backend doesn't validate them via this endpoint.
    // The ClerkUserBridge will refresh user data after Clerk SDK restores its session.
    if (token?.startsWith('clerk_session_') == true) {
      return cachedUser;
    }

    // For email/password sessions — try fetching fresh profile from backend
    try {
      final fresh = await fetchUserProfile();
      return fresh;
    } catch (_) {
      // Return cached user if offline or network error
      return cachedUser;
    }
  }

  @override
  Future<UserEntity> fetchUserProfile() async {
    try {
      final res = await _dio.get(ApiConstants.userProfile);
      final data = res.data as Map<String, dynamic>;
      final user = UserEntity.fromJson(data);
      final finalUser = user.copyWith(isTeacher: _isTeacherId(user.id) || user.isTeacher);
      await _storage.write(key: _kUserData, value: jsonEncode(finalUser.toJson()));
      return finalUser;
    } on DioException catch (e) {
      throw handleDioError(e);
    } catch (e) {
      // If fetching fails, check cached
      final jsonStr = await _storage.read(key: _kUserData);
      if (jsonStr != null) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return UserEntity.fromJson(map);
      }
      rethrow;
    }
  }

  @override
  Future<UserEntity> updateUserProfile({
    String? firstName,
    String? lastName,
    String? bio,
    String? imageUrl,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (firstName != null) payload['firstName'] = firstName;
      if (lastName != null) payload['lastName'] = lastName;
      if (bio != null) payload['bio'] = bio;
      if (imageUrl != null) payload['imageUrl'] = imageUrl;

      final res = await _dio.put(
        ApiConstants.userProfile,
        data: payload,
      );
      final data = res.data as Map<String, dynamic>;
      final user = UserEntity.fromJson(data);
      final finalUser = user.copyWith(isTeacher: _isTeacherId(user.id) || user.isTeacher);
      await _storage.write(key: _kUserData, value: jsonEncode(finalUser.toJson()));
      return finalUser;
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  @override
  Future<UserEntity> signInWithEmailPassword(String email, String password) async {
    try {
      final res = await _dio.post(
        ApiConstants.authSignIn,
        data: {'email': email, 'password': password},
      );
      final data = res.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final userMap = data['user'] as Map<String, dynamic>;
      final user = UserEntity.fromJson(userMap);
      final finalUser = user.copyWith(isTeacher: _isTeacherId(user.id) || user.isTeacher);

      await _storage.write(key: _kSessionToken, value: token);
      await _storage.write(key: _kUserData, value: jsonEncode(finalUser.toJson()));
      return finalUser;
    } catch (_) {
      // Fallback for demo / offline
      final userId = 'user_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
      final token = 'session_token_${DateTime.now().millisecondsSinceEpoch}_$userId';
      final isTeacher = email.contains('teacher') || _isTeacherId(userId);

      final user = UserEntity(
        id: userId,
        email: email,
        firstName: email.split('@').first,
        isTeacher: isTeacher,
        imageUrl: isTeacher
            ? 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=256&q=80'
            : 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=256&q=80',
        joinedDate: 'September 2026',
      );

      await _storage.write(key: _kSessionToken, value: token);
      await _storage.write(key: _kUserData, value: jsonEncode(user.toJson()));
      return user;
    }
  }

  @override
  Future<UserEntity> signUpWithEmailPassword(
    String email,
    String password, {
    String? firstName,
    String? lastName,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.authSignUp,
        data: {
          'email': email,
          'password': password,
          'firstName': firstName,
          'lastName': lastName,
        },
      );
      final data = res.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final userMap = data['user'] as Map<String, dynamic>;
      final user = UserEntity.fromJson(userMap);
      final finalUser = user.copyWith(isTeacher: _isTeacherId(user.id) || user.isTeacher);

      await _storage.write(key: _kSessionToken, value: token);
      await _storage.write(key: _kUserData, value: jsonEncode(finalUser.toJson()));
      return finalUser;
    } catch (_) {
      final userId = 'user_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
      final token = 'session_token_${DateTime.now().millisecondsSinceEpoch}_$userId';
      final isTeacher = _isTeacherId(userId);

      final user = UserEntity(
        id: userId,
        email: email,
        firstName: firstName ?? email.split('@').first,
        lastName: lastName,
        isTeacher: isTeacher,
        imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80',
        joinedDate: 'September 2026',
      );

      await _storage.write(key: _kSessionToken, value: token);
      await _storage.write(key: _kUserData, value: jsonEncode(user.toJson()));
      return user;
    }
  }

  @override
  Future<UserEntity> signInAsDemo({required bool isTeacher}) async {
    final userId = isTeacher ? 'teacher_admin_demo' : 'student_learner_demo';
    final token = 'demo_session_token_$userId';

    await _storage.write(key: _kSessionToken, value: token);

    try {
      final user = await fetchUserProfile();
      return user;
    } catch (_) {
      final user = UserEntity(
        id: userId,
        email: isTeacher ? 'teacher@oeplatform.dev' : 'student@oeplatform.dev',
        firstName: isTeacher ? 'Alex' : 'Jordan',
        lastName: isTeacher ? 'Instructor' : 'Learner',
        isTeacher: isTeacher,
        imageUrl: isTeacher
            ? 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=256&q=80'
            : 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=256&q=80',
        bio: isTeacher
            ? 'Senior Software Architect & Course Creator.'
            : 'Passionate student exploring cross-platform mobile development.',
        joinedDate: isTeacher ? 'September 2024' : 'January 2026',
      );

      await _storage.write(key: _kUserData, value: jsonEncode(user.toJson()));
      return user;
    }
  }

  @override
  Future<void> saveClerkUser(UserEntity user, [String? token]) async {
    final sessionToken = token ?? 'clerk_session_${user.id}';
    await _storage.write(key: _kSessionToken, value: sessionToken);
    await _storage.write(key: _kUserData, value: jsonEncode(user.toJson()));
  }

  @override
  Future<void> signOut() async {
    await _storage.delete(key: _kSessionToken);
    await _storage.delete(key: _kUserData);
  }

  @override
  Future<String?> getSessionToken() async {
    return _storage.read(key: _kSessionToken);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final dio = ref.watch(apiClientProvider);
  return AuthRepositoryImpl(storage, dio);
});

