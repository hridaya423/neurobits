import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
class StreakOnboardingScreen extends ConsumerWidget {
  final void Function(int streakGoal, bool adaptiveDifficulty) onComplete;
  const StreakOnboardingScreen({Key? key, required this.onComplete}) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGoal = ref.watch(_selectedGoalProvider);
    final adaptiveDifficulty = ref.watch(adaptiveDifficultyProvider);
    final List<int> streakGoals = [3, 7, 14, 30];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Your Streak Goal'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How many days in a row do you want to challenge yourself?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...streakGoals.map((goal) => RadioListTile<int>(
                  value: goal,
                  groupValue: selectedGoal,
                  onChanged: (val) {
                    ref.read(_selectedGoalProvider.notifier).state = val;
                  },
                  title: Text('$goal-day streak'),
                )),
            const SizedBox(height: 28),
            SwitchListTile.adaptive(
              title: const Text('Enable Adaptive Difficulty'),
              subtitle: const Text('Let the app automatically adjust question difficulty based on your performance.'),
              value: adaptiveDifficulty,
              onChanged: (val) => ref.read(adaptiveDifficultyProvider.notifier).state = val,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selectedGoal == null
                    ? null
                    : () => onComplete(selectedGoal!, adaptiveDifficulty),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
final _selectedGoalProvider = StateProvider<int?>((ref) => null);
final adaptiveDifficultyProvider = StateProvider<bool>((ref) => true);