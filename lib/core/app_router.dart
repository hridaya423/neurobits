import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neurobits/core/go_router_refresh_stream.dart';
import 'package:neurobits/core/providers.dart';
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
  final authState = ref.watch(userProvider);
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/landing',
    refreshListenable:
        GoRouterRefreshStream(SupabaseService.client.auth.onAuthStateChange),
    redirect: (context, state) {
      if (!authState.hasValue) {
        return null;
      }
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isLandingRoute = state.matchedLocation == '/landing';
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
          child: NewLandingPage(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => const CustomTransitionPage(
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
                    "Warning: /_loaded route reached but questions are empty or invalid.");
              }
              return CustomTransitionPage(
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
                child: ChallengeLoaderScreen(challengeData: state.extra),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          GoRoute(
            path: 'topic/:topic',
            pageBuilder: (context, state) => CustomTransitionPage(
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
          child: OnboardingGate(child: DashboardScreen()),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/auth/login',
        pageBuilder: (context, state) => const CustomTransitionPage(
          child: LoginScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/auth/signup',
        pageBuilder: (context, state) => const CustomTransitionPage(
          child: SignupScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => const CustomTransitionPage(
          child: ProfileScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
    ],
  );
});
Widget _fadeTransition(BuildContext context, Animation<double> animation,
    Animation<double> secondaryAnimation, Widget child) {
  return FadeTransition(
    opacity: animation,
    child: child,
  );
}

Widget _slideTransition(BuildContext context, Animation<double> animation,
    Animation<double> secondaryAnimation, Widget child) {
  const begin = Offset(0.0, 0.08);
  const end = Offset.zero;
  final tween = Tween(begin: begin, end: end)
      .chain(CurveTween(curve: Curves.easeOutCubic));
  return SlideTransition(
    position: animation.drive(tween),
    child: child,
  );
}
