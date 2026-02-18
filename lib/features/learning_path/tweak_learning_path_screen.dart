import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neurobits/services/convex_client_service.dart';
import '../../core/learning_path_providers.dart';
import '../../core/providers.dart';
import 'package:neurobits/services/ai_service.dart';

class TweakLearningPathScreen extends ConsumerStatefulWidget {
  const TweakLearningPathScreen({super.key});
  @override
  ConsumerState<TweakLearningPathScreen> createState() =>
      _TweakLearningPathScreenState();
}

class _TweakLearningPathScreenState
    extends ConsumerState<TweakLearningPathScreen> {
  final _formKey = GlobalKey<FormState>();
  late int _durationDays;
  late int _dailyMinutes;
  late String _level;
  String? _emphasisTopic;
  double _emphasisWeight = 0.0;
  late double _threshold;
  bool _loading = false;
  Map<String, dynamic>? _userPath;

  @override
  void initState() {
    super.initState();
    final userPath = ref.read(userPathProvider);
    _userPath = userPath;
    if (userPath != null) {
      _durationDays = userPath['duration_days'] is num
          ? (userPath['duration_days'] as num).toInt()
          : 7;
      _dailyMinutes = userPath['daily_minutes'] is num
          ? (userPath['daily_minutes'] as num).toInt()
          : 10;
      _level = userPath['level'] as String? ?? 'Intermediate';
      final Map<String, dynamic>? thresholdMeta =
          userPath['metadata'] as Map<String, dynamic>?;
      _threshold = 0.75;
      if (thresholdMeta != null && thresholdMeta['threshold'] != null) {
        final threshold = thresholdMeta['threshold'];
        if (threshold is num) {
          _threshold = threshold.toDouble();
        }
      }
      final metadata = thresholdMeta;
      if (metadata != null && metadata.containsKey('emphasis')) {
        final Map<String, dynamic>? emphasis =
            metadata['emphasis'] as Map<String, dynamic>?;
        if (emphasis != null && emphasis.isNotEmpty) {
          _emphasisTopic = emphasis.keys.first;
          final weight = emphasis[_emphasisTopic];
          if (weight is num) {
            _emphasisWeight = weight.toDouble();
          }
        }
      }
    } else {
      _durationDays = 7;
      _dailyMinutes = 10;
      _level = 'Intermediate';
      _threshold = 0.75;
    }
  }

  Future<void> _saveTweaks() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final userPath = ref.read(userPathProvider);
    if (userPath == null) return;
    Map<String, dynamic> metadata =
        userPath['metadata'] as Map<String, dynamic>? ?? {};
    metadata = Map<String, dynamic>.from(metadata);
    if (_emphasisTopic != null && _emphasisTopic!.isNotEmpty) {
      metadata['emphasis'] = {_emphasisTopic!: _emphasisWeight};
    } else {
      metadata.remove('emphasis');
    }
    metadata['threshold'] = _threshold;
    try {
      final pathTopic = (_emphasisTopic?.isNotEmpty ?? false)
          ? _emphasisTopic!
          : (_userPath?['name']?.toString() ??
              _userPath?['metadata']?['topic']?.toString() ??
              'General');

      final aiResponse = await AIService.generateLearningPath(
        pathTopic,
        _level,
        _durationDays,
        _dailyMinutes,
      );
      final newPathSteps = aiResponse['path'] ?? [];
      final String? pathDescription =
          aiResponse['path_description']?.toString();

      final aiPathData = <String, dynamic>{
        'path': newPathSteps,
        'path_description': pathDescription,
        'metadata': metadata,
      };
      final String aiPathJson = jsonEncode(aiPathData);
      final pathRepo = ref.read(pathRepositoryProvider);
      await pathRepo.tweakActivePathFromAi(
        durationDays: _durationDays,
        dailyMinutes: _dailyMinutes,
        aiPathJson: aiPathJson,
        pathDescription: pathDescription,
      );
      final updatedPath = {
        ...userPath,
        'duration_days': _durationDays,
        'daily_minutes': _dailyMinutes,
        'level': _level,
        'ai_path_json': aiPathJson,
        'metadata': metadata,
      };
      ref.read(userPathProvider.notifier).state = updatedPath;
      ref.invalidate(activeLearningPathProvider);
      final userPathId =
          userPath['_id']?.toString() ?? userPath['user_path_id']?.toString();
      if (userPathId != null) {
        ref.invalidate(userPathChallengesProvider(userPathId));
      }
      final refreshed = await ref.refresh(activeLearningPathProvider.future);
      if (refreshed != null) {
        ref.read(userPathProvider.notifier).state = refreshed;
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save tweaks: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildDropdownField({
    required String value,
    required String label,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return FormField<String>(
      initialValue: value,
      builder: (state) {
        return InputDecorator(
          decoration: InputDecoration(labelText: label),
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
    final userPath = ref.watch(userPathProvider);
    final topicsList = <String>[];
    if (userPath != null && isConvexList(userPath['topics'])) {
      for (var t in toList(userPath['topics'])) {
        final topicName = t['topic'] as String?;
        if (topicName != null) topicsList.add(topicName);
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Tweak Learning Path')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _buildDropdownField(
                      value: _level,
                      label: 'Difficulty',
                      items: const [
                        'Beginner',
                        'Intermediate',
                        'Advanced',
                      ]
                          .map(
                            (l) => DropdownMenuItem(value: l, child: Text(l)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _level = v!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _durationDays.toString(),
                      decoration:
                          const InputDecoration(labelText: 'Duration (days)'),
                      keyboardType: TextInputType.number,
                      onChanged: (val) =>
                          _durationDays = int.tryParse(val) ?? _durationDays,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Enter duration';
                        final num = int.tryParse(val);
                        if (num == null || num <= 0) return 'Invalid days';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _dailyMinutes.toString(),
                      decoration: const InputDecoration(
                          labelText: 'Daily time (minutes)'),
                      keyboardType: TextInputType.number,
                      onChanged: (val) =>
                          _dailyMinutes = int.tryParse(val) ?? _dailyMinutes,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Enter minutes';
                        final num = int.tryParse(val);
                        if (num == null || num <= 0) return 'Invalid minutes';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _emphasisTopic,
                      decoration: const InputDecoration(
                        labelText: 'Emphasis Topic (optional)',
                        hintText: 'Enter a topic to emphasize',
                      ),
                      onChanged: (val) => setState(() => _emphasisTopic = val),
                    ),
                    if ((_emphasisTopic?.isNotEmpty ?? false)) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Emphasis Weight (${(_emphasisWeight * 100).round()}%)',
                      ),
                      Slider(
                        value: _emphasisWeight,
                        min: 0.0,
                        max: 1.0,
                        divisions: 100,
                        label: '${(_emphasisWeight * 100).round()}%',
                        onChanged: (v) => setState(() => _emphasisWeight = v),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text('Pass Threshold (${(_threshold * 100).round()}%)'),
                    Slider(
                      value: _threshold,
                      min: 0.5,
                      max: 1.0,
                      divisions: 10,
                      label: '${(_threshold * 100).round()}%',
                      onChanged: (v) => setState(() => _threshold = v),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveTweaks,
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
