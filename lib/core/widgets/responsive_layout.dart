import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../utils/breakpoints.dart';
import 'app_sidebar.dart';
import 'top_navbar.dart';

class ResponsiveLayout extends ConsumerWidget {
  final String title;
  final String currentRoute;
  final Widget body;
  final bool showSearch;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const ResponsiveLayout({
    super.key,
    required this.title,
    required this.currentRoute,
    required this.body,
    this.showSearch = false,
    this.actions,
    this.floatingActionButton,
  });

  int _getBottomNavIndex(String route, bool isTeacher) {
    if (route == '/profile') return 4;
    if (isTeacher) {
      if (route == '/teacher/courses') return 0;
      if (route == '/teacher/analytics') return 1;
      if (route == '/teacher/community') return 2;
      if (route == '/teacher/meet') return 3;
      return 0;
    }
    if (route == '/') return 0;
    if (route == '/search') return 1;
    if (route == '/community') return 2;
    if (route.startsWith('/teacher')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenType = Breakpoints.getScreenType(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTeacherMode = currentRoute.startsWith('/teacher');

    if (screenType == ScreenType.compact) {
      return Scaffold(
        appBar: TopNavbar(
          title: title,
          showSearch: showSearch,
          actions: actions,
        ),
        drawer: Drawer(
          child: SafeArea(
            child: AppSidebar(
              currentRoute: currentRoute,
              onNavigate: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        body: body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _getBottomNavIndex(currentRoute, isTeacherMode),
          type: BottomNavigationBarType.fixed,
          backgroundColor: colorScheme.surface,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurfaceVariant,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          onTap: (index) {
            if (index == 4) {
              context.go('/profile');
              return;
            }
            if (isTeacherMode) {
              switch (index) {
                case 0:
                  context.go('/teacher/courses');
                  break;
                case 1:
                  context.go('/teacher/analytics');
                  break;
                case 2:
                  context.go('/teacher/community');
                  break;
                case 3:
                  context.go('/teacher/meet');
                  break;
              }
            } else {
              switch (index) {
                case 0:
                  context.go('/');
                  break;
                case 1:
                  context.go('/search');
                  break;
                case 2:
                  context.go('/community');
                  break;
                case 3:
                  context.go('/teacher/courses');
                  break;
              }
            }
          },
          items: isTeacherMode
              ? const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.list_alt_rounded),
                    label: 'Courses',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.bar_chart_rounded),
                    label: 'Analytics',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.forum_outlined),
                    label: 'Community',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.videocam_outlined),
                    label: 'ShortMeet',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings_outlined),
                    activeIcon: Icon(Icons.settings_rounded),
                    label: 'Settings',
                  ),
                ]
              : const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.dashboard_outlined),
                    activeIcon: Icon(Icons.dashboard_rounded),
                    label: 'Dashboard',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.explore_outlined),
                    activeIcon: Icon(Icons.explore_rounded),
                    label: 'Search',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.forum_outlined),
                    activeIcon: Icon(Icons.forum_rounded),
                    label: 'Community',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.school_outlined),
                    activeIcon: Icon(Icons.school_rounded),
                    label: 'Studio',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings_outlined),
                    activeIcon: Icon(Icons.settings_rounded),
                    label: 'Settings',
                  ),
                ],
        ),
      );
    }

    final isMedium = screenType == ScreenType.medium;

    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            currentRoute: currentRoute,
            isCollapsed: isMedium,
          ),
          Expanded(
            child: Column(
              children: [
                TopNavbar(
                  title: title,
                  showSearch: showSearch,
                  actions: actions,
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
