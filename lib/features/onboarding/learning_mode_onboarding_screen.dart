import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neurobits/core/providers.dart';
import 'package:neurobits/core/learning_path_providers.dart';
import 'package:neurobits/features/onboarding/learning_path_onboarding_screen.dart';

class LearningModeOnboardingScreen extends ConsumerWidget {
  const LearningModeOnboardingScreen({super.key});

  Future<void> _selectFreeMode(BuildContext context, WidgetRef ref) async {
    try {
      ref.read(userPathProvider.notifier).state = null;
      final pathRepo = ref.read(pathRepositoryProvider);
      await pathRepo.selectFreeMode();
      ref.read(userPathProvider.notifier).state = null;
      ref.invalidate(activeLearningPathProvider);
      ref.invalidate(userPathDataProvider);
      await ref.refresh(activeLearningPathProvider.future);
      ref.read(userPathProvider.notifier).state = null;
      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.completeOnboarding();
      if (context.mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set free mode: $e')),
        );
      }
    }
  }

  Future<void> _selectLearningPlan(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const LearningPathOnboardingScreen(),
      ),
    );
    if (context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose your learning style'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How do you want to learn?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick a guided plan or explore freely. You can switch anytime.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 24),
              _ModeCard(
                title: 'Guided Learning Plan',
                subtitle:
                    'Follow a structured path with daily challenges and milestones.',
                icon: Icons.route,
                onTap: () => _selectLearningPlan(context, ref),
              ),
              const SizedBox(height: 16),
              _ModeCard(
                title: 'Free Mode',
                subtitle:
                    'Practice any topic at your own pace without a fixed plan.',
                icon: Icons.explore_outlined,
                onTap: () => _selectFreeMode(context, ref),
              ),
              const Spacer(),
              Text(
                'You can always update this later in your profile.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.withOpacity(0.15),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
