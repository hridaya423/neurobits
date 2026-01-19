import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../services/supabase.dart';
import '../../services/ai_service.dart';
import '../../core/learning_path_providers.dart';
import '../../utils/text_utils.dart';

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
      if (path.isEmpty) {
        throw Exception('AI did not return a valid learning path.');
      }

      final capitalizedTopic = TextUtils.capitalizeTitle(topic);

      final aiDescription = aiResponse['path_description'] as String? ??
          'Customized $level learning path for $capitalizedTopic';

      final existingActivePaths = await SupabaseService.client
          .from('user_learning_paths')
          .select('id')
          .eq('user_id', user['id'])
          .is_('completed_at', null);

      if (existingActivePaths.isNotEmpty) {
        final pathIdsToComplete =
            existingActivePaths.map((p) => p['id']).toList();
        await SupabaseService.client.from('user_learning_paths').update({
          'completed_at': DateTime.now().toIso8601String(),
          'is_complete': true,
        }).in_('id', pathIdsToComplete);
      }

      final pathResults =
          await SupabaseService.client.from('learning_paths').insert({
        'name': '$capitalizedTopic ($level)',
        'description': aiDescription,
        'is_active': true,
        'created_by': user['id'],
      }).select();

      if (pathResults.isEmpty) {
        throw Exception('Failed to create learning path');
      }

      final pathRes = pathResults.first;
      final pathId = pathRes['id'];

      final topicNames =
          path.map((step) => step['topic'] as String).toSet().toList();

      final topicIds = <String, String>{};
      for (final name in topicNames) {
        if (name.trim().isEmpty) continue;

        try {
          final existingTopicResults = await SupabaseService.client
              .from('topics')
              .select('id')
              .ilike('name', name.trim());

          if (existingTopicResults.isNotEmpty) {
            topicIds[name] = existingTopicResults.first['id'];
          } else {
            debugPrint("Topic '$name' not found, inserting into topics table.");
            final newTopicResults = await SupabaseService.client
                .from('topics')
                .insert({'name': name.trim()}).select('id');

            if (newTopicResults.isEmpty) {
              throw Exception('Failed to create topic: $name');
            }

            final newTopic = newTopicResults.first;
            topicIds[name] = newTopic['id'];
          }
        } catch (e, s) {
          debugPrint("Error finding or creating topic '$name': $e\n$s");
        }
      }

      for (final step in path) {
        final topicName = step['topic'] as String;
        final topicId = topicIds[topicName];

        if (topicId == null) {
          debugPrint(
              "Skipping step for topic '$topicName' as topic_id was not found/created.");
          continue;
        }

        await SupabaseService.client.from('learning_path_topics').insert({
          'path_id': pathId,
          'topic_id': topicId,
          'step_number': step['day'],
          'description': step['description'],
        });
      }

      final userPathResults =
          await SupabaseService.client.from('user_learning_paths').insert({
        'user_id': user['id'],
        'path_id': pathId,
        'current_step': 1,
        'started_at': DateTime.now().toIso8601String(),
        'duration_days': durationDays,
        'daily_minutes': dailyMinutes,
        'level': level,
        'is_custom': true,
        'ai_path_json': aiResponse,
      }).select();

      if (userPathResults.isEmpty) {
        throw Exception('Failed to create user learning path');
      }

      final userPathRes = userPathResults.first;
      final userPathId = userPathRes['id'];

      final challenges = <Map<String, dynamic>>[];
      for (final step in path) {
        final topic = step['topic']?.toString().trim() ?? 'Unknown Topic';
        final description = step['description']?.toString().trim();
        final title = step['title']?.toString().trim() ?? topic;
        final challengeType =
            step['challenge_type']?.toString().toLowerCase() ?? 'quiz';

        final finalDescription = (description == null || description.isEmpty)
            ? 'Learn about $topic - Day ${step['day']}'
            : description;

        final challengeData = {
          'user_path_id': userPathId,
          'day': step['day'],
          'topic': topic,
          'challenge_type': challengeType,
          'title': title,
          'description': finalDescription,
          'completed': false,
        };

        await SupabaseService.client
            .from('user_path_challenges')
            .insert(challengeData);

        challenges.add(challengeData);
      }

      ref.read(userPathProvider.notifier).state = {
        ...pathRes,
        'current_step': 1,
        'user_path_id': userPathId,
        'challenges': challenges,
        'total_steps': challenges.length,
      };

      await SupabaseService.client.from('users').update({
        'onboarding_complete': true,
        'streak_goal': 7,
      }).eq('id', user['id']);

      ref.invalidate(userStatsProvider);
      ref.invalidate(userProvider);
      ref.invalidate(activeLearningPathProvider); // ✅ Reload learning path data

      if (!mounted) return;
      context.go('/dashboard');
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
