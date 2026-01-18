import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../services/supabase.dart';

class QuizPreferencesOnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  const QuizPreferencesOnboardingScreen({super.key, required this.onComplete});
  @override
  ConsumerState<QuizPreferencesOnboardingScreen> createState() =>
      _QuizPreferencesOnboardingScreenState();
}

class _QuizPreferencesOnboardingScreenState
    extends ConsumerState<QuizPreferencesOnboardingScreen> {
  bool _loading = false;
  bool _prefsLoading = true;
  int _defaultNumQuestions = 5;
  String _defaultDifficulty = 'Medium';
  int _defaultTimePerQuestionSec = 60;
  bool _timedModeEnabled = false;
  List<String> _allowedChallengeTypes = ['quiz'];
  final List<int> questionCountOptions = [5, 10, 15];
  final List<String> difficultyOptions = ['Easy', 'Medium', 'Hard'];
  final List<int> timePerQuestionOptions = [30, 60, 90];
  final List<String> challengeTypeOptions = [
    'quiz',
    'code',
    'input',
    'fill_blank'
  ];

  final Map<String, String> challengeTypeLabels = {
    'quiz': 'Multiple Choice (MCQ)',
    'code': 'Code Challenges',
    'input': 'Input Questions',
    'fill_blank': 'Fill in the Blank'
  };
  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await ref.read(userPreferencesProvider.future);
      if (prefs != null) {
        setState(() {
          _defaultNumQuestions = prefs['default_num_questions'] as int? ?? 5;
          _defaultDifficulty =
              prefs['default_difficulty'] as String? ?? 'Medium';
          _defaultTimePerQuestionSec =
              prefs['default_time_per_question_sec'] as int? ?? 60;
          _timedModeEnabled = prefs['timed_mode_enabled'] as bool? ?? false;
          _allowedChallengeTypes =
              List<String>.from(prefs['allowed_challenge_types'] ?? ['quiz']);
        });
      }
    } catch (e) {
      debugPrint('Error loading quiz preferences during onboarding: $e');
    } finally {
      if (mounted) {
        setState(() => _prefsLoading = false);
      }
    }
  }

  Future<void> _savePreferences() async {
    final user = ref.read(userProvider).value;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      await SupabaseService.client.from('user_quiz_preferences').upsert({
        'user_id': user['id'],
        'default_num_questions': _defaultNumQuestions,
        'default_difficulty': _defaultDifficulty,
        'default_time_per_question_sec': _defaultTimePerQuestionSec,
        'timed_mode_enabled': _timedModeEnabled,
        'allowed_challenge_types': _allowedChallengeTypes,
      }, onConflict: 'user_id');
      ref.refresh(userPreferencesProvider);
      widget.onComplete();
    } catch (e) {
      debugPrint('Error saving quiz preferences during onboarding: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving defaults: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_prefsLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Your Quiz Defaults'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          children: [
            Text(
              'Configure your preferred settings for quick quizzes.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Timed Mode'),
              subtitle: const Text('Enable timed mode by default'),
              value: _timedModeEnabled,
              onChanged: (v) => setState(() => _timedModeEnabled = v),
            ),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                  labelText: 'Default Number of Questions'),
              initialValue: _defaultNumQuestions,
              items: questionCountOptions
                  .map((cnt) =>
                      DropdownMenuItem(value: cnt, child: Text('$cnt')))
                  .toList(),
              onChanged: (v) => setState(() => _defaultNumQuestions = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration:
                  const InputDecoration(labelText: 'Default Difficulty'),
              initialValue: _defaultDifficulty,
              items: difficultyOptions
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => setState(() => _defaultDifficulty = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                  labelText: 'Time per Question (seconds)'),
              initialValue: _defaultTimePerQuestionSec,
              items: timePerQuestionOptions
                  .map((t) => DropdownMenuItem(value: t, child: Text('$t sec')))
                  .toList(),
              onChanged: (v) => setState(() => _defaultTimePerQuestionSec = v!),
            ),
            const SizedBox(height: 12),
            const Text('Allowed Challenge Types',
                style: TextStyle(fontSize: 16)),
            Wrap(
              spacing: 8,
              children: challengeTypeOptions.map((type) {
                final selected = _allowedChallengeTypes.contains(type);
                return FilterChip(
                  label: Text(challengeTypeLabels[type] ?? type),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _allowedChallengeTypes.add(type);
                      } else {
                        if (_allowedChallengeTypes.length > 1) {
                          _allowedChallengeTypes.remove(type);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Must select at least one challenge type.')));
                        }
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _savePreferences,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
