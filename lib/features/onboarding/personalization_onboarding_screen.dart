import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

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
  final TextEditingController _examSearchController = TextEditingController();
  int _currentPage = 0;
  bool _isLoading = false;
  bool _isResolvingExam = false;

  String _learningGoal = '';
  String _experienceLevel = '';
  String _learningStyle = '';
  int _timeCommitment = 15;
  final List<String> _interestedTopics = [];
  final List<String> _preferredQuestionTypes = ['quiz'];
  bool _examFocusEnabled = false;
  String _examIntentQuery = '';
  List<Map<String, dynamic>> _examMatches = [];
  List<Map<String, dynamic>> _examSuggestions = [];
  Map<String, dynamic>? _selectedExamEntry;
  int _examYearGroup = 10;
  DateTime? _examMockDate;
  DateTime? _examDate;
  int _examDailyStudyMinutes = 45;
  int _examWeeklySessionsTarget = 4;

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
    'Data Science',
    'AI & Machine Learning',
    'Web Development',
    'Mobile Development',
    'Mathematics',
    'Statistics',
    'Physics',
    'Biology',
    'Chemistry',
    'Psychology',
    'History',
    'Economics',
    'Business',
    'Finance',
    'Marketing',
    'Product Management',
    'Design & UX',
    'Languages',
    'Writing',
    'Technology',
    'Engineering',
  ];

  final Map<String, List<String>> _goalTopicBias = {
    'Career Change': [
      'Programming',
      'Data Science',
      'Web Development',
      'Product Management',
      'Design & UX',
      'Business',
    ],
    'Skill Enhancement': [
      'Programming',
      'AI & Machine Learning',
      'Data Science',
      'Technology',
      'Engineering',
    ],
    'Academic Support': [
      'Mathematics',
      'Statistics',
      'Physics',
      'Biology',
      'Chemistry',
      'Writing',
    ],
    'Certification Prep': [
      'Technology',
      'Programming',
      'Business',
      'Finance',
    ],
    'Hobby Learning': [
      'Languages',
      'History',
      'Writing',
      'Design & UX',
      'Psychology',
    ],
    'Interview Preparation': [
      'Programming',
      'Data Science',
      'Product Management',
      'Business',
      'Statistics',
    ],
  };

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
  void initState() {
    super.initState();
    _loadExamSuggestions();
  }

  Future<void> _loadExamSuggestions() async {
    try {
      final repo = ref.read(examRepositoryProvider);
      final items = await repo.listCatalog(limit: 8);
      if (!mounted) return;
      setState(() {
        _examSuggestions = items;
      });
    } catch (_) {}
  }

  Future<void> _resolveExamIntent() async {
    final query = _examSearchController.text.trim();
    setState(() {
      _examIntentQuery = query;
      _isResolvingExam = true;
    });

    if (query.isEmpty) {
      setState(() {
        _examMatches = [];
        _isResolvingExam = false;
      });
      return;
    }

    try {
      final repo = ref.read(examRepositoryProvider);
      final matches = await repo.resolveIntent(query, limit: 6);
      if (!mounted) return;
      setState(() {
        _examMatches = matches;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not resolve exam yet: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingExam = false;
        });
      }
    }
  }

  void _selectExamEntry(Map<String, dynamic> entry) {
    final maybeYear = entry['year'];
    final normalizedYear = maybeYear is num ? maybeYear.toInt() : null;
    setState(() {
      _selectedExamEntry = entry;
      _examFocusEnabled = true;
      if (normalizedYear != null &&
          normalizedYear >= 7 &&
          normalizedYear <= 13) {
        _examYearGroup = normalizedYear;
      }
    });
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Not set';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<DateTime?> _pickDate(DateTime? initialDate) async {
    final now = DateTime.now();
    return await showDatePicker(
      context: context,
      initialDate: initialDate ?? now.add(const Duration(days: 30)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
    );
  }

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
              value: (_currentPage + 1) / 6,
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
                _buildExamSpecializationPage(),
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
                      : Text(_currentPage == 5 ? 'Complete Setup' : 'Next'),
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
    final rankedTopics = _rankedTopics();
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
              itemCount: rankedTopics.length,
              itemBuilder: (context, index) {
                final topic = rankedTopics[index];
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

  Map<String, dynamic> _toExamEntry(Map<String, dynamic> row) {
    final raw = row['entry'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return row;
  }

  String _examLabel(Map<String, dynamic> entry) {
    final title = entry['displayName']?.toString().trim() ?? '';
    if (title.isNotEmpty) return title;
    final family = entry['examFamily']?.toString() ?? 'Exam';
    final board = entry['board']?.toString() ?? '';
    final subject = entry['subject']?.toString() ?? '';
    return [family, board, subject]
        .where((part) => part.trim().isNotEmpty)
        .join(' - ');
  }

  Map<String, dynamic> _buildCustomExamTarget(String query) {
    final trimmed = query.trim();
    return {
      'slug': 'custom-${DateTime.now().millisecondsSinceEpoch}',
      'displayName': trimmed,
      'countryCode': 'INTL',
      'countryName': 'International',
      'examFamily': 'custom',
      'board': 'Custom',
      'level': 'General',
      'subject': trimmed,
    };
  }

  Widget _buildExamSpecializationPage() {
    final options = _examMatches.isNotEmpty
        ? _examMatches.map(_toExamEntry).toList()
        : _examSuggestions;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exam Specialization (Optional)',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick an exam target to make your practice board- and paper-style aware.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable exam-focused prep'),
            value: _examFocusEnabled,
            onChanged: (value) {
              setState(() {
                _examFocusEnabled = value;
                if (!value) {
                  _selectedExamEntry = null;
                }
              });
            },
          ),
          if (_examFocusEnabled) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _examSearchController,
                    decoration: const InputDecoration(
                      labelText: 'Search exam (e.g. GCSE Maths AQA)',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _resolveExamIntent(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _isResolvingExam ? null : _resolveExamIntent,
                  child: _isResolvingExam
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Find'),
                ),
              ],
            ),
            if (_selectedExamEntry != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                child: Text(
                  'Selected: ${_examLabel(_selectedExamEntry!)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exam planning basics',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Set your year, key dates, and realistic daily capacity so we can build a better revision plan from day one.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Current year group',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [9, 10, 11, 12, 13].map((year) {
                        return ChoiceChip(
                          selected: _examYearGroup == year,
                          label: Text('Year $year'),
                          onSelected: (_) {
                            setState(() {
                              _examYearGroup = year;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await _pickDate(_examMockDate);
                              if (picked == null) return;
                              setState(() {
                                _examMockDate = picked;
                              });
                            },
                            icon: const Icon(Icons.event_outlined),
                            label: const Text('Set mock date'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _examMockDate == null
                              ? null
                              : () {
                                  setState(() {
                                    _examMockDate = null;
                                  });
                                },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    Text(
                      'Mocks: ${_formatDate(_examMockDate)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await _pickDate(_examDate);
                              if (picked == null) return;
                              setState(() {
                                _examDate = picked;
                              });
                            },
                            icon: const Icon(Icons.event_available_outlined),
                            label: const Text('Set exam date'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _examDate == null
                              ? null
                              : () {
                                  setState(() {
                                    _examDate = null;
                                  });
                                },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    Text(
                      'Exam: ${_formatDate(_examDate)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Daily study minutes: $_examDailyStudyMinutes',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Slider(
                      value: _examDailyStudyMinutes.toDouble(),
                      min: 10,
                      max: 180,
                      divisions: 34,
                      label: '$_examDailyStudyMinutes min/day',
                      onChanged: (value) {
                        setState(() {
                          _examDailyStudyMinutes = value.round();
                        });
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Weekly sessions target: $_examWeeklySessionsTarget',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Slider(
                      value: _examWeeklySessionsTarget.toDouble(),
                      min: 2,
                      max: 14,
                      divisions: 12,
                      label: '$_examWeeklySessionsTarget sessions',
                      onChanged: (value) {
                        setState(() {
                          _examWeeklySessionsTarget = value.round();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              options.isEmpty ? 'No exam matches yet.' : 'Suggested exams',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (options.isEmpty && _examIntentQuery.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  _selectExamEntry(_buildCustomExamTarget(_examIntentQuery));
                },
                icon: const Icon(Icons.edit_note_rounded),
                label: Text('Use "${_examIntentQuery.trim()}" as custom'),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final entry = options[index];
                  final isSelected = _selectedExamEntry != null &&
                      _selectedExamEntry!['slug']?.toString() ==
                          entry['slug']?.toString();
                  final subtitle = [
                    entry['countryName']?.toString() ?? '',
                    entry['examFamily']?.toString() ?? '',
                    entry['board']?.toString() ?? '',
                    entry['subject']?.toString() ?? '',
                  ].where((part) => part.trim().isNotEmpty).join(' • ');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _selectExamEntry(entry),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _examLabel(entry),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey.shade600),
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

  List<String> _rankedTopics() {
    final selected = _interestedTopics.toList();
    final bias = _learningGoal.isEmpty
        ? <String>[]
        : (_goalTopicBias[_learningGoal] ?? <String>[]);
    final ordered = <String>[];

    for (final topic in selected) {
      if (!ordered.contains(topic)) ordered.add(topic);
    }

    for (final topic in bias) {
      if (_availableTopics.contains(topic) && !ordered.contains(topic)) {
        ordered.add(topic);
      }
    }

    for (final topic in _availableTopics) {
      if (!ordered.contains(topic)) ordered.add(topic);
    }

    return ordered;
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
    if (_currentPage == 4 && _examFocusEnabled && _selectedExamEntry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an exam or disable exam focus.')),
      );
      return;
    }

    if (_currentPage == 4 &&
        _examFocusEnabled &&
        _examMockDate != null &&
        _examDate != null &&
        _examMockDate!.isAfter(_examDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Mock date should be on or before the final exam date.'),
        ),
      );
      return;
    }

    if (_currentPage < 5) {
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
      final prefRepo = ref.read(preferenceRepositoryProvider);
      await prefRepo.upsertMine(
        learningGoal: _learningGoal,
        experienceLevel: _experienceLevel,
        learningStyle: _learningStyle,
        timeCommitmentMinutes: _timeCommitment,
        interestedTopics: _interestedTopics,
        preferredQuestionTypes: _preferredQuestionTypes,
      );
      ref.invalidate(userPreferencesProvider);
      ref.invalidate(recommendationsCacheProvider);
      ref.invalidate(practiceRecommendationsProvider);
      ref.invalidate(enrichedPracticeProvider);
      ref.invalidate(suggestedNewTopicsWithReasonsProvider);

      if (_examFocusEnabled && _selectedExamEntry != null) {
        final examRepo = ref.read(examRepositoryProvider);
        final selected = _selectedExamEntry!;
        await examRepo.upsertMyTarget(
          countryCode: selected['countryCode']?.toString() ?? 'INTL',
          countryName: selected['countryName']?.toString() ?? 'International',
          examFamily: selected['examFamily']?.toString() ?? 'exam',
          board: selected['board']?.toString() ?? 'General',
          level: selected['level']?.toString() ?? 'General',
          subject: selected['subject']?.toString() ?? 'General',
          year: _examYearGroup,
          mockDateAt: _examMockDate?.millisecondsSinceEpoch,
          examDateAt: _examDate?.millisecondsSinceEpoch,
          timetableMode: 'manual',
          weeklyStudyMinutes: _examDailyStudyMinutes * 7,
          weeklySessionsTarget: _examWeeklySessionsTarget,
          intentQuery: _examIntentQuery,
          sourceCatalogSlug: selected['slug']?.toString(),
        );
        ref.invalidate(userExamTargetProvider);
        ref.invalidate(userExamTargetsProvider);
        ref.invalidate(gcseExamHomeProvider);
        ref.invalidate(userExamDashboardProvider);
      }

      widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preferences: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _examSearchController.dispose();
    super.dispose();
  }
}
