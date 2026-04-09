import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neurobits/core/go_router_refresh_stream.dart';

import 'package:neurobits/features/challenges/screens/quiz_screen.dart';
import 'package:neurobits/features/challenges/screens/challenge_loader_screen.dart';
import 'package:neurobits/features/dashboard/dashboard_screen.dart';
import 'package:neurobits/features/profile/screens/profile_screen.dart';
import 'package:neurobits/features/landing/landingpage.dart';
import 'package:neurobits/features/auth/login_screen.dart';
import 'package:neurobits/features/reports/report_screen.dart';
import 'package:neurobits/features/exams/exam_dashboard_screen.dart';
import 'package:neurobits/features/exams/exam_mode_hub_screen.dart';
import 'package:neurobits/features/exams/exam_mode_setup_screen.dart';
import 'package:neurobits/features/exams/exam_planning_screen.dart';
import 'package:neurobits/features/exams/exam_curriculum_breakdown_screen.dart';
import 'package:neurobits/features/exams/exam_subject_report_screen.dart';
import 'package:neurobits/services/auth_service.dart';
import 'package:neurobits/features/challenges/screens/topic_customization_screen.dart';
import 'package:neurobits/features/onboarding/onboarding_gate.dart';
import 'dart:convert';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/',
    refreshListenable:
        GoRouterRefreshStream(AuthService.instance.authStateChanges),
    redirect: (context, state) {
      final matchedLocation = state.matchedLocation;
      final isAuthRoute =
          matchedLocation == '/landing' || matchedLocation == '/login';
      final isLoggedIn =
          AuthService.instance.currentStatus == AuthStatus.authenticated;
      if (!isLoggedIn && !isAuthRoute) {
        return '/landing';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/landing',
        pageBuilder: (context, state) => const CustomTransitionPage(
          transitionDuration: Duration(milliseconds: 300),
          child: NewLandingPage(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) {
          final isSignUp = state.uri.queryParameters['signup'] == 'true';
          return CustomTransitionPage(
            transitionDuration: const Duration(milliseconds: 300),
            child: LoginScreen(initialSignUp: isSignUp),
            transitionsBuilder: _slideTransition,
          );
        },
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => const CustomTransitionPage(
          transitionDuration: Duration(milliseconds: 300),
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
                transitionDuration: const Duration(milliseconds: 300),
                child: challenge is Map<String, dynamic>
                    ? ChallengeScreen(
                        topic: challenge['topic']?.toString() ??
                            challenge['title']?.toString() ??
                            '',
                        questions: questions,
                        quizName: challenge['quiz_name']?.toString() ??
                            challenge['quizName']?.toString() ??
                            challenge['title']?.toString(),
                        timedMode: challenge['timedMode'] is bool
                            ? challenge['timedMode']
                            : true,
                        hintsEnabled: challenge['hintsEnabled'] is bool
                            ? challenge['hintsEnabled'] as bool
                            : false,
                        challengeId: challenge['challengeId']?.toString() ??
                            challenge['_id']?.toString(),
                        userPathChallengeId:
                            challenge['userPathChallengeId']?.toString() ??
                                challenge['user_path_challenge_id']?.toString(),
                        examTargetId: challenge['examTargetId']?.toString() ??
                            challenge['exam_target_id']?.toString(),
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
              return CustomTransitionPage(
                transitionDuration: const Duration(milliseconds: 300),
                child: ChallengeLoaderScreen(challengeData: state.extra),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          GoRoute(
            path: 'topic/:topic',
            pageBuilder: (context, state) => CustomTransitionPage(
              transitionDuration: const Duration(milliseconds: 300),
              child: TopicCustomizationScreen(
                topic: state.pathParameters['topic'] ?? '',
                userPathChallengeId: (state.extra is Map<String, dynamic>)
                    ? (state.extra
                            as Map<String, dynamic>)['userPathChallengeId']
                        ?.toString()
                    : null,
                examTargetId: (state.extra is Map<String, dynamic>)
                    ? (state.extra as Map<String, dynamic>)['examTargetId']
                        ?.toString()
                    : null,
                quizPreset: (state.extra is Map<String, dynamic>)
                    ? ((state.extra as Map<String, dynamic>)['quizPreset']
                            as Map?)
                        ?.map((key, value) => MapEntry(key.toString(), value))
                    : null,
              ),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: 'ai-challenge',
            pageBuilder: (context, state) {
              final extra = state.extra;
              if (extra is! Map<String, dynamic>) {
                return const CustomTransitionPage(
                  transitionDuration: Duration(milliseconds: 300),
                  child: Scaffold(
                    body: Center(child: Text('Invalid challenge data')),
                  ),
                  transitionsBuilder: _slideTransition,
                );
              }
              return CustomTransitionPage(
                transitionDuration: const Duration(milliseconds: 300),
                child: ChallengeScreen(
                  topic: extra['topic']?.toString() ?? '',
                  questions: (extra['questions'] is List)
                      ? List<Map<String, dynamic>>.from(
                          (extra['questions'] as List)
                              .whereType<Map>()
                              .map((e) => Map<String, dynamic>.from(e)),
                        )
                      : <Map<String, dynamic>>[],
                  quizName: extra['quiz_name']?.toString() ??
                      extra['quizName']?.toString(),
                  timedMode: extra['timedMode'] is bool
                      ? extra['timedMode'] as bool
                      : true,
                  hintsEnabled: extra['hintsEnabled'] is bool
                      ? extra['hintsEnabled'] as bool
                      : false,
                  challengeId: extra['challengeId']?.toString(),
                  userPathChallengeId: extra['userPathChallengeId']?.toString(),
                  examTargetId: extra['examTargetId']?.toString(),
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
          transitionDuration: Duration(milliseconds: 300),
          child: OnboardingGate(child: DashboardScreen()),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => const CustomTransitionPage(
          transitionDuration: Duration(milliseconds: 300),
          child: ProfileScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/reports',
        pageBuilder: (context, state) {
          final period = state.uri.queryParameters['period'] == 'monthly'
              ? 'monthly'
              : 'weekly';
          return CustomTransitionPage(
            transitionDuration: const Duration(milliseconds: 300),
            child: ReportScreen(initialPeriod: period),
            transitionsBuilder: _fadeTransition,
          );
        },
      ),
      GoRoute(
        path: '/exam-dashboard',
        pageBuilder: (context, state) => const CustomTransitionPage(
          transitionDuration: Duration(milliseconds: 300),
          child: ExamModeHubScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/exam-dashboard/planning',
        pageBuilder: (context, state) => const CustomTransitionPage(
          transitionDuration: Duration(milliseconds: 300),
          child: ExamPlanningScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/exam-dashboard/subject/:targetId',
        pageBuilder: (context, state) => CustomTransitionPage(
          transitionDuration: const Duration(milliseconds: 300),
          child: ExamDashboardScreen(
            targetId: state.pathParameters['targetId'] ?? '',
          ),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/exam-dashboard/subject/:targetId/report',
        pageBuilder: (context, state) => CustomTransitionPage(
          transitionDuration: const Duration(milliseconds: 300),
          child: ExamSubjectReportScreen(
            targetId: state.pathParameters['targetId'] ?? '',
          ),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/exam-dashboard/subject/:targetId/curriculum',
        pageBuilder: (context, state) => CustomTransitionPage(
          transitionDuration: const Duration(milliseconds: 300),
          child: ExamCurriculumBreakdownScreen(
            targetId: state.pathParameters['targetId'] ?? '',
          ),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/exam-mode/setup',
        pageBuilder: (context, state) => const CustomTransitionPage(
          transitionDuration: Duration(milliseconds: 300),
          child: ExamModeSetupScreen(),
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
