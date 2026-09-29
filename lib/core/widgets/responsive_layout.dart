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

  int _getBottomNavIndex(String route) {
    if (route == '/profile') return 4;
    if (route == '/') return 0;
    if (route == '/search') return 1;
    if (route == '/community') return 2;
    if (route == '/shortmeet' || route.startsWith('/meet')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenType = Breakpoints.getScreenType(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
          currentIndex: _getBottomNavIndex(currentRoute),
          type: BottomNavigationBarType.fixed,
          backgroundColor: colorScheme.surface,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurfaceVariant,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          onTap: (index) {
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
                context.go('/shortmeet');
                break;
              case 4:
                context.go('/profile');
                break;
            }
          },
          items: const [
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
              icon: Icon(Icons.videocam_outlined),
              activeIcon: Icon(Icons.videocam_rounded),
              label: 'ShortMeet',
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
