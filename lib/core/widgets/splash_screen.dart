import 'package:flutter/material.dart';
import 'dart:async';
import 'package:neurobits/services/auth_service.dart';
import 'package:neurobits/services/convex_client_service.dart';

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
          _prefetchUserData(),
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

  Future<void> _prefetchUserData() async {
    try {
      if (!AuthService.isInitialized) {
        return;
      }
      if (AuthService.instance.currentStatus != AuthStatus.authenticated) {
        return;
      }
      await ConvexClientService.instance.query(name: 'users:getMe');
    } catch (e) {
      debugPrint('Prefetch error: $e');
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
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.2),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    'assets/neurobiticon.png',
                    width: 60,
                    height: 60,
                  ),
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
