import 'package:flutter/material.dart';

enum ScreenType { compact, medium, expanded }

class Breakpoints {
  const Breakpoints._();

  static const double compactMax = 600.0;
  static const double mediumMax = 1024.0;

  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < compactMax) return ScreenType.compact;
    if (width < mediumMax) return ScreenType.medium;
    return ScreenType.expanded;
  }

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactMax;

  static bool isMedium(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= compactMax && width < mediumMax;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mediumMax;

  static int getGridCrossAxisCount(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < compactMax) return 1;
    if (width < mediumMax) return 2;
    if (width < 1400) return 3;
    return 4;
  }
}
