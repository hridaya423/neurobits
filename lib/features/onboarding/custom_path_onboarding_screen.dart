import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../services/ai_service.dart';
import '../../core/learning_path_providers.dart';

class CustomPathOnboardingScreen extends ConsumerStatefulWidget {
  const CustomPathOnboardingScreen({super.key});

  @override
  ConsumerState<CustomPathOnboardingScreen> createState() =>
      _CustomPathOnboardingScreenState();
}

class _CustomPathOnboardingScreenState
    extends ConsumerState<CustomPathOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  String _duration = '7';
  String _dailyMinutes = '10';
  String _level = 'Intermediate';
  bool _loading = false;
  String? _error;

  final List<String> durations = ['7', '14', '30'];
  final List<String> durationLabels = ['1 week', '2 weeks', '1 month'];
  final List<String> dailyMinutesOptions = ['10', '20', '30', '60'];
  final List<String> dailyMinutesLabels = [
    '10 min',
    '20 min',
    '30 min',
    '1 hour'
  ];
  final List<String> levels = ['Beginner', 'Intermediate', 'Advanced'];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _generatePath() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final user = ref.read(userProvider).value;
    if (user == null) {
      setState(() {
        _error = 'User not found.';
        _loading = false;
      });
      return;
    }

    try {
      final topic = _topicController.text.trim();
      final durationDays = int.parse(_duration);
      final dailyMinutes = int.parse(_dailyMinutes);
      final level = _level;

      final aiResponse = await AIService.generateLearningPath(
        topic,
        level,
        durationDays,
        dailyMinutes,
      );

      final List<dynamic> path = aiResponse['path'] ?? [];
      final String? pathDescription =
          aiResponse['path_description']?.toString();
      if (path.isEmpty) {
        throw Exception('AI did not return a valid learning path.');
      }

      final aiPathData = {
        'path': path,
        'path_description': pathDescription,
        'metadata': {},
      };
      final aiPathJsonString = json.encode(aiPathData);

      final pathRepo = ref.read(pathRepositoryProvider);
      final userPathId = await pathRepo.createCustomPathFromAi(
        topic: topic,
        level: level,
        durationDays: durationDays,
        dailyMinutes: dailyMinutes,
        aiPathJson: aiPathJsonString,
        pathDescription: pathDescription,
      );

      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.completeOnboarding();

      ref.invalidate(activeLearningPathProvider);
      final activePath = await ref.read(activeLearningPathProvider.future);
      if (activePath != null) {
        ref.read(userPathProvider.notifier).state = activePath;
      }

      ref.invalidate(userStatsProvider);
      ref.invalidate(userProvider);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e, s) {
      debugPrint('Error generating custom path: $e\n$s');
      setState(() {
        _error = 'Failed to generate path: ${e.toString()}';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _buildDropdownField({
    required String value,
    required String label,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return FormField<String>(
      initialValue: value,
      validator: validator,
      builder: (state) {
        return InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            errorText: state.errorText,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
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
    return Scaffold(
      appBar: AppBar(title: const Text('Custom Learning Path')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              TextFormField(
                controller: _topicController,
                decoration: const InputDecoration(
                    labelText: 'What do you want to learn?'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please enter a topic'
                    : null,
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                value: _duration,
                label: 'How long?',
                items: List.generate(
                  durations.length,
                  (i) => DropdownMenuItem(
                      value: durations[i], child: Text(durationLabels[i])),
                ),
                onChanged: (v) => setState(() => _duration = v!),
                validator: (v) => v == null ? 'Select duration' : null,
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                value: _dailyMinutes,
                label: 'How much time per day?',
                items: List.generate(
                  dailyMinutesOptions.length,
                  (i) => DropdownMenuItem(
                      value: dailyMinutesOptions[i],
                      child: Text(dailyMinutesLabels[i])),
                ),
                onChanged: (v) => setState(() => _dailyMinutes = v!),
                validator: (v) => v == null ? 'Select daily time' : null,
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                value: _level,
                label: 'Select level',
                items: levels
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => _level = v!),
                validator: (v) => v == null ? 'Select level' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _generatePath,
                  child: _loading
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Text('Generate Custom Path'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
