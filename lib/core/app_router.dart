import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neurobits/core/go_router_refresh_stream.dart';
import 'package:neurobits/features/auth/login_screen.dart';
import 'package:neurobits/features/auth/signup_screen.dart';
import 'package:neurobits/features/challenges/screens/quiz_screen.dart';
import 'package:neurobits/features/challenges/screens/challenge_loader_screen.dart';
import 'package:neurobits/features/dashboard/dashboard_screen.dart';
import 'package:neurobits/features/profile/screens/profile_screen.dart';
import 'package:neurobits/features/landing/landingpage.dart';
import 'package:neurobits/services/supabase.dart';
import 'package:neurobits/features/challenges/screens/topic_customization_screen.dart';
import 'package:neurobits/features/onboarding/onboarding_gate.dart';
import 'dart:convert';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/landing',
    refreshListenable:
        GoRouterRefreshStream(SupabaseService.client.auth.onAuthStateChange),
    redirect: (context, state) {
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isLandingRoute = state.matchedLocation == '/landing';
      final isLoggedIn = SupabaseService.client.auth.currentUser != null;
      final isDashboard = state.matchedLocation == '/';
      if (!isLoggedIn && !isAuthRoute && !isLandingRoute) {
        return '/landing';
      }
      if (isLoggedIn && (isAuthRoute || isLandingRoute)) {
        if (!isDashboard) {
          return '/';
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/landing',
        pageBuilder: (context, state) => const CustomTransitionPage(
          transitionDuration: Duration(milliseconds: 4000),
          child: NewLandingPage(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => const CustomTransitionPage(
          transitionDuration: Duration(milliseconds: 4000),
          child: OnboardingGate(child: DashboardScreen()),
          transitionsBuilder: _fadeTransition,
        ),
        routes: [
          GoRoute(
            path: 'challenge/:id/_loaded',
            pageBuilder: (context, state) {
              final challenge = state.extra;
              List<Map<String, dynamic>> questions = [];
              if (challenge is Map<String, dynamic>) {
                final q = challenge['questions'];
                if (q is List && q.every((e) => e is Map)) {
                  questions = List<Map<String, dynamic>>.from(
                      q.map((e) => Map<String, dynamic>.from(e)));
                } else if (q is String) {
                  try {
                    final decoded = q.startsWith('[') ? q : '[$q]';
                    final parsed = jsonDecode(decoded);
                    if (parsed is List && parsed.every((e) => e is Map)) {
                      questions = List<Map<String, dynamic>>.from(
                          parsed.map((e) => Map<String, dynamic>.from(e)));
                    }
                  } catch (_) {}
                }
              } else {
                debugPrint(
                    "Error: /_loaded route reached without valid Map extra.");
              }
              if (questions.isEmpty) {
                debugPrint(
                    "Warning: /_loaded route reached but queSstions are empty or invalid.");
              }
              return CustomTransitionPage(
                transitionDuration: const Duration(milliseconds: 4000),
                child: challenge is Map<String, dynamic>
                    ? ChallengeScreen(
                        topic: challenge['topic']?.toString() ??
                            challenge['title']?.toString() ??
                            '',
                        questions: questions,
                        quizName: challenge['quiz_name']?.toString() ??
                            challenge['title']?.toString(),
                        timedMode: challenge['timedMode'] is bool
                            ? challenge['timedMode']
                            : true,
                      )
                    : Scaffold(
                        body: Center(child: Text("Invalid challenge data"))),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          GoRoute(
            path: 'challenge/:id',
            pageBuilder: (context, state) {
              debugPrint(
                  "Navigating to challenge loader with extra: ${state.extra}");
              return CustomTransitionPage(
                transitionDuration: const Duration(milliseconds: 4000),
                child: ChallengeLoaderScreen(challengeData: state.extra),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          GoRoute(
            path: 'topic/:topic',
            pageBuilder: (context, state) => CustomTransitionPage(
              transitionDuration: const Duration(milliseconds: 4000),
              child: TopicCustomizationScreen(
                topic: state.pathParameters['topic'] ?? '',
              ),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: 'ai-challenge',
            pageBuilder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              return CustomTransitionPage(
                transitionDuration: const Duration(milliseconds: 4000),
                child: ChallengeScreen(
                  topic: extra['topic'] as String,
                  questions: extra['questions'] as List<Map<String, dynamic>>,
                  quizName: extra['quiz_name'] as String,
                  timedMode: extra['timedMode'] as bool,
                ),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/dashboard',
        pageBuilder: (context, state) => const CustomTransitionPage(
          transitionDuration: Duration(milliseconds: 4000),
          child: OnboardingGate(child: DashboardScreen()),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/auth/login',
        pageBuilder: (context, state) => const CustomTransitionPage(
          transitionDuration: Duration(milliseconds: 4000),
          child: LoginScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/auth/signup',
        pageBuilder: (context, state) => const CustomTransitionPage(
          transitionDuration: Duration(milliseconds: 4000),
          child: SignupScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => const CustomTransitionPage(
          transitionDuration: Duration(milliseconds: 4000),
          child: ProfileScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
    ],
  );
});
Widget _fadeTransition(BuildContext context, Animation<double> animation,
    Animation<double> secondaryAnimation, Widget child) {
  return Stack(
    children: [
      FadeTransition(
        opacity: animation,
        child: child,
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _SparklePainter(animation.value),
          ),
        ),
      ),
    ],
  );
}

Widget _slideTransition(BuildContext context, Animation<double> animation,
    Animation<double> secondaryAnimation, Widget child) {
  const begin = Offset(0.0, 0.08);
  const end = Offset.zero;
  final tween = Tween(begin: begin, end: end)
      .chain(CurveTween(curve: Curves.easeOutCubic));
  return Stack(
    children: [
      SlideTransition(
        position: animation.drive(tween),
        child: child,
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _SparklePainter(animation.value),
          ),
        ),
      ),
    ],
  );
}

class _SparklePainter extends CustomPainter {
  final double progress;

  _SparklePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final sparkleCount = 15;
    for (int i = 0; i < sparkleCount; i++) {
      final seed = i * 123.456;
      final x = (seed % size.width);
      final y = ((seed * 1.5) % size.height);

      final sparkleProgress =
          ((progress * 3) - (i / sparkleCount)).clamp(0.0, 1.0);
      final opacity =
          (sparkleProgress * (1 - sparkleProgress) * 4).clamp(0.0, 1.0);

      if (opacity > 0) {
        paint.color = Color.lerp(
          const Color(0xFFFFD700),
          const Color(0xFFFFFFFF),
          i % 2 == 0 ? 0.3 : 0.7,
        )!
            .withOpacity(opacity);

        final sparkleSize = 4.0 + (i % 3) * 2.0;
        _drawStar(canvas, paint, Offset(x, y), sparkleSize);
      }
    }
  }

  void _drawStar(Canvas canvas, Paint paint, Offset center, double size) {
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final angle = (i * 90) * (3.14159 / 180);
      final x = center.dx + size * (i % 2 == 0 ? 1 : 0.3) * (i < 2 ? 1 : -1);
      final y = center.dy +
          size * (i % 2 == 1 ? 1 : 0.3) * (i == 1 || i == 2 ? 1 : -1);

      if (i == 0) {
        path.moveTo(x, center.dy);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);

    canvas.drawCircle(
      center,
      size * 0.3,
      paint..color = paint.color.withOpacity(paint.color.opacity * 0.5),
    );
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) =>
      progress != oldDelegate.progress;
}
