import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user_entity.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../theme/theme_provider.dart';

class AppSidebar extends ConsumerWidget {
  final String currentRoute;
  final bool isCollapsed;
  final VoidCallback? onNavigate;

  const AppSidebar({
    super.key,
    required this.currentRoute,
    this.isCollapsed = false,
    this.onNavigate,
  });

  static const _studentItems = <_SidebarDestination>[
    _SidebarDestination('Dashboard', '/', Icons.grid_view_rounded),
    _SidebarDestination('Search courses', '/search', Icons.explore_rounded),
    _SidebarDestination('Listing', '/listing', Icons.currency_bitcoin_rounded),
    _SidebarDestination('Community', '/community', Icons.forum_outlined),
    _SidebarDestination(
      'ShortMeet',
      '/shortmeet',
      Icons.video_camera_front_outlined,
    ),
  ];

  static const _listingItems = <_SidebarDestination>[
    _SidebarDestination('Markets', '/listing/markets', Icons.candlestick_chart),
    _SidebarDestination(
      'Trending',
      '/listing/trending',
      Icons.local_fire_department_outlined,
    ),
    _SidebarDestination(
      'Top gainers',
      '/listing/gainers',
      Icons.trending_up_rounded,
    ),
    _SidebarDestination(
      'Top losers',
      '/listing/losers',
      Icons.trending_down_rounded,
    ),
    _SidebarDestination(
      'Categories',
      '/listing/categories',
      Icons.category_outlined,
    ),
    _SidebarDestination(
      'Watchlist',
      '/listing/watchlist',
      Icons.star_outline_rounded,
    ),
  ];

  bool _isActive(String route) =>
      currentRoute == route || (route != '/' && currentRoute.startsWith(route));

