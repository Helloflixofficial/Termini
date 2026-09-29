import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/clerk_auth_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/community/presentation/community_notifications_screen.dart';
import '../../features/community/presentation/community_settings_screen.dart';
import '../../features/community/domain/community_entity.dart';
import '../../features/courses/presentation/course_detail_screen.dart';
import '../../features/courses/presentation/search_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/live/presentation/live_meet_screen.dart';
import '../../features/live/presentation/student_meet_screen.dart';
import '../../features/player/presentation/chapter_player_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/teacher/presentation/chapter_editor_screen.dart';
import '../../features/teacher/presentation/course_editor_screen.dart';
import '../../features/teacher/presentation/create_course_screen.dart';
import '../../features/teacher/presentation/teacher_analytics_screen.dart';
import '../../features/teacher/presentation/teacher_courses_screen.dart';
import '../../features/teacher/presentation/teacher_meet_screen.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authControllerProvider, (_, _) {
      notifyListeners();
    });
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final user = authState.asData?.value;
      final isLoading = authState.isLoading;

      final isAuthRoute = state.matchedLocation == '/sign-in' || state.matchedLocation == '/sign-up';

      // While auth is still loading (checking stored session), don't redirect at all.
      // This prevents the sign-in flash when Clerk is restoring a persisted session.
      if (isLoading) return null;

      // If user is not authenticated
      if (user == null) {
        // Allow public browsing for search, course preview, and auth routes
        final isPublicRoute = isAuthRoute ||
            state.matchedLocation.startsWith('/search') ||
            state.matchedLocation.startsWith('/course/');

        if (!isPublicRoute) {
          return '/sign-in';
        }
        return null;
      }

      // If user is authenticated and tries to visit sign-in / sign-up, redirect to dashboard
      if (isAuthRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      // Auth Routes — both sign-in and sign-up use the same Clerk screen
      GoRoute(
        path: '/sign-in',
        name: 'sign-in',
        builder: (context, state) => const ClerkAuthScreen(),
      ),
      GoRoute(
        path: '/sign-up',
        name: 'sign-up',
        builder: (context, state) => const ClerkAuthScreen(),
      ),

      // Student Routes
      GoRoute(
        path: '/',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/course/:courseId',
        name: 'course-detail',
        builder: (context, state) {
          final courseId = state.pathParameters['courseId'] ?? '';
          return CourseDetailScreen(courseId: courseId);
        },
      ),
      GoRoute(
        path: '/course/:courseId/chapters/:chapterId',
        name: 'chapter-player',
        builder: (context, state) {
          final courseId = state.pathParameters['courseId'] ?? '';
          final chapterId = state.pathParameters['chapterId'] ?? '';
          return ChapterPlayerScreen(
            courseId: courseId,
            chapterId: chapterId,
          );
        },
      ),
      GoRoute(
        path: '/community/post/:postId',
        name: 'community-post-detail',
        builder: (context, state) {
          final post = state.extra;
          if (post is CommunityPostEntity) {
            return CommunityPostDetailScreen(post: post);
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Post')),
            body: const Center(child: Text('This post is no longer available.')),
          );
        },
      ),
      GoRoute(
        path: '/community',
        name: 'community',
        builder: (context, state) => const CommunityScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const CommunityNotificationsScreen(),
      ),
      GoRoute(
        path: '/meet/:roomName',
        name: 'live-meet',
        builder: (context, state) {
          final roomName = state.pathParameters['roomName'] ?? 'default-room';
          return LiveMeetScreen(roomName: roomName);
        },
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/shortmeet',
        name: 'shortmeet',
        builder: (context, state) => const StudentMeetScreen(),
      ),

      // Teacher Routes
      GoRoute(
        path: '/teacher/courses',
        name: 'teacher-courses',
        builder: (context, state) => const TeacherCoursesScreen(),
      ),
      GoRoute(
        path: '/teacher/create',
        name: 'teacher-create',
        builder: (context, state) => const CreateCourseScreen(),
      ),
      GoRoute(
        path: '/teacher/courses/:courseId',
        name: 'teacher-course-editor',
        builder: (context, state) {
          final courseId = state.pathParameters['courseId'] ?? '';
          return CourseEditorScreen(courseId: courseId);
        },
      ),
      GoRoute(
        path: '/teacher/courses/:courseId/chapters/:chapterId',
        name: 'teacher-chapter-editor',
        builder: (context, state) {
          final courseId = state.pathParameters['courseId'] ?? '';
          final chapterId = state.pathParameters['chapterId'] ?? '';
          return ChapterEditorScreen(
            courseId: courseId,
            chapterId: chapterId,
          );
        },
      ),
      GoRoute(
        path: '/teacher/analytics',
        name: 'teacher-analytics',
        builder: (context, state) => const TeacherAnalyticsScreen(),
      ),
      GoRoute(
        path: '/teacher/meet',
        name: 'teacher-meet',
        builder: (context, state) => const TeacherMeetScreen(),
      ),
      GoRoute(
        path: '/teacher/community',
        name: 'teacher-community',
        builder: (context, state) => const CommunityScreen(),
      ),
      GoRoute(
        path: '/teacher/community/settings',
        name: 'teacher-community-settings',
        builder: (context, state) => const CommunitySettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page Not Found: ${state.uri}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Return Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
