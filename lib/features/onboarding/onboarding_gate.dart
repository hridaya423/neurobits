import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neurobits/features/onboarding/streak_onboarding_screen.dart';
import 'package:neurobits/core/providers.dart';
import 'learning_path_onboarding_screen.dart';
import 'quiz_preferences_onboarding_screen.dart';
import 'personalization_onboarding_screen.dart';

final onboardingCompleteProvider = StateProvider<bool>((ref) => false);

Future<void> syncOnboardingStatusFromBackend(WidgetRef ref) async {
  try {
    final userRepo = ref.read(userRepositoryProvider);
    final userData = await userRepo.getMe();
    if (userData == null) return;

    final onboardingComplete = userData['onboardingComplete'] == true;
    final adaptiveDifficulty = userData['adaptiveDifficultyEnabled'] == true;
    ref.read(adaptiveDifficultyProvider.notifier).state = adaptiveDifficulty;
    if (ref.read(onboardingCompleteProvider) != onboardingComplete) {
      ref.read(onboardingCompleteProvider.notifier).state = onboardingComplete;
    }
  } catch (e) {
    debugPrint('[OnboardingGate] Error syncing onboarding status: $e');
  }
}

class OnboardingGate extends ConsumerStatefulWidget {
  final Widget child;
  const OnboardingGate({super.key, required this.child});
  @override
  ConsumerState<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<OnboardingGate> {
  bool _isCheckingOnboarding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnboardingStatus();
    });
  }

  Future<void> _checkOnboardingStatus() async {
    if (_isCheckingOnboarding) return;
    _isCheckingOnboarding = true;
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final userData = await userRepo.getMe();
      if (userData == null) return;
      if (!mounted) return;

      final onboardingComplete = userData['onboardingComplete'] == true;
      final adaptiveDifficulty = userData['adaptiveDifficultyEnabled'] == true;
      ref.read(adaptiveDifficultyProvider.notifier).state = adaptiveDifficulty;
      if (ref.read(onboardingCompleteProvider) != onboardingComplete) {
        ref.read(onboardingCompleteProvider.notifier).state =
            onboardingComplete;
      }

      final bool shouldShowOnboarding = !onboardingComplete;

      if (shouldShowOnboarding && mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => StreakOnboardingScreen(
            onComplete: (goal, adaptiveDifficulty) async {
              if (!mounted) return;
              try {
                await userRepo.updateProfile(streakGoal: goal);
                await userRepo.updateSettings(
                  adaptiveDifficultyEnabled: adaptiveDifficulty,
                );
                await userRepo.completeOnboarding();

                if (!mounted) return;
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
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => PersonalizationOnboardingScreen(
                      onComplete: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                );

                if (!mounted) return;
                await syncOnboardingStatusFromBackend(ref);
                await showDialog<bool?>(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext2) => LearningPathOnboardingScreen(),
                );
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
      debugPrint('[OnboardingGate] Error checking onboarding status: $e');
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
