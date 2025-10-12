import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/supabase.dart';

class PersonalizationOnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const PersonalizationOnboardingScreen({
    super.key,
    required this.onComplete,
  });

  @override
  ConsumerState<PersonalizationOnboardingScreen> createState() =>
      _PersonalizationOnboardingScreenState();
}

class _PersonalizationOnboardingScreenState
    extends ConsumerState<PersonalizationOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  String _learningGoal = '';
  String _experienceLevel = '';
  String _learningStyle = '';
  int _timeCommitment = 15;
  final List<String> _interestedTopics = [];
  final List<String> _preferredQuestionTypes = ['quiz'];
  final String _motivation = '';

  final List<String> _learningGoals = [
    'Career Change',
    'Skill Enhancement',
    'Academic Support',
    'Certification Prep',
    'Hobby Learning',
    'Interview Preparation',
  ];

  final List<String> _experienceLevels = [
    'Complete Beginner',
    'Some Experience',
    'Intermediate',
    'Advanced',
    'Expert',
  ];

  final List<String> _learningStyles = [
    'Visual Learner',
    'Hands-on Practice',
    'Reading & Theory',
    'Mixed Approach',
  ];

  final List<String> _availableTopics = [
    'Programming',
    'Mathematics',
    'Science',
    'Languages',
    'History',
    'Business',
    'Art & Design',
    'Technology',
  ];

  final List<String> _questionTypeOptions = [
    'quiz',
    'code',
    'input',
    'fill_blank',
  ];

  final Map<String, String> _questionTypeLabels = {
    'quiz': 'Multiple Choice',
    'code': 'Coding Challenges',
    'input': 'Short Answers',
    'fill_blank': 'Fill in Blanks',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalize Your Experience'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: LinearProgressIndicator(
              value: (_currentPage + 1) / 5,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                _buildLearningGoalPage(),
                _buildExperiencePage(),
                _buildLearningStylePage(),
                _buildTopicInterestsPage(),
                _buildPreferencesPage(),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_currentPage > 0)
                  TextButton(
                    onPressed: () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.ease,
                    ),
                    child: const Text('Back'),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleNext,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_currentPage == 4 ? 'Complete Setup' : 'Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningGoalPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What\'s your learning goal?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us recommend the right content for you',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              itemCount: _learningGoals.length,
              itemBuilder: (context, index) {
                final goal = _learningGoals[index];
                final isSelected = _learningGoal == goal;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _learningGoal = goal),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getGoalIcon(goal),
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                goal,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperiencePage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What\'s your experience level?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll adjust the difficulty to match your level',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              itemCount: _experienceLevels.length,
              itemBuilder: (context, index) {
                final level = _experienceLevels[index];
                final isSelected = _experienceLevel == level;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _experienceLevel = level),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade300,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                level,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningStylePage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How do you learn best?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll recommend content that matches your style',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 32),
          Text(
            'Learning Style',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          ...(_learningStyles.map((style) {
            final isSelected = _learningStyle == style;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _learningStyle = style),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getStyleIcon(style),
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Text(style)),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList()),
          const SizedBox(height: 32),
          Text(
            'Time Commitment',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          Text('$_timeCommitment minutes per session'),
          Slider(
            value: _timeCommitment.toDouble(),
            min: 5,
            max: 60,
            divisions: 11,
            onChanged: (value) =>
                setState(() => _timeCommitment = value.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicInterestsPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What topics interest you?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select all that apply - we\'ll recommend related content',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _availableTopics.length,
              itemBuilder: (context, index) {
                final topic = _availableTopics[index];
                final isSelected = _interestedTopics.contains(topic);

                return Material(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _interestedTopics.remove(topic);
                        } else {
                          _interestedTopics.add(topic);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getTopicIcon(topic),
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              topic,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question Preferences',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your preferred question types',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 32),
          ..._questionTypeOptions.map((type) {
            final isSelected = _preferredQuestionTypes.contains(type);
            final label = _questionTypeLabels[type] ?? type;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        if (_preferredQuestionTypes.length > 1) {
                          _preferredQuestionTypes.remove(type);
                        }
                      } else {
                        _preferredQuestionTypes.add(type);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getQuestionTypeIcon(type),
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Text(label)),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  IconData _getGoalIcon(String goal) {
    switch (goal) {
      case 'Career Change':
        return Icons.work;
      case 'Skill Enhancement':
        return Icons.trending_up;
      case 'Academic Support':
        return Icons.school;
      case 'Certification Prep':
        return Icons.verified;
      case 'Hobby Learning':
        return Icons.favorite;
      case 'Interview Preparation':
        return Icons.quiz;
      default:
        return Icons.star;
    }
  }

  IconData _getStyleIcon(String style) {
    switch (style) {
      case 'Visual Learner':
        return Icons.visibility;
      case 'Hands-on Practice':
        return Icons.build;
      case 'Reading & Theory':
        return Icons.menu_book;
      case 'Mixed Approach':
        return Icons.apps;
      default:
        return Icons.lightbulb;
    }
  }

  IconData _getTopicIcon(String topic) {
    switch (topic) {
      case 'Programming':
        return Icons.code;
      case 'Mathematics':
        return Icons.calculate;
      case 'Science':
        return Icons.science;
      case 'Languages':
        return Icons.language;
      case 'History':
        return Icons.history_edu;
      case 'Business':
        return Icons.business;
      case 'Art & Design':
        return Icons.palette;
      case 'Technology':
        return Icons.computer;
      default:
        return Icons.topic;
    }
  }

  IconData _getQuestionTypeIcon(String type) {
    switch (type) {
      case 'quiz':
        return Icons.quiz;
      case 'code':
        return Icons.code;
      case 'input':
        return Icons.edit;
      case 'fill_blank':
        return Icons.space_bar;
      default:
        return Icons.help;
    }
  }

  void _handleNext() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) throw Exception('User not found');

      await SupabaseService.client.from('user_quiz_preferences').upsert({
        'user_id': user.id,
        'learning_goal': _learningGoal,
        'experience_level': _experienceLevel,
        'learning_style': _learningStyle,
        'time_commitment_minutes': _timeCommitment,
        'interested_topics': _interestedTopics,
        'preferred_question_types': _preferredQuestionTypes,
        'updated_at': DateTime.now().toIso8601String(),
      });

      await _createInitialPerformanceData(user.id);

      widget.onComplete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving preferences: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createInitialPerformanceData(String userId) async {
    final baseAccuracy = _getInitialAccuracy();

    for (final topic in _interestedTopics) {
      final existingTopic = await SupabaseService.client
          .from('topics')
          .select('id')
          .eq('name', topic)
          .maybeSingle();

      String topicId;
      if (existingTopic != null) {
        topicId = existingTopic['id'] as String;
      } else {
        final newTopic = await SupabaseService.client
            .from('topics')
            .insert({'name': topic})
            .select('id')
            .single();
        topicId = newTopic['id'] as String;
      }

      await SupabaseService.client.from('user_topic_stats').upsert({
        'user_id': userId,
        'topic_id': topicId,
        'attempts': 1,
        'correct': (baseAccuracy * 5).round(),
        'total': 5,
        'avg_accuracy': baseAccuracy,
        'last_attempted': DateTime.now().toIso8601String(),
      });
    }
  }

  double _getInitialAccuracy() {
    switch (_experienceLevel) {
      case 'Complete Beginner':
        return 0.4;
      case 'Some Experience':
        return 0.6;
      case 'Intermediate':
        return 0.75;
      case 'Advanced':
        return 0.85;
      case 'Expert':
        return 0.9;
      default:
        return 0.6;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
