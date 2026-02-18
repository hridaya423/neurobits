import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

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
  bool _quickStartEnabled = true;
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
          _defaultNumQuestions = prefs['defaultNumQuestions'] is num
              ? (prefs['defaultNumQuestions'] as num).toInt()
              : 5;
          _defaultDifficulty =
              prefs['defaultDifficulty'] as String? ?? 'Medium';
          _defaultTimePerQuestionSec = prefs['defaultTimePerQuestionSec'] is num
              ? (prefs['defaultTimePerQuestionSec'] as num).toInt()
              : 60;
          _timedModeEnabled = prefs['timedModeEnabled'] as bool? ?? false;
          _quickStartEnabled = prefs['quickStartEnabled'] as bool? ?? true;
          _allowedChallengeTypes =
              List<String>.from(prefs['allowedChallengeTypes'] ?? ['quiz']);
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
    setState(() => _loading = true);
    try {
      final prefRepo = ref.read(preferenceRepositoryProvider);
      await prefRepo.upsertMine(
        defaultNumQuestions: _defaultNumQuestions,
        defaultDifficulty: _defaultDifficulty,
        defaultTimePerQuestionSec: _defaultTimePerQuestionSec,
        timedModeEnabled: _timedModeEnabled,
        quickStartEnabled: _quickStartEnabled,
        allowedChallengeTypes: _allowedChallengeTypes,
      );
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

  Widget _buildDropdownField<T>({
    required T value,
    required String label,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? Function(T?)? validator,
  }) {
    return FormField<T>(
      initialValue: value,
      validator: validator,
      builder: (state) {
        return InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            errorText: state.errorText,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: state.value,
              items: items,
              onChanged: (selected) {
                state.didChange(selected);
                onChanged(selected);
              },
            ),
          ),
        );
      },
    );
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
            SwitchListTile(
              title: const Text('Quick Start'),
              subtitle: const Text('Start quizzes with your defaults'),
              value: _quickStartEnabled,
              onChanged: (v) => setState(() => _quickStartEnabled = v),
            ),
            _buildDropdownField<int>(
              label: 'Default Number of Questions',
              value: _defaultNumQuestions,
              items: questionCountOptions
                  .map((cnt) =>
                      DropdownMenuItem(value: cnt, child: Text('$cnt')))
                  .toList(),
              onChanged: (v) => setState(() => _defaultNumQuestions = v!),
            ),
            const SizedBox(height: 12),
            _buildDropdownField<String>(
              label: 'Default Difficulty',
              value: _defaultDifficulty,
              items: difficultyOptions
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => setState(() => _defaultDifficulty = v!),
            ),
            const SizedBox(height: 12),
            _buildDropdownField<int>(
              label: 'Time per Question (seconds)',
              value: _defaultTimePerQuestionSec,
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
