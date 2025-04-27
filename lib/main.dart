import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neurobits/core/app_router.dart';
import 'package:neurobits/services/supabase.dart';
import 'package:neurobits/services/groq_service.dart';
import 'package:neurobits/core/widgets/splash_screen.dart';
import 'package:neurobits/features/onboarding/onboarding_gate.dart';
import 'package:neurobits/core/learning_path_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await GroqService.init();
  await SupabaseService.init();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    initializeUserPathProvider(ref);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Neurobits',
      theme: ThemeData.dark(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return _SplashWrapper(child: OnboardingGate(child: child!));
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
  bool _statsLoaded = false;
  DateTime? _splashStart;

  @override
  void initState() {
    super.initState();
    _splashStart = DateTime.now();
    _preloadUserStats();
  }

  Future<void> _preloadUserStats() async {
    final minSplash = Duration(seconds: 2);
    final splashStart = DateTime.now();
    Future statsFuture = (() async {
      try {
        final user = SupabaseService.client.auth.currentUser;
        if (user != null) {
          await SupabaseService.getUserStats(user.id);
        }
      } catch (_) {}
    })();
    await Future.wait([Future.delayed(minSplash), statsFuture]);
    if (mounted) setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    return _showSplash ? SplashScreen(onFinish: () {}) : widget.child;
  }
}
