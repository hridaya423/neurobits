import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neurobits/core/app_router.dart';
import 'package:neurobits/services/supabase.dart';
import 'package:neurobits/services/ai_service.dart';
import 'package:neurobits/core/widgets/splash_screen.dart';
import 'package:neurobits/services/content_moderation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env", isOptional: true);
  } catch (e) {
    debugPrint("Warning: .env file not found, will use dart-define values: $e");
  }

  try {
    await ContentModerationService.init();
  } catch (e) {
    debugPrint("Error initializing ContentModerationService: $e");
  }

  try {
    await AIService.init();
  } catch (e) {
    debugPrint("Error initializing AIService: $e");
  }

  try {
    await SupabaseService.init();
  } catch (e) {
    debugPrint("App cannot continue without Supabase");
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
    _listenForAuthRedirects();

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

  void _listenForAuthRedirects() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.passwordRecovery) {
        GoRouter.of(context).go('/auth/reset-password');
      }
    });
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
        final user = SupabaseService.client.auth.currentUser;
        if (user != null) {
          SupabaseService.getUserStats(user.id);
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
