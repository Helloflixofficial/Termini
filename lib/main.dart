import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/config/env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: TerminiApp(),
    ),
  );
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
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        debugPrint('[Termini DeepLink] Initial link: $uri');
        _deepLinkController.add(uri);
      }
    }).catchError((err) {
      debugPrint('[Termini DeepLink] Initial link error: $err');
    });

    // Listen to incoming runtime deep links
    _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('[Termini DeepLink] Incoming link: $uri');
        _deepLinkController.add(uri);
      },
      onError: (err) => debugPrint('[Termini DeepLink] Stream error: $err'),
    );
  }

  @override
  void dispose() {
    _deepLinkController.close();
    super.dispose();
  }

  /// Tells Clerk to redirect back to our app scheme after Chrome OAuth
  Uri? _generateDeepLink(BuildContext context, clerk.Strategy strategy) {
    if (strategy.isOauth) {
      return Uri(
        scheme: 'termini',
        host: 'oauth-callback',
      );
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
        deepLinkStream: _deepLinkController.stream.asyncMap(_handleClerkDeepLink),
        defaultLaunchMode: LaunchMode.externalApplication,
      ),
      child: MaterialApp.router(
        title: 'Termini LMS',
        debugShowCheckedModeBanner: false,
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
