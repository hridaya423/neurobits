import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neurobits/features/onboarding/streak_onboarding_screen.dart';
import 'package:neurobits/services/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:neurobits/features/onboarding/streak_notification_service.dart';
import 'learning_path_onboarding_screen.dart';
import 'quiz_preferences_onboarding_screen.dart';

final streakGoalProvider = StateProvider<int?>((ref) => null);
final onboardingCompleteProvider = StateProvider<bool>((ref) => false);
Future<void> syncOnboardingStatusFromBackend(WidgetRef ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;
  try {
    final userData = await SupabaseService.client
        .from('users')
        .select('streak_goal, onboarding_complete, adaptive_difficulty')
        .eq('id', user.id)
        .maybeSingle();
    final streakGoal = userData?['streak_goal'] as int?;
    final onboardingComplete = userData?['onboarding_complete'] == true;
    final adaptiveDifficulty = userData?['adaptive_difficulty'] == true;
    if (ref.read(streakGoalProvider) != streakGoal) {
      ref.read(streakGoalProvider.notifier).state = streakGoal;
    }
    if (ref.read(onboardingCompleteProvider) != onboardingComplete) {
      ref.read(onboardingCompleteProvider.notifier).state = onboardingComplete;
    }
  } catch (e) {
    print('Error syncing onboarding status: $e');
  }
}

class OnboardingGate extends ConsumerStatefulWidget {
  final Widget child;
  const OnboardingGate({Key? key, required this.child}) : super(key: key);
  @override
  ConsumerState<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<OnboardingGate> {
  bool _isCheckingOnboarding = false;
  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    if (_isCheckingOnboarding) return;
    _isCheckingOnboarding = true;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final userData = await SupabaseService.client
          .from('users')
          .select('streak_goal, onboarding_complete, adaptive_difficulty')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      final streakGoal = userData?['streak_goal'] as int?;
      final onboardingComplete = userData?['onboarding_complete'] == true;
      final adaptiveDifficulty = userData?['adaptive_difficulty'] == true;
      if (ref.read(streakGoalProvider) != streakGoal) {
        ref.read(streakGoalProvider.notifier).state = streakGoal;
      }
      if (ref.read(onboardingCompleteProvider) != onboardingComplete) {
        ref.read(onboardingCompleteProvider.notifier).state =
            onboardingComplete;
      }
      final bool shouldShowOnboarding =
          user != null && (!onboardingComplete || streakGoal == null);
      if (shouldShowOnboarding && mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => StreakOnboardingScreen(
            onComplete: (goal, adaptiveDifficulty) async {
              if (!mounted) return;
              final currentUserId =
                  Supabase.instance.client.auth.currentUser?.id;
              if (currentUserId == null) {
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
                return;
              }
              try {
                await SupabaseService.client.from('users').update({
                  'streak_goal': goal,
                  'adaptive_difficulty': adaptiveDifficulty,
                }).eq('id', currentUserId);
                if (!mounted) return;
                ref.read(streakGoalProvider.notifier).state = goal;
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
                if (!mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => QuizPreferencesOnboardingScreen(
                      onComplete: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                );
                if (!mounted) return;
                final bool? pathSelected = await showDialog<bool?>(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext2) => LearningPathOnboardingScreen(),
                );
                debugPrint(
                    "LearningPathOnboardingScreen completed with result: $pathSelected");
                await syncOnboardingStatusFromBackend(ref);
              } catch (e) {
                debugPrint(
                    "[OnboardingGate] Error saving onboarding step 1 or showing step 2: $e");
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
              }
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('Error checking onboarding status: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingOnboarding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
