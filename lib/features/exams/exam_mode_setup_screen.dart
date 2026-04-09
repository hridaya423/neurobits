import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neurobits/core/providers.dart';
import 'package:neurobits/features/exams/gcse_core_track_config.dart';

enum _ExamSetupStep { family, subjects, boards, onboarding, review }

class ExamModeSetupScreen extends ConsumerStatefulWidget {
  const ExamModeSetupScreen({super.key});

  @override
  ConsumerState<ExamModeSetupScreen> createState() =>
      _ExamModeSetupScreenState();
}

class _ExamModeSetupScreenState extends ConsumerState<ExamModeSetupScreen> {
  _ExamSetupStep _step = _ExamSetupStep.family;
  String? _selectedFamily;
  String? _selectedCountryCode;
  final Set<String> _selectedSubjects = <String>{};
  final Set<String> _lockedSubjects = <String>{};
  final Map<String, String> _selectedBoardBySubject = <String, String>{};
  final Map<String, String> _selectedTierBySubject = <String, String>{};
  final Map<String, String> _selectedCurrentGradeBySubject = <String, String>{};
  final Map<String, String> _selectedTargetGradeBySubject = <String, String>{};
  final TextEditingController _subjectQueryController = TextEditingController();
  int _selectedYearGroup = 10;
  static const String _defaultCurrentGrade = '5';
  static const String _defaultTargetGrade = '7';
  bool _saving = false;
  DateTime? _mockDate;
  DateTime? _examDate;
  int _dailyStudyMinutes = 45;
  int _weeklySessionsTarget = 4;

  static const List<_ExamSetupStep> _stepOrder = [
    _ExamSetupStep.family,
    _ExamSetupStep.subjects,
    _ExamSetupStep.boards,
    _ExamSetupStep.onboarding,
    _ExamSetupStep.review,
  ];

  @override
  void dispose() {
    _subjectQueryController.dispose();
    super.dispose();
  }

  String _stepTitle(_ExamSetupStep step) {
    switch (step) {
      case _ExamSetupStep.family:
        return 'Track';
      case _ExamSetupStep.subjects:
        return 'Subjects';
      case _ExamSetupStep.boards:
        return 'Boards';
      case _ExamSetupStep.review:
        return 'Review';
      case _ExamSetupStep.onboarding:
        return 'Onboarding';
    }
  }

  Future<DateTime?> _pickDate(DateTime? initialDate) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initialDate ?? now.add(const Duration(days: 120)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Not set';
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '${value.year}-$m-$d';
  }