  void _go(BuildContext context, String route) {
    onNavigate?.call();
    context.go(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final canTeach = user?.isTeacher ?? false;
    final selected = isDark ? Colors.white : const Color(0xFF111111);
    final selectedForeground = isDark ? const Color(0xFF111111) : Colors.white;
    final destinations = <_SidebarDestination>[
      ..._studentItems,
      if (canTeach) ...const [
        _SidebarDestination(
          'My courses',
          '/teacher/courses',
          Icons.menu_book_outlined,
        ),
        _SidebarDestination(
          'Analytics',
          '/teacher/analytics',
          Icons.analytics_outlined,
        ),
        _SidebarDestination(
          'Host a meeting',
          '/teacher/meet',
          Icons.video_call_outlined,
        ),
      ],
    ];

    return Material(
      color: scheme.surface,
      child: SizedBox(
        width: isCollapsed ? 76 : 286,
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _BrandMark(isDark: isDark),
                  const SizedBox(height: 26),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: destinations.length,
                      itemBuilder: (context, index) {
                        final item = destinations[index];
                        return _RailButton(
                          icon: item.icon,
                          label: item.label,
                          selected: _isActive(item.route),
                          selectedColor: selected,
                          foregroundColor: selectedForeground,
                          idleColor: scheme.onSurfaceVariant,
                          onTap: () => _go(context, item.route),
                        );
                      },
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.8),
                    margin: const EdgeInsets.only(bottom: 12),
                  ),
                  _RailButton(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    selected: _isActive('/profile'),
                    selectedColor: selected,
                    foregroundColor: selectedForeground,
                    idleColor: scheme.onSurfaceVariant,
                    onTap: () => _go(context, '/profile'),
                  ),
                  _RailButton(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notifications',
                    selected: _isActive('/notifications'),
                    selectedColor: selected,
                    foregroundColor: selectedForeground,
                    idleColor: scheme.onSurfaceVariant,
                    onTap: () => _go(context, '/notifications'),
                  ),
                  const SizedBox(height: 7),
                  Tooltip(
                    message: isDark
                        ? 'Switch to light theme'
                        : 'Switch to dark theme',
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: const ThemeToggleButton(isCompact: true),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SidebarAvatar(
                    user: user,
                    onTap: () => _go(context, '/profile'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            if (!isCollapsed) ...[
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.75),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 24, 14, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Termini',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.expand_more_rounded,
                            size: 19,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          for (final item in destinations) ...[
                            _SidebarNavItem(
                              item: item,
                              selected:
                                  _isActive(item.route) &&
                                  (item.route != '/listing' ||
                                      currentRoute == '/listing'),
                              selectedColor: selected,
                              foregroundColor: selectedForeground,
                              idleColor: scheme.onSurfaceVariant,
                              onTap: () => _go(context, item.route),
                            ),
                            if (item.route == '/listing' &&
                                _isActive('/listing'))
                              for (final subitem in _listingItems)
                                Padding(
                                  padding: const EdgeInsets.only(left: 16),
                                  child: _SidebarNavItem(
                                    item: subitem,
                                    selected: currentRoute == subitem.route,
                                    selectedColor: selected,
                                    foregroundColor: selectedForeground,
                                    idleColor: scheme.onSurfaceVariant,
                                    onTap: () => _go(context, subitem.route),
                                    showIcon: false,
                                  ),
                                ),
                          ],
                          const SizedBox(height: 12),
                          Divider(
                            color: scheme.outlineVariant.withValues(alpha: 0.8),
                          ),
                          _SidebarNavItem(
                            item: const _SidebarDestination(
                              'Notifications',
                              '/notifications',
                              Icons.notifications_none_rounded,
                            ),
                            selected: _isActive('/notifications'),
                            selectedColor: selected,
                            foregroundColor: selectedForeground,
                            idleColor: scheme.onSurfaceVariant,
                            onTap: () => _go(context, '/notifications'),
                          ),
                          _SidebarNavItem(
                            item: const _SidebarDestination(
                              'Settings',
                              '/profile',
                              Icons.settings_outlined,
                            ),
                            selected: _isActive('/profile'),
                            selectedColor: selected,
                            foregroundColor: selectedForeground,
                            idleColor: scheme.onSurfaceVariant,
                            onTap: () => _go(context, '/profile'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: _ExploreCard(
                        isDark: isDark,
                        onTap: () => _go(context, '/search'),
                      ),
                    ),
                    _AccountFooter(
                      user: user,
                      onTap: () => _go(context, '/profile'),
                      onSignOut: () async {
                        await ref
                            .read(authControllerProvider.notifier)
                            .signOut();
                        if (context.mounted) context.go('/sign-in');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SidebarDestination {
  final String label;
  final String route;
  final IconData icon;

  const _SidebarDestination(this.label, this.route, this.icon);
}

class _BrandMark extends StatelessWidget {
  final bool isDark;
  const _BrandMark({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fill = isDark ? Colors.white : const Color(0xFF111111);
    final ink = isDark ? const Color(0xFF111111) : Colors.white;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.school_rounded, size: 21, color: ink),
    );
  }
}

class _RailButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color foregroundColor;
  final Color idleColor;
  final VoidCallback onTap;

  const _RailButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.foregroundColor,
    required this.idleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Tooltip(
      message: label,
      child: Material(
        color: selected ? selectedColor : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 21,
              color: selected ? foregroundColor : idleColor,
            ),
          ),
        ),
      ),
    ),
  );
}

class _SidebarNavItem extends StatelessWidget {
  final _SidebarDestination item;
  final bool selected;
  final Color selectedColor;
  final Color foregroundColor;
  final Color idleColor;
  final VoidCallback onTap;
  final bool showIcon;

  const _SidebarNavItem({
    required this.item,
    required this.selected,
    required this.selectedColor,
    required this.foregroundColor,
    required this.idleColor,
    required this.onTap,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected ? selectedColor : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 42,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  if (showIcon)
                    Icon(
                      item.icon,
                      size: 19,
                      color: selected ? foregroundColor : idleColor,
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle?.copyWith(
                        color: selected ? foregroundColor : idleColor,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarAvatar extends StatelessWidget {
  final UserEntity? user;
  final VoidCallback onTap;
  const _SidebarAvatar({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initial = user?.firstName?.isNotEmpty == true
        ? user!.firstName![0].toUpperCase()
        : (user?.email.isNotEmpty == true ? user!.email[0].toUpperCase() : 'U');
    return Tooltip(
      message: user?.fullName ?? 'Profile',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: Theme.of(context).colorScheme.secondary,
          backgroundImage: user?.imageUrl?.isNotEmpty == true
              ? CachedNetworkImageProvider(user!.imageUrl!)
              : null,
          child: user?.imageUrl?.isNotEmpty == true
              ? null
              : Text(
                  initial,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  const _ExploreCard({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: isDark ? scheme.surfaceContainerHighest : const Color(0xFFF4F4F4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Keep learning',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 3),
              Text(
                'Find your next course',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 32,
                child: FilledButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.explore_outlined, size: 15),
                  label: const Text('Explore', style: TextStyle(fontSize: 11)),
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white
                        : const Color(0xFF111111),
                    foregroundColor: isDark
                        ? const Color(0xFF111111)
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountFooter extends StatelessWidget {
  final UserEntity? user;
  final VoidCallback onTap;
  final Future<void> Function() onSignOut;
  const _AccountFooter({
    required this.user,
    required this.onTap,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = user?.fullName ?? 'Guest User';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.75)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      user?.isTeacher == true ? 'Instructor' : 'Student',
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            visualDensity: VisualDensity.compact,
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
