import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termini/core/config/env.dart';
import 'package:termini/core/theme/app_colors.dart';
import 'package:termini/core/theme/app_theme.dart';
import 'package:termini/core/theme/theme_provider.dart';
import 'package:termini/core/widgets/empty_state.dart';
import 'package:termini/features/courses/domain/course_entity.dart';
import 'package:termini/features/courses/presentation/widgets/course_card.dart';

void main() {
  group('Core & Configuration Tests', () {
    test('AppEnv provides non-empty default values', () {
      expect(AppEnv.apiBaseUrl, isNotEmpty);
      expect(AppEnv.clerkPublishableKey, isNotEmpty);
      expect(AppEnv.liveKitUrl, isNotEmpty);
    });

    test('AppTheme defines consistent light and dark color schemes', () {
      final light = AppTheme.lightTheme;
      final dark = AppTheme.darkTheme;

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.colorScheme.primary, AppColors.lightPrimary);
      expect(dark.colorScheme.primary, AppColors.darkPrimary);
    });
  });

  group('UI Widget Tests', () {
    testWidgets('Theme toggle widget renders and triggers toggle', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: ThemeToggleButton(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(ThemeToggleButton), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(find.byType(ThemeToggleButton), findsOneWidget);
    });

    testWidgets('EmptyStateWidget renders icon, title, description, and action button',
        (WidgetTester tester) async {
      bool actionPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.school_outlined,
              title: 'No Courses Yet',
              description: 'You have not enrolled in any courses.',
              actionLabel: 'Browse Courses',
              onAction: () {
                actionPressed = true;
              },
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('No Courses Yet'), findsOneWidget);
      expect(find.text('You have not enrolled in any courses.'), findsOneWidget);
      expect(find.text('Browse Courses'), findsOneWidget);
      expect(find.byIcon(Icons.school_outlined), findsOneWidget);

      await tester.tap(find.text('Browse Courses'));
      expect(actionPressed, isTrue);
    });

    testWidgets('CourseCard renders course details correctly', (WidgetTester tester) async {
      const sampleCourse = CourseEntity(
        id: 'course-123',
        userId: 'teacher-1',
        title: 'Flutter Full Stack Masterclass',
        description: 'Learn Flutter, Riverpod, Next.js, and LiveKit.',
        price: 49.99,
        isPublished: true,
        chaptersCount: 12,
        progress: 50.0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CourseCard(course: sampleCourse),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Flutter Full Stack Masterclass'), findsOneWidget);
      expect(find.text('12 Chapters'), findsOneWidget);
      expect(find.text('50% Complete'), findsOneWidget);
    });
  });
}
