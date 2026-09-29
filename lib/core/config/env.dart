import 'package:flutter/foundation.dart';

class AppEnv {
  const AppEnv._();

  static const String _envApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_envApiBaseUrl.isNotEmpty) return _envApiBaseUrl;
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:3000'
        : 'http://localhost:3000';
  }

  static const String clerkPublishableKey = String.fromEnvironment(
    'CLERK_PUBLISHABLE_KEY',
    defaultValue: 'pk_test_Zmxvd2luZy1zdGFyZmlzaC04NS5jbGVyay5hY2NvdW50cy5kZXYk',
  );

  static const String liveKitUrl = String.fromEnvironment(
    'LIVEKIT_URL',
    defaultValue: 'wss://oep-3u0116of.livekit.cloud',
  );

  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: 'pk_test_51Q6xacSJq8qqNVo9co1qOCGBXdiMR3aoOYFRmd2A8jebfd5lInzgIUEJiqiDThKzDtYSr3rfxf8Incxyfk1Oy4fp00uXqefP6k',
  );

  static const String teacherIds = String.fromEnvironment(
    'NEXT_PUBLIC_TEACHER_ID',
    defaultValue: 'user_2ZrBFVtrrTrK0EbbS93RQHjQgX3',
  );
}
