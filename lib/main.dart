import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neurobits/core/app_router.dart';
import 'package:neurobits/firebase_options.dart';
import 'package:neurobits/services/ai_service.dart';
import 'package:neurobits/services/auth_service.dart';
import 'package:neurobits/services/convex_client_service.dart';
import 'package:neurobits/core/widgets/splash_screen.dart';
import 'package:neurobits/services/content_moderation_service.dart';

bool _isTimeoutError(Object error) {
  return error is TimeoutException ||
      error.toString().contains('TimeoutException');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env", isOptional: true);
  } catch (e) {
    debugPrint("Warning: .env file not found, will use dart-define values: $e");
  }

  try {
    await AIService.init();
  } catch (e) {
    debugPrint("Error initializing AIService: $e");
  }

  try {
    await ContentModerationService.init();
  } catch (e) {
    debugPrint("Error initializing ContentModerationService: $e");
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final authService = await AuthService.init();
    final convexClient = await ConvexClientService.init();

    if (authService.currentStatus == AuthStatus.authenticated) {
      final idToken = await authService.getIdToken(forceRefresh: true);
      if (idToken != null) {
        await convexClient.setAuthToken(idToken);

        convexClient
            .mutation(
          name: 'users:ensureCurrent',
          args: {},
          timeout: const Duration(seconds: 15),
        )
            .catchError((e) {
          if (!_isTimeoutError(e)) {
            debugPrint('Warning: ensureCurrent failed: $e');
          }
        });
      }
    }

    var ensureCurrentInFlight = false;

    authService.idTokenChanges.listen((firebaseUser) async {
      if (firebaseUser == null) {
        await convexClient.setAuthToken(null);
        return;
      }

      final idToken = await authService.getIdToken();
      if (idToken == null) {
        await convexClient.setAuthToken(null);
        return;
      }

      await convexClient.setAuthToken(idToken);
      if (ensureCurrentInFlight) return;

      ensureCurrentInFlight = true;
      try {
        await convexClient.mutation(
          name: 'users:ensureCurrent',
          args: {},
          timeout: const Duration(seconds: 15),
        );
      } catch (e) {
        if (!_isTimeoutError(e)) {
          debugPrint('Warning: ensureCurrent failed (token listener): $e');
        }
      } finally {
        ensureCurrentInFlight = false;
      }
    });
  } catch (e) {
    debugPrint("Error initializing Firebase Auth/Convex: $e");
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text('Failed to initialize app'),
                const SizedBox(height: 8),
                Text('Error: $e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                const Text('Check that environment variables are configured'),
              ],
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Neurobits',
      theme: ThemeData.dark(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return _SplashWrapper(child: child!);
      },
    );
  }
}

class _SplashWrapper extends StatefulWidget {
  final Widget child;
  const _SplashWrapper({required this.child});
  @override
  State<_SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<_SplashWrapper> {
  bool _showSplash = true;
  static bool _hasShownSplash = false;
  @override
  void initState() {
    super.initState();

    if (_hasShownSplash) {
      _showSplash = false;
    } else {
      _hasShownSplash = true;
      _startSplashTimer();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _startSplashTimer() async {
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() => _showSplash = false);
    }

    _preloadDataInBackground();
  }

  void _preloadDataInBackground() {
    Future.microtask(() async {
      try {
        if (AuthService.instance.currentStatus == AuthStatus.authenticated) {
          ConvexClientService.instance.query(name: 'users:getMe');
        }
      } catch (e) {
        debugPrint('Background data preload error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _showSplash ? SplashScreen(onFinish: () {}) : widget.child;
  }
}
