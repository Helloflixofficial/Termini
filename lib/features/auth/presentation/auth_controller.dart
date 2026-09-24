import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../domain/user_entity.dart';

class AuthStateNotifier extends StateNotifier<AsyncValue<UserEntity?>> {
  final AuthRepository _repository;

  AuthStateNotifier(this._repository) : super(const AsyncValue.loading()) {
    checkCurrentUser();
  }

  Future<void> checkCurrentUser() async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.signInWithEmailPassword(email, password);
      state = AsyncValue.data(user);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> signUp(
    String email,
    String password, {
    String? firstName,
    String? lastName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.signUpWithEmailPassword(
        email,
        password,
        firstName: firstName,
        lastName: lastName,
      );
      state = AsyncValue.data(user);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> signInAsDemo({required bool isTeacher}) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.signInAsDemo(isTeacher: isTeacher);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refreshProfile() async {
    try {
      final user = await _repository.fetchUserProfile();
      state = AsyncValue.data(user);
    } catch (e) {
      // Keep current state if fetch fails
      debugPrint('[AuthController] refreshProfile error: $e');
    }
  }

  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? bio,
    String? imageUrl,
  }) async {
    try {
      final user = await _repository.updateUserProfile(
        firstName: firstName,
        lastName: lastName,
        bio: bio,
        imageUrl: imageUrl,
      );
      state = AsyncValue.data(user);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AsyncValue.data(null);
  }

  /// Called by [ClerkUserBridge] after a successful Clerk sign-in to
  /// inject the Clerk user into Riverpod state and persist session.
  Future<void> setClerkUser(UserEntity user, [String? token]) async {
    state = AsyncValue.data(user);
    await _repository.saveClerkUser(user, token);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<UserEntity?>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthStateNotifier(repo);
});

final currentUserProvider = Provider<UserEntity?>((ref) {
  return ref.watch(authControllerProvider).asData?.value;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

final isTeacherProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider)?.isTeacher ?? false;
});