  String _familyTitle(String family) {
    final key = family.trim().toLowerCase();
    switch (key) {
      case 'gcse':
        return 'GCSE';
      case 'a_level':
        return 'A-Level';
      case 'igcse':
        return 'IGCSE';
      case 'sat':
        return 'SAT';
      case 'sats':
        return 'SATs';
      case 'act':
        return 'ACT';
      case 'ap':
        return 'AP';
      case 'iit':
        return 'IIT';
      case 'medical':
        return 'Medical Entrance';
      case 'driving_theory':
        return 'Driving Theory';
      case 'certification':
        return 'Certification';
      case 'olympiad':
        return 'Olympiad';
      default:
        return family
            .split('_')
            .where((part) => part.trim().isNotEmpty)
            .map((part) =>
                '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
            .join(' ');
    }
  }

  int _currentStepIndex() => _stepOrder.indexOf(_step);

  List<Map<String, dynamic>> _rowsForFamilyAndCountry(
    List<Map<String, dynamic>> rows,
  ) {
    return rows.where((row) {
      final family = row['examFamily']?.toString().toLowerCase() ?? '';
      final country = row['countryCode']?.toString().toUpperCase() ?? '';
      if (family != 'gcse' || country != 'GB') {
        return false;
      }
      final subject = row['subject']?.toString().trim() ?? '';
      if (!isGcseCoreSubject(subject)) {
        return false;
      }
      final preferredBoard = gcsePreferredBoardForSubject(subject);
      final board = row['board']?.toString().trim() ?? '';
      if (preferredBoard == null) {
        return false;
      }
      return board.toLowerCase() == preferredBoard.toLowerCase();
    }).toList();
  }

  List<String> _subjects(List<Map<String, dynamic>> rows) {
    final set = rows
        .map((row) => row['subject']?.toString().trim() ?? '')
        .where((subject) => subject.isNotEmpty)
        .toSet()
        .toList();
    set.sort();
    return set;
  }

  static const Set<String> _tieredGcseSubjects = {
    'Mathematics',
    'Combined Science',
    'Biology',
    'Chemistry',
    'Physics',
  };

  bool _supportsTierSelection(String subject) {
    return (_selectedFamily ?? '').toLowerCase() == 'gcse' &&
        _tieredGcseSubjects.contains(subject);
  }

  static const List<String> _gcseGradeOptions = <String>[
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
  ];

  void _seedSubjectGrades(String subject) {
    _selectedCurrentGradeBySubject.putIfAbsent(
        subject, () => _defaultCurrentGrade);
    _selectedTargetGradeBySubject.putIfAbsent(
        subject, () => _defaultTargetGrade);

    final current =
        int.tryParse(_selectedCurrentGradeBySubject[subject] ?? '') ?? 0;
    final target =
        int.tryParse(_selectedTargetGradeBySubject[subject] ?? '') ?? 0;
    if (current > 0 && target > 0 && target < current) {
      _selectedTargetGradeBySubject[subject] = current.toString();
    }
  }

  void _removeSubjectGrades(String subject) {
    _selectedCurrentGradeBySubject.remove(subject);
    _selectedTargetGradeBySubject.remove(subject);
  }

  Set<String> _coreSubjectsForCurrentSelection(
    List<Map<String, dynamic>> scopedRows,
  ) {
    if ((_selectedFamily ?? '').toLowerCase() != 'gcse') {
      return const <String>{};
    }
    if ((_selectedCountryCode ?? '').toUpperCase() != 'GB') {
      return const <String>{};
    }

    final available = _subjects(scopedRows).toSet();
    final core = <String>{};
    for (final subject in gcseCoreSubjects) {
      if (available.contains(subject)) {
        core.add(subject);
      }
    }
    return core;
  }

  void _applyLockedSubjects(List<Map<String, dynamic>> scopedRows) {
    final mandatory = _coreSubjectsForCurrentSelection(scopedRows);
    _lockedSubjects
      ..clear()
      ..addAll(mandatory);

    for (final subject in mandatory) {
      _selectedSubjects.add(subject);
      final boards = _boardsForSubject(scopedRows, subject);
      final preferredBoard = gcsePreferredBoardForSubject(subject);
      if (boards.isNotEmpty) {
        if (preferredBoard != null && boards.contains(preferredBoard)) {
          _selectedBoardBySubject[subject] = preferredBoard;
        } else {
          final existing = _selectedBoardBySubject[subject];
          if (existing == null || !boards.contains(existing)) {
            _selectedBoardBySubject[subject] = boards.first;
          }
        }
      }
      if (_supportsTierSelection(subject)) {
        _selectedTierBySubject.putIfAbsent(subject, () => 'Foundation');
      }
      _seedSubjectGrades(subject);
    }

    final allSubjects = _subjects(scopedRows);
    for (final subject in allSubjects) {
      if (_selectedSubjects.contains(subject) && !mandatory.contains(subject)) {
        _selectedSubjects.remove(subject);
        _selectedBoardBySubject.remove(subject);
        _selectedTierBySubject.remove(subject);
        _removeSubjectGrades(subject);
      }
    }
  }

  bool _shouldHideOptionalSubject(String subject) {
    return !isGcseCoreSubject(subject);
  }

  List<String> _boardsForSubject(
    List<Map<String, dynamic>> rows,
    String subject,
  ) {
    final set = rows
        .where((row) =>
            (row['subject']?.toString().trim().toLowerCase() ?? '') ==
            subject.toLowerCase())
        .map((row) => row['board']?.toString().trim() ?? '')
        .where((board) => board.isNotEmpty)
        .toSet()
        .toList();
    set.sort();
    return set;
  }

  Map<String, dynamic>? _entryForSubjectBoard(
    List<Map<String, dynamic>> rows,
    String subject,
    String board,
  ) {
    for (final row in rows) {
      final rowSubject = row['subject']?.toString().trim().toLowerCase() ?? '';
      final rowBoard = row['board']?.toString().trim().toLowerCase() ?? '';
      if (rowSubject == subject.toLowerCase() &&
          rowBoard == board.toLowerCase()) {
        return row;
      }
    }
    return null;
  }

  void _seedDefaults(List<Map<String, dynamic>> rows) {
    _selectedFamily = 'gcse';
    _selectedCountryCode = 'GB';
  }

  void _advance(List<Map<String, dynamic>> scopedRows) {
    if (_step == _ExamSetupStep.subjects && _selectedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select at least one subject to continue.')),
      );
      return;
    }

    if (_step == _ExamSetupStep.boards) {
      final missing = _selectedSubjects.where((subject) {
        final board = _selectedBoardBySubject[subject];
        return board == null || board.trim().isEmpty;
      }).toList();
      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Choose board for ${missing.first}.')),
        );
        return;
      }

