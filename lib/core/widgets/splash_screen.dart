import 'package:flutter/material.dart';
import 'dart:async';
import 'package:neurobits/services/groq_service.dart';
import 'package:neurobits/services/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const SplashScreen({required this.onFinish, super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _controller.forward();
      final stopwatch = Stopwatch()..start();
      try {
        await Future.wait(<Future<void>>[
          GroqService.init(),
          _prefetchUserData(context),
        ]).timeout(const Duration(seconds: 5), onTimeout: () => <void>[]);
      } catch (_) {}
      final elapsed = stopwatch.elapsed.inMilliseconds;
      final minSplash = 2000;
      final maxSplash = 6000;
      final toWait = elapsed < minSplash ? minSplash - elapsed : 0;
      final total = elapsed + toWait;
      if (total < maxSplash) {
        await Future.delayed(Duration(milliseconds: toWait));
        widget.onFinish();
      } else {
        widget.onFinish();
      }
    });
  }

  Future<void> _prefetchUserData(BuildContext context) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;
      await Future.wait([
        SupabaseService.client
            .from('users')
            .select('*')
            .eq('id', userId)
            .maybeSingle(),
        SupabaseService.client
            .from('user_learning_paths')
            .select('id, is_complete')
            .eq('user_id', userId)
            .limit(1),
      ]);
      Future.microtask(() async {
        try {
          await Future.wait([
            SupabaseService.client
                .from('user_path_challenges')
                .select('id')
                .eq('user_learning_paths.user_id', userId)
                .limit(5),
            SupabaseService.client
                .from('challenges')
                .select('id, title')
                .limit(5),
            SupabaseService.client
                .from('learning_paths')
                .select('id, title')
                .limit(5),
          ]);
        } catch (e) {
          debugPrint('Background prefetch error: $e');
        }
      });
    } catch (e) {
      debugPrint('Essential prefetch error: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.2),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(Icons.bolt, size: 60, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Neurobits',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Train your brain. Level up.',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
