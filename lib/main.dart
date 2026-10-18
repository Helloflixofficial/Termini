import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/config/env.dart';
import 'core/network/api_client.dart' show bindClerkAuthState;
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/courses/data/course_repository.dart';
import 'features/courses/presentation/course_detail_screen.dart'
    show courseDetailProvider;
import 'features/dashboard/presentation/dashboard_controller.dart'
    show dashboardControllerProvider;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await Firebase.initializeApp();
    } catch (error) {
      // Keep the app usable when the optional, local Firebase Android config
      // has not been installed yet. Push messaging will be enabled once added.
      debugPrint('[Termini Push] Firebase is not configured: $error');
    }
  }
  runApp(const ProviderScope(child: TerminiApp()));
}

class TerminiApp extends ConsumerStatefulWidget {
  const TerminiApp({super.key});

  @override
  ConsumerState<TerminiApp> createState() => _TerminiAppState();
}

class _TerminiAppState extends ConsumerState<TerminiApp> {
  final _appLinks = AppLinks();
  late final StreamController<Uri?> _deepLinkController;

  @override
  void initState() {
    super.initState();
    _deepLinkController = StreamController<Uri?>.broadcast();

    // Check cold-start initial deep link
    _appLinks
        .getInitialLink()
        .then((uri) {
          if (uri != null) {
            debugPrint('[Termini DeepLink] Initial link: $uri');
            _handleIncomingLink(uri);
          }
        })
        .catchError((err) {
          debugPrint('[Termini DeepLink] Initial link error: $err');
        });

    // Listen to incoming runtime deep links
    _appLinks.uriLinkStream.listen((uri) {
      debugPrint('[Termini DeepLink] Incoming link: $uri');
      _handleIncomingLink(uri);
    }, onError: (err) => debugPrint('[Termini DeepLink] Stream error: $err'));
  }

  void _handleIncomingLink(Uri uri) {
    if (uri.scheme == 'termini' &&
        uri.host == 'course' &&
        uri.pathSegments.length == 1) {
      unawaited(_handleCheckoutReturn(uri));
      return;
    }
    _deepLinkController.add(uri);
  }

  Future<void> _handleCheckoutReturn(Uri uri) async {
    final courseId = uri.pathSegments.single;
    final router = ref.read(appRouterProvider);
    if (uri.queryParameters['canceled'] == '1') {
      router.go('/course/${Uri.encodeComponent(courseId)}');
      return;
    }

    final sessionId = uri.queryParameters['session_id'];
    if (uri.queryParameters['success'] != '1' || sessionId == null) {
      router.go('/course/${Uri.encodeComponent(courseId)}');
      return;
    }

    var enrolled = false;
    try {
      enrolled = await ref
          .read(courseRepositoryProvider)
          .verifyCheckoutSession(courseId, sessionId);
    } catch (error) {
      debugPrint('[Termini Checkout] Payment confirmation pending: $error');
    }

    ref.invalidate(courseDetailProvider(courseId));
    ref.invalidate(dashboardControllerProvider);
    if (!mounted) return;
    router.go(enrolled ? '/' : '/course/${Uri.encodeComponent(courseId)}');
  }

  @override
  void dispose() {
    _deepLinkController.close();
    super.dispose();
  }

  /// Tells Clerk to redirect back to our app scheme after Chrome OAuth
  Uri? _generateDeepLink(BuildContext context, clerk.Strategy strategy) {
    if (strategy.isOauth) {
      return Uri(scheme: 'termini', host: 'oauth-callback');
    }
    return null;
  }

  /// Filters deep links so Clerk processes OAuth redirects
  Future<Uri?> _handleClerkDeepLink(Uri? uri) async {
    if (uri == null) return null;
    debugPrint('[Termini Clerk DeepLink Filter] Received: $uri');
    if (uri.scheme == 'termini' || uri.scheme == 'com.clerk.flutter') {
      return uri;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return ClerkAuth(
      config: ClerkAuthConfig(
        publishableKey: AppEnv.clerkPublishableKey,
        redirectionGenerator: _generateDeepLink,
        deepLinkStream: _deepLinkController.stream.asyncMap(
          _handleClerkDeepLink,
        ),
        defaultLaunchMode: LaunchMode.externalApplication,
      ),
      child: MaterialApp.router(
        title: 'Termini LMS',
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          bindClerkAuthState(ClerkAuth.of(context, listen: false));
          return _StartupSplash(child: child ?? const SizedBox.shrink());
        },
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        routerConfig: router,
        // Required by clerk_flutter for its built-in UI strings
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          ClerkSdkLocalizations.delegate,
        ],
        supportedLocales: ClerkSdkLocalizations.supportedLocales,
      ),
    );
  }
}

class _StartupSplash extends StatefulWidget {
  final Widget child;

  const _StartupSplash({required this.child});

  @override
  State<_StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<_StartupSplash> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_visible)
          Positioned.fill(
            child: IgnorePointer(
              child: Image.asset(
                'assets/branding/termini_splash.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
      ],
    );
  }
}