      for (final subject in _selectedSubjects) {
        _seedSubjectGrades(subject);
        final currentGrade =
            int.tryParse(_selectedCurrentGradeBySubject[subject] ?? '') ?? 0;
        final targetGrade =
            int.tryParse(_selectedTargetGradeBySubject[subject] ?? '') ?? 0;
        if (currentGrade <= 0 || targetGrade <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Choose current and target grade for $subject.'),
            ),
          );
          return;
        }
        if (targetGrade < currentGrade) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Target grade for $subject should be at least current grade.',
              ),
            ),
          );
          return;
        }
      }
    }

    final idx = _currentStepIndex();
    if (idx < _stepOrder.length - 1) {
      setState(() {
        _step = _stepOrder[idx + 1];
      });
      return;
    }

    _saveTargets(scopedRows);
  }

  Future<void> _saveTargets(List<Map<String, dynamic>> scopedRows) async {
    if (_saving) return;
    setState(() {
      _saving = true;
    });

    try {
      final repo = ref.read(examRepositoryProvider);
      final selected = _selectedSubjects.toList()..sort();
      var makeActive = true;

      for (final subject in selected) {
        final board = _selectedBoardBySubject[subject];
        if (board == null || board.trim().isEmpty) continue;
        final row = _entryForSubjectBoard(scopedRows, subject, board);
        if (row == null) continue;
        final selectedTier = _selectedTierBySubject[subject];
        final effectiveLevel =
            (selectedTier != null && selectedTier.trim().isNotEmpty)
                ? selectedTier
                : (row['level']?.toString() ?? '');

        await repo.upsertMyTarget(
          countryCode: row['countryCode']?.toString() ?? '',
          countryName: row['countryName']?.toString() ?? 'International',
          examFamily: row['examFamily']?.toString() ?? '',
          board: row['board']?.toString() ?? '',
          level: effectiveLevel,
          subject: row['subject']?.toString() ?? '',
          year: _selectedYearGroup,
          currentGrade: _selectedCurrentGradeBySubject[subject],
          targetGrade: _selectedTargetGradeBySubject[subject],
          mockDateAt: _mockDate?.millisecondsSinceEpoch,
          examDateAt: _examDate?.millisecondsSinceEpoch,
          timetableMode: 'manual',
          weeklyStudyMinutes: _dailyStudyMinutes * 7,
          weeklySessionsTarget: _weeklySessionsTarget,
          sourceCatalogSlug: row['slug']?.toString(),
          makeActive: makeActive,
        );
        makeActive = false;
      }

      ref.invalidate(userExamTargetProvider);
      ref.invalidate(userExamTargetsProvider);
      ref.invalidate(userExamDashboardProvider);
      if (mounted) {
        context.go('/exam-dashboard');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save exam setup: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _buildOnboardingStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Exam onboarding',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Set your known dates and realistic daily capacity. We use this to auto-adjust your revision plan.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 14),
        Text(
          'Current year group',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [10, 11].map((year) {
            return ChoiceChip(
              selected: _selectedYearGroup == year,
              label: Text('Year $year'),
              onSelected: (_) {
                setState(() {
                  _selectedYearGroup = year;
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dates',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await _pickDate(_mockDate);
                          if (picked == null) return;
                          setState(() {
                            _mockDate = picked;
                          });
                        },
                        icon: const Icon(Icons.event_outlined),
                        label: const Text('Set mock date'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _mockDate == null
                          ? null
                          : () {
                              setState(() {
                                _mockDate = null;
                              });
                            },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                Text(
                  'Mocks: ${_formatDate(_mockDate)}',
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
                        label: const Text('Set GCSE date'),
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
                  'GCSEs: ${_formatDate(_examDate)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Daily study minutes: $_dailyStudyMinutes',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Slider(
                  min: 10,
                  max: 180,
                  divisions: 34,
                  label: '$_dailyStudyMinutes min/day',
                  value: _dailyStudyMinutes.toDouble(),
                  onChanged: (value) {
                    setState(() {
                      _dailyStudyMinutes = value.round();
                    });
                  },
                ),
                Text(
                  'Weekly sessions target: $_weeklySessionsTarget',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Slider(
                  min: 2,
                  max: 14,
                  divisions: 12,
                  label: '$_weeklySessionsTarget sessions',
                  value: _weeklySessionsTarget.toDouble(),
                  onChanged: (value) {
                    setState(() {
                      _weeklySessionsTarget = value.round();
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyStep(
    BuildContext context,
    List<Map<String, dynamic>> rows,
  ) {
    final gcseRows = _rowsForFamilyAndCountry(rows);
    final availableSubjects = _coreSubjectsForCurrentSelection(gcseRows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GCSE Setup',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Exam Mode is focused on GCSE only for now. We will set up your core subjects, locked boards, tiers, and year group next.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.school_outlined,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'GCSE • United Kingdom',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${availableSubjects.length} core subjects in this depth-first track.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Next: confirm subjects, then set board-locked grades and tiers.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectsStep(
    BuildContext context,
    List<Map<String, dynamic>> scopedRows,
  ) {
    final query = _subjectQueryController.text.trim().toLowerCase();
    final subjects = _subjects(scopedRows)
        .where((subject) => !_lockedSubjects.contains(subject))
        .where((subject) => !_shouldHideOptionalSubject(subject))
        .where(
            (subject) => query.isEmpty || subject.toLowerCase().contains(query))
        .toList();
    final optionalSelected = _selectedSubjects
        .where((subject) => !_lockedSubjects.contains(subject));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Core GCSE track',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          _lockedSubjects.isEmpty
              ? 'Pick everything you are currently studying. You can always update later.'
              : 'This depth-first track is locked to 6 required subjects for now. Optional subjects will be added after core quality is complete.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 14),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.25),
          ),
          child: Text(
            'Locked subjects: ${gcseCoreSubjects.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        TextField(
          controller: _subjectQueryController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search subjects (e.g., Mathematics)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              '${optionalSelected.length} optional selected',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            if (_selectedSubjects.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() {
                    final keep = _lockedSubjects.toSet();
                    _selectedSubjects
                      ..clear()
                      ..addAll(keep);
                    _selectedBoardBySubject.removeWhere(
                      (subject, _) => !keep.contains(subject),
                    );
                    _selectedTierBySubject.removeWhere(
                      (subject, _) => !keep.contains(subject),
                    );
                    _selectedCurrentGradeBySubject.removeWhere(
                      (subject, _) => !keep.contains(subject),
                    );
                    _selectedTargetGradeBySubject.removeWhere(
                      (subject, _) => !keep.contains(subject),
                    );
                  });
                },
                child: const Text('Clear all'),
              ),
          ],
        ),
        if (_lockedSubjects.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Core GCSE subjects are pre-selected: ${_lockedSubjects.join(', ')}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        if (subjects.isEmpty)
          const Text('No optional subjects available in this core track.')
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: subjects.map((subject) {
              final selected = _selectedSubjects.contains(subject);
              final locked = _lockedSubjects.contains(subject);
              return FilterChip(
                selected: selected,
                avatar:
                    locked ? const Icon(Icons.lock_outline, size: 16) : null,
                label: Text(subject),
                onSelected: (value) {
                  if (locked) return;
                  setState(() {
                    if (value) {
                      _selectedSubjects.add(subject);
                      final boards = _boardsForSubject(scopedRows, subject);
                      if (boards.isNotEmpty) {
                        _selectedBoardBySubject.putIfAbsent(
                            subject, () => boards.first);
                      }
                      if (_supportsTierSelection(subject)) {
                        _selectedTierBySubject.putIfAbsent(
                            subject, () => 'Foundation');
                      }
                      _seedSubjectGrades(subject);
                    } else {
                      _selectedSubjects.remove(subject);
                      _selectedBoardBySubject.remove(subject);
                      _selectedTierBySubject.remove(subject);
                      _removeSubjectGrades(subject);
                    }
                  });
                },
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildBoardsStep(
    BuildContext context,
    List<Map<String, dynamic>> scopedRows,
  ) {
    final selectedSubjects = _selectedSubjects.toList()
      ..sort((a, b) {
        final aLocked = _lockedSubjects.contains(a);
        final bLocked = _lockedSubjects.contains(b);
        if (aLocked != bLocked) return aLocked ? -1 : 1;
        return a.compareTo(b);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Boards and grades',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Boards are locked for the core depth-first track. Set tier and grade trajectory for each subject.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 14),
        if (selectedSubjects.isEmpty)
          const Text('Select at least one subject first.')
        else ...[
          ...selectedSubjects.map((subject) {
            final boards = _boardsForSubject(scopedRows, subject);
            final selectedBoard = _selectedBoardBySubject[subject];
            final preferredBoard = gcsePreferredBoardForSubject(subject);
            final selectedTier =
                _selectedTierBySubject[subject] ?? 'Foundation';
            final selectedCurrentGrade =
                _selectedCurrentGradeBySubject[subject] ?? _defaultCurrentGrade;
            final selectedTargetGrade =
                _selectedTargetGradeBySubject[subject] ?? _defaultTargetGrade;
            final locked = _lockedSubjects.contains(subject);
            final boardLocked =
                preferredBoard != null && boards.contains(preferredBoard);
            final boardOptions =
                boardLocked ? <String>[preferredBoard] : boards;
            final safeValue = boards.contains(selectedBoard)
                ? selectedBoard
                : (boardOptions.isNotEmpty ? boardOptions.first : null);
            final showTierSelection = _supportsTierSelection(subject);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (locked)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.lock_outline,
                                  size: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                subject,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: boardLocked
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Text(
                                  preferredBoard,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              )
                            : DropdownButtonFormField<String>(
                                key: ValueKey('$subject-$safeValue'),
                                initialValue: safeValue,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: boardOptions
                                    .map(
                                      (board) => DropdownMenuItem<String>(
                                        value: board,
                                        child: Text(
                                          board,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _selectedBoardBySubject[subject] = value;
                                  });
                                },
                              ),
                      ),
                    ],
                  ),
                  if (boardLocked) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Board locked for this core subject.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  if (showTierSelection) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Foundation', 'Higher'].map((tier) {
                        return ChoiceChip(
                          selected: selectedTier == tier,
                          label: Text(tier),
                          onSelected: (_) {
                            setState(() {
                              _selectedTierBySubject[subject] = tier;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue:
                              _gcseGradeOptions.contains(selectedCurrentGrade)
                                  ? selectedCurrentGrade
                                  : _gcseGradeOptions.first,
                          decoration: const InputDecoration(
                            labelText: 'Current',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _gcseGradeOptions
                              .map(
                                (grade) => DropdownMenuItem<String>(
                                  value: grade,
                                  child: Text('Grade $grade'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedCurrentGradeBySubject[subject] = value;
                              final current = int.tryParse(value) ?? 0;
                              final target = int.tryParse(
                                      _selectedTargetGradeBySubject[subject] ??
                                          '') ??
                                  0;
                              if (target < current) {
                                _selectedTargetGradeBySubject[subject] = value;
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue:
                              _gcseGradeOptions.contains(selectedTargetGrade)
                                  ? selectedTargetGrade
                                  : _gcseGradeOptions.first,
                          decoration: const InputDecoration(
                            labelText: 'Target',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _gcseGradeOptions
                              .where((grade) {
                                final current = int.tryParse(
                                        _selectedCurrentGradeBySubject[
                                                subject] ??
                                            selectedCurrentGrade) ??
                                    0;
                                final target = int.tryParse(grade) ?? 0;
                                return target >= current;
                              })
                              .map(
                                (grade) => DropdownMenuItem<String>(
                                  value: grade,
                                  child: Text('Grade $grade'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedTargetGradeBySubject[subject] = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildReviewStep(
    BuildContext context,
    List<Map<String, dynamic>> scopedRows,
  ) {
    final selectedSubjects = _selectedSubjects.toList()..sort();
    final selectedFamily = _selectedFamily;
    final selectedCountry = _selectedCountryCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review and create Exam Mode',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'You will get a dedicated dashboard and reports for each selected subject.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.18),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Setup overview',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ReviewMetricTile(
                    icon: Icons.flag_outlined,
                    label: 'Track',
                    value: selectedFamily == null
                        ? '-'
                        : '${_familyTitle(selectedFamily)} • ${selectedCountry ?? '-'}',
                  ),
                  _ReviewMetricTile(
                    icon: Icons.groups_2_outlined,
                    label: 'Subjects',
                    value: '${selectedSubjects.length} selected',
                  ),
                  _ReviewMetricTile(
                    icon: Icons.school_outlined,
                    label: 'Year group',
                    value: 'Year $_selectedYearGroup',
                  ),
                  _ReviewMetricTile(
                    icon: Icons.schedule_outlined,
                    label: 'Study plan',
                    value:
                        '${_dailyStudyMinutes}m/day • $_weeklySessionsTarget sessions/week',
                  ),
                  _ReviewMetricTile(
                    icon: Icons.event_note_outlined,
                    label: 'Dates',
                    value:
                        'Mock ${_formatDate(_mockDate)} • GCSE ${_formatDate(_examDate)}',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.18),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subject plan',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Board and grade trajectory for each subject.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 10),
              ...selectedSubjects.map((subject) {
                final board = _selectedBoardBySubject[subject] ?? '-';
                final row = _entryForSubjectBoard(scopedRows, subject, board);
                final level = _selectedTierBySubject[subject] ??
                    (row?['level']?.toString() ?? '');
                final currentGrade = _selectedCurrentGradeBySubject[subject] ??
                    _defaultCurrentGrade;
                final targetGrade = _selectedTargetGradeBySubject[subject] ??
                    _defaultTargetGrade;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.58),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [board, level]
                                  .where((part) => part.trim().isNotEmpty)
                                  .join(' • '),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.16),
                        ),
                        child: Text(
                          'G$currentGrade -> G$targetGrade',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSetupHeader(BuildContext context, int subjectsCount) {
    final progress = (_currentStepIndex() + 1) / _stepOrder.length;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: colorScheme.primary.withValues(alpha: 0.14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.workspace_premium_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Let's set up your GCSE plan",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: colorScheme.primary.withValues(alpha: 0.14),
                ),
                child: Text(
                  'Step ${_currentStepIndex() + 1}/${_stepOrder.length}',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'GCSE • UK curriculum • $subjectsCount core subjects selected',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: colorScheme.primary.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _stepOrder.asMap().entries.map((entry) {
              return _buildStepPill(context, entry.key, entry.value);
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _stepIcon(_ExamSetupStep step) {
    switch (step) {
      case _ExamSetupStep.family:
        return Icons.route_outlined;
      case _ExamSetupStep.subjects:
        return Icons.menu_book_outlined;
      case _ExamSetupStep.boards:
        return Icons.rule_folder_outlined;
      case _ExamSetupStep.onboarding:
        return Icons.event_note_outlined;
      case _ExamSetupStep.review:
        return Icons.fact_check_outlined;
    }
  }

  Widget _buildStepPill(BuildContext context, int index, _ExamSetupStep step) {
    final active = step == _step;
    final complete = index < _currentStepIndex();
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = active
        ? colorScheme.primary.withValues(alpha: 0.2)
        : complete
            ? colorScheme.tertiary.withValues(alpha: 0.16)
            : colorScheme.surface.withValues(alpha: 0.6);

    final borderColor = active
        ? colorScheme.primary.withValues(alpha: 0.34)
        : complete
            ? colorScheme.tertiary.withValues(alpha: 0.28)
            : colorScheme.outline.withValues(alpha: 0.22);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: bgColor,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            complete ? Icons.check_circle_rounded : _stepIcon(step),
            size: 15,
            color: active
                ? colorScheme.primary
                : complete
                    ? colorScheme.tertiary
                    : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 7),
          Text(
            '${index + 1} ${_stepTitle(step)}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(examCatalogAllProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Mode Setup'),
      ),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Failed to load exam catalog: $error'),
          ),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(child: Text('Exam catalog is empty.'));
          }

          _seedDefaults(rows);
          final scopedRows = _rowsForFamilyAndCountry(rows);
          _applyLockedSubjects(scopedRows);
          final subjectsCount =
              _coreSubjectsForCurrentSelection(scopedRows).length;

          return SafeArea(
            child: Column(
              children: [
                _buildSetupHeader(context, subjectsCount),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: switch (_step) {
                          _ExamSetupStep.family =>
                            _buildFamilyStep(context, rows),
                          _ExamSetupStep.subjects =>
                            _buildSubjectsStep(context, scopedRows),
                          _ExamSetupStep.boards =>
                            _buildBoardsStep(context, scopedRows),
                          _ExamSetupStep.onboarding =>
                            _buildOnboardingStep(context),
                          _ExamSetupStep.review =>
                            _buildReviewStep(context, scopedRows),
                        },
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      if (_step != _ExamSetupStep.family)
                        OutlinedButton.icon(
                          onPressed: _saving
                              ? null
                              : () {
                                  setState(() {
                                    final idx = _currentStepIndex();
                                    _step = _stepOrder[idx - 1];
                                  });
                                },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back'),
                        ),
                      if (_step != _ExamSetupStep.family)
                        const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              _saving ? null : () => _advance(scopedRows),
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(_step == _ExamSetupStep.review
                                  ? Icons.check_circle_outline
                                  : Icons.arrow_forward),
                          label: Text(
                            _step == _ExamSetupStep.review
                                ? 'Save Exam Mode'
                                : 'Continue',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReviewMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReviewMetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.58),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
