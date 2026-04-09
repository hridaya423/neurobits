import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:neurobits/core/providers.dart';
import 'package:neurobits/services/convex_client_service.dart';
import 'package:neurobits/services/timetable_sync_service.dart';

class ExamPlanningScreen extends ConsumerStatefulWidget {
  const ExamPlanningScreen({super.key});

  @override
  ConsumerState<ExamPlanningScreen> createState() => _ExamPlanningScreenState();
}

class _ExamPlanningScreenState extends ConsumerState<ExamPlanningScreen> {
  final Map<String, DateTime?> _mockDatesByTarget = <String, DateTime?>{};
  final Set<String> _dirtyTargets = <String>{};
  final Set<String> _clearMockDateForTarget = <String>{};

  bool _initialized = false;
  bool _savingTimetable = false;
  bool _savingDates = false;
  bool _analyzingTimetable = false;
  bool _generatingRevisionWindows = false;
  String _timetableMode = 'none';
  String _timetableProvider = '';
  int _dailyStudyMinutes = 45;
  int _weeklySessionsTarget = 4;
  String? _timetableSummary;
  String? _timetableSourceText;
  List<String> _timetableHighlights = const [];
  List<Map<String, String>> _timetableSlots = const [];
  List<Map<String, dynamic>> _revisionWindows = const [];
  String? _studyRhythmLabel;
  int _studyRhythmSampleSize = 0;
  String _selectedTimetableDay = 'mon';

  static const List<MapEntry<String, String>> _weekDays = [
    MapEntry('mon', 'Mon'),
    MapEntry('tue', 'Tue'),
    MapEntry('wed', 'Wed'),
    MapEntry('thu', 'Thu'),
    MapEntry('fri', 'Fri'),
    MapEntry('sat', 'Sat'),
    MapEntry('sun', 'Sun'),
  ];

  void _seedState(List<Map<String, dynamic>> targets) {
    if (_initialized) return;
    _initialized = true;

    for (final target in targets) {
      final targetId = target['_id']?.toString();
      if (targetId == null || targetId.trim().isEmpty) continue;
      final mockDateAt = convexInt(target['mockDateAt']);
      _mockDatesByTarget[targetId] = mockDateAt > 0
          ? DateTime.fromMillisecondsSinceEpoch(mockDateAt)
          : null;
    }

    final first = targets.isNotEmpty ? targets.first : null;
    final rawMode = first?['timetableMode']?.toString().trim().toLowerCase();
    if (rawMode != null && rawMode.isNotEmpty) {
      _timetableMode = rawMode;
    }
    _timetableProvider = first?['timetableProvider']?.toString().trim() ?? '';
    _timetableSummary = first?['timetableSummary']?.toString().trim();
    _timetableSourceText = first?['timetableSourceText']?.toString().trim();
    _timetableSlots = _normalizeTimetableSlots(first?['timetableSlots']);
    _revisionWindows = _normalizeRevisionWindows(first?['revisionWindows']);
    if (_timetableSlots.isNotEmpty) {
      _selectedTimetableDay = _timetableSlots.first['day'] ?? 'mon';
    }
    final studyMinutes = convexInt(first?['weeklyStudyMinutes']);
    if (studyMinutes > 0) {
      _dailyStudyMinutes = (studyMinutes / 7).round().clamp(10, 180);
    }
    final sessionsTarget = convexInt(first?['weeklySessionsTarget']);
    if (sessionsTarget > 0) {
      _weeklySessionsTarget = sessionsTarget;
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Not set';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<DateTime?> _pickDate(DateTime? initialDate) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now.add(const Duration(days: 30)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    return selected;
  }

  String? _normalizeDayKey(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (normalized.startsWith('mon')) return 'mon';
    if (normalized.startsWith('tue')) return 'tue';
    if (normalized.startsWith('wed')) return 'wed';
    if (normalized.startsWith('thu')) return 'thu';
    if (normalized.startsWith('fri')) return 'fri';
    if (normalized.startsWith('sat')) return 'sat';
    if (normalized.startsWith('sun')) return 'sun';
    return null;
  }

  String? _normalizeTimeText(String? value) {
    if (value == null) return null;
    final match =
        RegExp(r'^(\d{1,2})(?::|\.)(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  int _dayOrder(String day) {
    final index = _weekDays.indexWhere((entry) => entry.key == day);
    return index < 0 ? 999 : index;
  }

  String _dayLabel(String day) {
    for (final entry in _weekDays) {
      if (entry.key == day) return entry.value;
    }
    return day;
  }

  int? _timeToMinutes(String? value) {
    if (value == null) return null;
    final normalized = _normalizeTimeText(value);
    if (normalized == null) return null;
    final parts = normalized.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return (hour * 60) + minute;
  }

  Set<int> _overlapIndicesForDay(String day) {
    final entries = _slotsForDay(day);
    final overlap = <int>{};
    for (int i = 0; i < entries.length; i++) {
      final a = entries[i];
      final aStart = _timeToMinutes(a.value['start']);
      final aEnd = _timeToMinutes(a.value['end']);
      if (aStart == null || aEnd == null) continue;

      for (int j = i + 1; j < entries.length; j++) {
        final b = entries[j];
        final bStart = _timeToMinutes(b.value['start']);
        final bEnd = _timeToMinutes(b.value['end']);
        if (bStart == null || bEnd == null) continue;
        final overlaps = aStart < bEnd && bStart < aEnd;
        if (overlaps) {
          overlap.add(a.key);
          overlap.add(b.key);
        }
      }
    }
    return overlap;
  }

  Set<int> _overlapIndicesAllDays() {
    final out = <int>{};
    for (final day in _weekDays) {
      out.addAll(_overlapIndicesForDay(day.key));
    }
    return out;
  }

  List<Map<String, String>> _standardTemplateSlots() {
    const weekdays = ['mon', 'tue', 'wed', 'thu', 'fri'];
    const periods = [
      ('08:30', '09:20', 'School period 1'),
      ('09:25', '10:15', 'School period 2'),
      ('10:35', '11:25', 'School period 3'),
      ('11:30', '12:20', 'School period 4'),
      ('13:05', '13:55', 'School period 5'),
      ('14:00', '14:50', 'School period 6'),
    ];
    final slots = <Map<String, String>>[];
    for (final day in weekdays) {
      for (final period in periods) {
        slots.add({
          'day': day,
          'start': period.$1,
          'end': period.$2,
          'subject': period.$3,
        });
      }
    }
    return slots;
  }

  List<Map<String, String>> _compactTemplateSlots() {
    const weekdays = ['mon', 'tue', 'wed', 'thu', 'fri'];
    const periods = [
      ('09:00', '10:00', 'School period 1'),
      ('10:10', '11:10', 'School period 2'),
      ('11:40', '12:40', 'School period 3'),
      ('13:30', '14:30', 'School period 4'),
    ];
    final slots = <Map<String, String>>[];
    for (final day in weekdays) {
      for (final period in periods) {
        slots.add({
          'day': day,
          'start': period.$1,
          'end': period.$2,
          'subject': period.$3,
        });
      }
    }
    return slots;
  }

  Future<bool> _confirmTemplateReplace(String templateName) async {
    if (_timetableSlots.isEmpty) return true;
    final decision = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Replace current timetable?'),
          content: Text(
            'Apply "$templateName" and replace your current ${_timetableSlots.length} saved periods?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Replace'),
            ),
          ],
        );
      },
    );
    return decision ?? false;
  }

  Future<void> _applyTimetableTemplate({
    required String templateName,
    required List<Map<String, String>> slots,
  }) async {
    final confirmed = await _confirmTemplateReplace(templateName);
    if (!confirmed) return;
    setState(() {
      _timetableSlots = _normalizeTimetableSlots(slots);
      _selectedTimetableDay = _timetableSlots.isNotEmpty
          ? (_timetableSlots.first['day'] ?? 'mon')
          : 'mon';
      _timetableMode = 'manual';
      _timetableProvider = 'manual_template';
      _timetableSummary = '$templateName applied. Adjust periods as needed.';
      _timetableSourceText = 'Template: $templateName';
      _timetableHighlights = const [
        'Template loaded. Edit periods to match your school day.',
      ];
      _revisionWindows = _buildRevisionWindowsFromTimetable();
      _studyRhythmLabel = null;
      _studyRhythmSampleSize = 0;
    });
  }

  List<Map<String, String>> _normalizeTimetableSlots(dynamic raw) {
    if (raw is! List) return const [];
    final out = <Map<String, String>>[];
    final seen = <String>{};
    for (final row in raw) {
      if (row is! Map) continue;
      final day = _normalizeDayKey(row['day']?.toString());
      final start = _normalizeTimeText(row['start']?.toString());
      final end = _normalizeTimeText(row['end']?.toString());
      final subject = row['subject']?.toString().trim() ?? '';
      if (day == null || start == null || end == null || subject.isEmpty) {
        continue;
      }
      final key = '$day|$start|$end|${subject.toLowerCase()}';
      if (!seen.add(key)) continue;
      out.add({
        'day': day,
        'start': start,
        'end': end,
        'subject': subject,
      });
      if (out.length >= 120) break;
    }
    out.sort((a, b) {
      final dayDiff = _dayOrder(a['day'] ?? '') - _dayOrder(b['day'] ?? '');
      if (dayDiff != 0) return dayDiff;
      final startDiff = (a['start'] ?? '').compareTo(b['start'] ?? '');
      if (startDiff != 0) return startDiff;
      return (a['subject'] ?? '').compareTo(b['subject'] ?? '');
    });
    return out;
  }

  String _minutesToTimeText(int minutes) {
    final safe = minutes.clamp(0, (23 * 60) + 59);
    final hour = (safe ~/ 60).toString().padLeft(2, '0');
    final minute = (safe % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  List<Map<String, dynamic>> _normalizeRevisionWindows(dynamic raw) {
    if (raw is! List) return const [];
    final out = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final row in raw) {
      if (row is! Map) continue;
      final day = _normalizeDayKey(row['day']?.toString());
      final start = _normalizeTimeText(row['start']?.toString());
      final end = _normalizeTimeText(row['end']?.toString());
      final durationRaw = row['durationMinutes'];
      final duration = durationRaw is num
          ? durationRaw.toInt()
          : int.tryParse(durationRaw?.toString() ?? '');
      if (day == null || start == null || end == null || duration == null) {
        continue;
      }
      final boundedDuration = duration.clamp(10, 180);
      if (start.compareTo(end) >= 0) continue;
      final key = '$day|$start|$end|$boundedDuration';
      if (!seen.add(key)) continue;
      out.add({
        'day': day,
        'start': start,
        'end': end,
        'durationMinutes': boundedDuration,
      });
      if (out.length >= 28) break;
    }
    out.sort((a, b) {
      final dayDiff = _dayOrder(a['day']?.toString() ?? '') -
          _dayOrder(b['day']?.toString() ?? '');
      if (dayDiff != 0) return dayDiff;
      final startDiff = (a['start']?.toString() ?? '')
          .compareTo(b['start']?.toString() ?? '');
      if (startDiff != 0) return startDiff;
      return (a['end']?.toString() ?? '').compareTo(b['end']?.toString() ?? '');
    });
    return out;
  }

  String _friendlyStudyBandLabel(String? bandKey) {
    switch ((bandKey ?? '').trim().toLowerCase()) {
      case 'after_school':
        return 'after school';
      case 'after_dinner':
        return 'after dinner';
      case 'before_sleep':
        return 'before sleep';
      case 'morning':
        return 'morning';
      case 'midday':
        return 'midday';
      default:
        return 'flexible';
    }
  }

  List<Map<String, dynamic>> _buildRevisionWindowsFromTimetable({
    Map<String, dynamic>? studyProfile,
  }) {
    if (_timetableSlots.isEmpty) return const [];
    final duration = _dailyStudyMinutes.clamp(20, 90);
    final targetSessions = _weeklySessionsTarget.clamp(1, 14);
    final desiredSessions = targetSessions < 3 ? 3 : targetSessions;

    String normalizeBand(String? value) {
      final key = (value ?? '').trim().toLowerCase();
      switch (key) {
        case 'after_school':
          return 'after_school';
        case 'after_dinner':
          return 'after_dinner';
        case 'before_sleep':
          return 'before_sleep';
        case 'morning':
          return 'morning';
        default:
          return 'after_school';
      }
    }

    String primaryBand =
        normalizeBand(studyProfile?['primaryBand']?.toString());
    String secondaryBand =
        normalizeBand(studyProfile?['secondaryBand']?.toString());
    if (secondaryBand == primaryBand) {
      secondaryBand =
          primaryBand == 'after_school' ? 'after_dinner' : 'after_school';
    }

    final dayStats = <String, Map<String, int?>>{};
    for (final day in _weekDays) {
      dayStats[day.key] = {
        'load': 0,
        'latestEnd': null,
      };
    }
    for (final slot in _timetableSlots) {
      final day = slot['day'];
      if (day == null || !dayStats.containsKey(day)) continue;
      final start = _timeToMinutes(slot['start']);
      final end = _timeToMinutes(slot['end']);
      if (start == null || end == null || end <= start) continue;
      final state = dayStats[day]!;
      state['load'] = (state['load'] ?? 0) + (end - start);
      final latest = state['latestEnd'];
      if (latest == null || end > latest) {
        state['latestEnd'] = end;
      }
    }

    final dayOrderMap = {
      for (int i = 0; i < _weekDays.length; i++) _weekDays[i].key: i,
    };
    final weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri'];
    final weekendKeys = ['sat', 'sun'];

    int loadFor(String day) => dayStats[day]?['load'] ?? 0;
    List<String> sortByLoad(List<String> days) {
      final sorted = [...days];
      sorted.sort((a, b) {
        final loadDiff = loadFor(a) - loadFor(b);
        if (loadDiff != 0) return loadDiff;
        return (dayOrderMap[a] ?? 99) - (dayOrderMap[b] ?? 99);
      });
      return sorted;
    }

    final preferredDays = [
      ...sortByLoad(weekdayKeys),
      ...sortByLoad(weekendKeys),
    ];

    int startForBand({
      required String band,
      required String day,
      required int pass,
      int? latestEnd,
    }) {
      final isWeekend = day == 'sat' || day == 'sun';
      final stagger = pass * (duration + 35);
      switch (band) {
        case 'morning':
          return isWeekend ? 9 * 60 + stagger : 6 * 60 + 45 + stagger;
        case 'before_sleep':
          return 22 * 60 + 10 + (pass * 25);
        case 'after_dinner':
          return 19 * 60 + 20 + (pass * 25);
        case 'after_school':
        default:
          if (latestEnd != null) {
            return latestEnd + 50 + stagger;
          }
          return isWeekend ? 11 * 60 + 20 + stagger : 16 * 60 + 50 + stagger;
      }
    }

    int clampStart(int startMinute) {
      if (startMinute < 6 * 60) return 6 * 60;
      if (startMinute > 23 * 60 - duration) return 23 * 60 - duration;
      return startMinute;
    }

    final output = <Map<String, dynamic>>[];
    final usedKeys = <String>{};
    int generated = 0;
    int pass = 0;
    while (generated < desiredSessions && pass < 3) {
      for (final day in preferredDays) {
        if (generated >= desiredSessions) break;
        final latestEnd = dayStats[day]?['latestEnd'];
        final band = pass.isEven ? primaryBand : secondaryBand;
        final startMinute = clampStart(startForBand(
            band: band, day: day, pass: pass, latestEnd: latestEnd));
        final endMinute = startMinute + duration;
        final startText = _minutesToTimeText(startMinute);
        final endText = _minutesToTimeText(endMinute);
        final key = '$day|$startText|$endText';
        if (usedKeys.contains(key)) continue;
        usedKeys.add(key);
        output.add({
          'day': day,
          'start': startText,
          'end': endText,
          'durationMinutes': duration,
        });
        generated += 1;
      }
      pass += 1;
    }

    return _normalizeRevisionWindows(output);
  }

  Future<void> _generateRevisionWindows() async {
    if (_timetableSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add timetable periods first, then generate windows.'),
        ),
      );
      return;
    }
    if (_generatingRevisionWindows) return;
    setState(() {
      _generatingRevisionWindows = true;
    });
    Map<String, dynamic>? profile;
    try {
      final repo = ref.read(examRepositoryProvider);
      profile = await repo.getMyStudyTimeProfile(
        timezoneOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      );
    } catch (_) {
      profile = null;
    }

    final generated = _buildRevisionWindowsFromTimetable(studyProfile: profile);
    if (!mounted) return;
    if (generated.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not generate revision windows from timetable.'),
        ),
      );
      setState(() {
        _generatingRevisionWindows = false;
      });
      return;
    }
    setState(() {
      _revisionWindows = generated;
      _studyRhythmLabel =
          _friendlyStudyBandLabel(profile?['primaryBand']?.toString());
      _studyRhythmSampleSize = (profile?['sampleSize'] as num?)?.toInt() ?? 0;
      _generatingRevisionWindows = false;
      if (_timetableProvider.trim().isEmpty ||
          _timetableProvider == 'manual_input') {
        _timetableProvider = 'manual_editor';
      }
    });
  }

  List<MapEntry<int, Map<String, String>>> _slotsForDay(String day) {
    final entries = <MapEntry<int, Map<String, String>>>[];
    for (int i = 0; i < _timetableSlots.length; i++) {
      final slot = _timetableSlots[i];
      if (slot['day'] == day) {
        entries.add(MapEntry(i, slot));
      }
    }
    entries.sort((a, b) {
      final startDiff =
          (a.value['start'] ?? '').compareTo(b.value['start'] ?? '');
      if (startDiff != 0) return startDiff;
      return (a.value['subject'] ?? '').compareTo(b.value['subject'] ?? '');
    });
    return entries;
  }

  List<MapEntry<int, Map<String, dynamic>>> _revisionWindowsForDay(String day) {
    final entries = <MapEntry<int, Map<String, dynamic>>>[];
    for (int i = 0; i < _revisionWindows.length; i++) {
      final window = _revisionWindows[i];
      if (window['day']?.toString() == day) {
        entries.add(MapEntry(i, window));
      }
    }
    entries.sort((a, b) => (a.value['start']?.toString() ?? '')
        .compareTo(b.value['start']?.toString() ?? ''));
    return entries;
  }

  Future<void> _openSlotEditor({int? index}) async {
    final existing = index != null ? _timetableSlots[index] : null;
    String day = _normalizeDayKey(existing?['day']) ?? _selectedTimetableDay;
    final startController =
        TextEditingController(text: existing?['start']?.trim() ?? '08:30');
    final endController =
        TextEditingController(text: existing?['end']?.trim() ?? '09:30');
    final subjectController =
        TextEditingController(text: existing?['subject']?.trim() ?? '');

    final saved = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        String? validationError;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(index == null ? 'Add period' : 'Edit period'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: day,
                      decoration: const InputDecoration(labelText: 'Day'),
                      items: _weekDays
                          .map((entry) => DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(entry.value),
                              ))
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() => day = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: startController,
                      decoration: const InputDecoration(
                        labelText: 'Start (HH:mm)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: endController,
                      decoration: const InputDecoration(
                        labelText: 'End (HH:mm)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject / period',
                      ),
                    ),
                    if (validationError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        validationError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final normalizedStart =
                        _normalizeTimeText(startController.text);
                    final normalizedEnd =
                        _normalizeTimeText(endController.text);
                    final subject = subjectController.text.trim();
                    if (normalizedStart == null || normalizedEnd == null) {
                      setModalState(() {
                        validationError = 'Use valid 24-hour times like 08:30.';
                      });
                      return;
                    }
                    if (normalizedStart.compareTo(normalizedEnd) >= 0) {
                      setModalState(() {
                        validationError =
                            'End time must be later than start time.';
                      });
                      return;
                    }
                    if (subject.isEmpty) {
                      setModalState(() {
                        validationError = 'Enter a subject or period label.';
                      });
                      return;
                    }
                    Navigator.of(context).pop({
                      'day': day,
                      'start': normalizedStart,
                      'end': normalizedEnd,
                      'subject': subject,
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == null) return;

    setState(() {
      final next = _timetableSlots.toList(growable: true);
      if (index == null) {
        next.add(saved);
      } else {
        next[index] = saved;
      }
      _timetableSlots = _normalizeTimetableSlots(next);
      _selectedTimetableDay = saved['day'] ?? _selectedTimetableDay;
      _timetableMode = _timetableMode == 'none' ? 'manual' : _timetableMode;
      if (_timetableProvider.trim().isEmpty) {
        _timetableProvider = 'manual_editor';
      }
      if (_revisionWindows.isNotEmpty) {
        _revisionWindows = _buildRevisionWindowsFromTimetable();
        _studyRhythmLabel = null;
        _studyRhythmSampleSize = 0;
      }
    });
  }

  String _timetableModeDescription(String mode) {
    switch (mode) {
      case 'manual':
        return 'Use text, image, or camera to build your timetable.';
      case 'sync_pending':
        return 'Analyzing your timetable upload.';
      case 'synced':
        return 'Timetable connected and ready.';
      default:
        return 'No timetable connected yet.';
    }
  }

  void _resetTimetableConnection() {
    setState(() {
      _timetableMode = 'none';
      _timetableProvider = '';
      _timetableSummary = null;
      _timetableSourceText = null;
      _timetableHighlights = const [];
      _timetableSlots = const [];
      _revisionWindows = const [];
      _studyRhythmLabel = null;
      _studyRhythmSampleSize = 0;
      _selectedTimetableDay = 'mon';
    });
  }

  Future<void> _analyzeManualTimetable() async {
    final controller = TextEditingController(text: _timetableSourceText ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Paste school timetable'),
          content: SizedBox(
            width: 500,
            child: TextField(
              controller: controller,
              minLines: 8,
              maxLines: 14,
              decoration: const InputDecoration(
                hintText:
                    'Example:\nMon 08:30-15:20 Maths, English\nTue 09:00-15:30 Biology, Chemistry\n...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                Navigator.of(context).pop(value);
              },
              child: const Text('Analyze'),
            ),
          ],
        );
      },
    );

    if (text == null || text.trim().isEmpty) return;
    await _runTimetableAnalysis(
      modeAfterAnalysis: 'manual',
      providerAfterAnalysis: 'manual_input',
      analyzer: () => TimetableSyncService.analyzeFromManualText(text.trim()),
    );
  }

  Future<void> _analyzeImageTimetable() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
      maxWidth: 2200,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    await _runTimetableAnalysis(
      modeAfterAnalysis: 'synced',
      providerAfterAnalysis: 'school_ocr',
      analyzer: () => TimetableSyncService.analyzeFromImageBytes(bytes),
    );
  }

  Future<void> _scanTimetableWithCamera() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
      maxWidth: 2200,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    await _runTimetableAnalysis(
      modeAfterAnalysis: 'synced',
      providerAfterAnalysis: 'school_ocr_camera',
      analyzer: () => TimetableSyncService.analyzeFromImageBytes(bytes),
    );
  }

  Future<void> _runTimetableAnalysis({
    required Future<TimetablePlanDraft> Function() analyzer,
    required String modeAfterAnalysis,
    required String providerAfterAnalysis,
  }) async {
    if (_analyzingTimetable) return;
    setState(() {
      _analyzingTimetable = true;
      _timetableMode = 'sync_pending';
      _timetableProvider = providerAfterAnalysis;
    });

    try {
      final draft = await analyzer();
      if (!mounted) return;
      setState(() {
        _timetableMode = modeAfterAnalysis;
        _timetableProvider = providerAfterAnalysis;
        _dailyStudyMinutes =
            (draft.weeklyStudyMinutes / 7).round().clamp(10, 180);
        _weeklySessionsTarget = draft.weeklySessionsTarget.clamp(2, 14);
        _timetableSummary = draft.summary;
        _timetableSourceText = draft.extractedText;
        _timetableHighlights = draft.highlights.take(4).toList(growable: false);
        if (draft.timetableSlots.isNotEmpty) {
          _timetableSlots = draft.timetableSlots
              .map((slot) => {
                    'day': slot.day,
                    'start': slot.start,
                    'end': slot.end,
                    'subject': slot.subject,
                  })
              .toList(growable: false);
          _selectedTimetableDay = _timetableSlots.first['day'] ?? 'mon';
          _revisionWindows = _buildRevisionWindowsFromTimetable();
          _studyRhythmLabel = null;
          _studyRhythmSampleSize = 0;
        } else {
          _revisionWindows = const [];
          _studyRhythmLabel = null;
          _studyRhythmSampleSize = 0;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Timetable analyzed. Review values and tap Save timetable plan.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _timetableMode = 'manual';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not analyze timetable: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _analyzingTimetable = false;
        });
      }
    }
  }

  Future<void> _saveTimetablePlan() async {
    if (_savingTimetable) return;
    final overlapCount = _overlapIndicesAllDays().length;
    if (overlapCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Resolve $overlapCount overlapping period${overlapCount == 1 ? '' : 's'} before saving timetable.'),
        ),
      );
      return;
    }
    setState(() {
      _savingTimetable = true;
    });
    try {
      final repo = ref.read(examRepositoryProvider);
      final normalizedProvider = _timetableMode == 'none'
          ? ''
          : (_timetableProvider.trim().isNotEmpty
              ? _timetableProvider.trim()
              : _timetableMode == 'manual'
                  ? 'manual_input'
                  : 'school');
      final syncedAt = _timetableMode == 'synced'
          ? DateTime.now().millisecondsSinceEpoch
          : null;
      final shouldClearTimetableDetails = _timetableMode == 'none';
      await repo.setGcseTimetablePlan(
        timetableMode: _timetableMode,
        timetableProvider: normalizedProvider,
        timetableSyncedAt: syncedAt,
        timetableSummary: _timetableSummary,
        timetableSourceText: _timetableSourceText,
        timetableSlots: _timetableSlots,
        revisionWindows: _revisionWindows,
        clearTimetableSummary: shouldClearTimetableDetails,
        clearTimetableSourceText: shouldClearTimetableDetails,
        clearTimetableSlots: shouldClearTimetableDetails,
        clearRevisionWindows: shouldClearTimetableDetails,
        weeklyStudyMinutes: _dailyStudyMinutes * 7,
        weeklySessionsTarget: _weeklySessionsTarget,
      );
      ref.invalidate(userExamTargetsProvider);
      ref.invalidate(gcseExamHomeProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Timetable plan updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update timetable plan: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingTimetable = false;
        });
      }
    }
  }

  Future<void> _saveSubjectDates(List<Map<String, dynamic>> targets) async {
    if (_savingDates || _dirtyTargets.isEmpty) return;
    setState(() {
      _savingDates = true;
    });

    try {
      final repo = ref.read(examRepositoryProvider);
      for (final target in targets) {
        final targetId = target['_id']?.toString();
        if (targetId == null || !_dirtyTargets.contains(targetId)) continue;
        final mockDate = _mockDatesByTarget[targetId];
        await repo.updateTargetPlanning(
          targetId: targetId,
          mockDateAt: mockDate?.millisecondsSinceEpoch,
          clearMockDate: _clearMockDateForTarget.contains(targetId),
        );
      }

      _dirtyTargets.clear();
      _clearMockDateForTarget.clear();
      ref.invalidate(userExamTargetsProvider);
      ref.invalidate(gcseExamHomeProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mock dates saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save dates: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingDates = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetsAsync = ref.watch(userExamTargetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning & Timetable'),
      ),
      body: targetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Could not load GCSE planning: $error'),
          ),
        ),
        data: (targets) {
          final gcseTargets = targets
              .where((row) =>
                  (row['examFamily']?.toString().toLowerCase() ?? '') == 'gcse')
              .toList()
            ..sort((a, b) {
              final sa = a['subject']?.toString() ?? '';
              final sb = b['subject']?.toString() ?? '';
              return sa.compareTo(sb);
            });

          _seedState(gcseTargets);
          final selectedDaySlots = _slotsForDay(_selectedTimetableDay);
          final selectedDayRevisionWindows =
              _revisionWindowsForDay(_selectedTimetableDay);
          final selectedDayOverlapIndices =
              _overlapIndicesForDay(_selectedTimetableDay);
          final totalOverlapCount = _overlapIndicesAllDays().length;
          final selectedDaySchoolMinutes =
              selectedDaySlots.fold<int>(0, (total, entry) {
            final start = _timeToMinutes(entry.value['start']);
            final end = _timeToMinutes(entry.value['end']);
            if (start == null || end == null || end <= start) return total;
            return total + (end - start);
          });
          final selectedDayHoursLabel =
              (selectedDaySchoolMinutes / 60).toStringAsFixed(1);
          final weeklyRevisionPreview =
              _normalizeRevisionWindows(_revisionWindows)
                  .take(6)
                  .toList(growable: false);
          final canEditTimetable = !_analyzingTimetable && !_savingTimetable;

          if (gcseTargets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Set up GCSE subjects first, then add mock plans and timetable settings.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }

          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color:
                                  colorScheme.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.school_outlined,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'School Timetable & Weekly Capacity',
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  'Set school periods, then generate revision windows.',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _timetableModeDescription(_timetableMode),
                        style: theme.textTheme.bodySmall,
                      ),
                      if (_timetableProvider.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: colorScheme.primary.withValues(alpha: 0.1),
                          ),
                          child: Text(
                            _timetableProvider.replaceAll('_', ' '),
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _PlanningModeBadge(mode: _timetableMode),
                          const Spacer(),
                          if (_timetableMode != 'none')
                            TextButton.icon(
                              onPressed: canEditTimetable
                                  ? _resetTimetableConnection
                                  : null,
                              icon:
                                  const Icon(Icons.link_off_outlined, size: 16),
                              label: const Text('Disconnect'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _PlanningQuickButton(
                            icon: Icons.edit_note_outlined,
                            label: 'Paste text',
                            onTap: canEditTimetable
                                ? _analyzeManualTimetable
                                : null,
                          ),
                          _PlanningQuickButton(
                            icon: Icons.image_search_outlined,
                            label: 'Import image',
                            onTap: canEditTimetable
                                ? _analyzeImageTimetable
                                : null,
                          ),
                          _PlanningQuickButton(
                            icon: Icons.photo_camera_outlined,
                            label: 'Scan camera',
                            onTap: canEditTimetable
                                ? _scanTimetableWithCamera
                                : null,
                          ),
                          if ((_timetableSourceText ?? '').trim().isNotEmpty)
                            _PlanningQuickButton(
                              icon: Icons.edit_outlined,
                              label: 'Edit parsed',
                              onTap: canEditTimetable
                                  ? _analyzeManualTimetable
                                  : null,
                            ),
                        ],
                      ),
                      if (_analyzingTimetable) ...[
                        const SizedBox(height: 10),
                        const LinearProgressIndicator(),
                        const SizedBox(height: 6),
                        Text(
                          'Analyzing timetable with OCR and building your study capacity...',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                      if ((_timetableSummary ?? '').trim().isNotEmpty ||
                          _timetableHighlights.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.22),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Timetable analysis',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              if ((_timetableSummary ?? '')
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _timetableSummary!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              if (_timetableHighlights.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                ..._timetableHighlights.take(3).map(
                                      (line) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          '• $line',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall,
                                        ),
                                      ),
                                    ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Weekly school timetable',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            '${_timetableSlots.length} periods • ${_dayLabel(_selectedTimetableDay)} $selectedDayHoursLabel h',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _weekDays.map((entry) {
                            final dayPeriodCount =
                                _slotsForDay(entry.key).length;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                selected: _selectedTimetableDay == entry.key,
                                label: Text(dayPeriodCount > 0
                                    ? '${entry.value} $dayPeriodCount'
                                    : entry.value),
                                onSelected: (_) {
                                  setState(() {
                                    _selectedTimetableDay = entry.key;
                                  });
                                },
                              ),
                            );
                          }).toList(growable: false),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (selectedDaySlots.isNotEmpty)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.16),
                            border: Border.all(
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            children:
                                selectedDaySlots.asMap().entries.map((row) {
                              final rowIndex = row.key;
                              final entry = row.value;
                              final slot = entry.value;
                              final index = entry.key;
                              final hasOverlap =
                                  selectedDayOverlapIndices.contains(index);
                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 9,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(7),
                                            color: theme.colorScheme.surface
                                                .withValues(alpha: 0.5),
                                          ),
                                          child: Text(
                                            'P${rowIndex + 1}',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            color: hasOverlap
                                                ? theme
                                                    .colorScheme.errorContainer
                                                    .withValues(alpha: 0.5)
                                                : theme.colorScheme.primary
                                                    .withValues(alpha: 0.14),
                                          ),
                                          child: Text(
                                            '${slot['start']}-${slot['end']}',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            slot['subject'] ?? 'Period',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ),
                                        if (hasOverlap)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(right: 4),
                                            child: Icon(
                                              Icons.warning_amber_rounded,
                                              size: 16,
                                              color: theme.colorScheme.error,
                                            ),
                                          ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'Edit period',
                                          onPressed: () =>
                                              _openSlotEditor(index: index),
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                          ),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'Delete period',
                                          onPressed: () {
                                            setState(() {
                                              final next = _timetableSlots
                                                  .toList(growable: true);
                                              next.removeAt(index);
                                              _timetableSlots =
                                                  _normalizeTimetableSlots(
                                                      next);
                                              if (_revisionWindows.isNotEmpty) {
                                                _revisionWindows =
                                                    _buildRevisionWindowsFromTimetable();
                                                _studyRhythmLabel = null;
                                                _studyRhythmSampleSize = 0;
                                              }
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (rowIndex < selectedDaySlots.length - 1)
                                    Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: theme.colorScheme.outline
                                          .withValues(alpha: 0.14),
                                    ),
                                ],
                              );
                            }).toList(growable: false),
                          ),
                        ),
                      if (selectedDaySlots.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: 0.35),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.18),
                            ),
                          ),
                          child: Text(
                            'No periods set for ${_dayLabel(_selectedTimetableDay)}. Add one below or import a timetable image.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      if (selectedDayOverlapIndices.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Theme.of(context)
                                .colorScheme
                                .errorContainer
                                .withValues(alpha: 0.36),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .error
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            '${selectedDayOverlapIndices.length} overlapping period${selectedDayOverlapIndices.length == 1 ? '' : 's'} on ${_dayLabel(_selectedTimetableDay)}. Edit times so periods do not collide.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                      if (totalOverlapCount > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Total overlaps across week: $totalOverlapCount (saving is disabled until resolved).',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Quick templates',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _analyzingTimetable
                                ? null
                                : () => _applyTimetableTemplate(
                                      templateName:
                                          'Standard Mon-Fri (6 periods)',
                                      slots: _standardTemplateSlots(),
                                    ),
                            icon: const Icon(Icons.table_rows_outlined),
                            label: const Text('Standard school day'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _analyzingTimetable
                                ? null
                                : () => _applyTimetableTemplate(
                                      templateName:
                                          'Compact Mon-Fri (4 periods)',
                                      slots: _compactTemplateSlots(),
                                    ),
                            icon: const Icon(Icons.view_day_outlined),
                            label: const Text('Compact day'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _analyzingTimetable
                                ? null
                                : () => _openSlotEditor(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add period'),
                          ),
                          if (selectedDaySlots.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: _analyzingTimetable
                                  ? null
                                  : () {
                                      setState(() {
                                        _timetableSlots = _timetableSlots
                                            .where((slot) =>
                                                slot['day'] !=
                                                _selectedTimetableDay)
                                            .toList(growable: false);
                                        if (_revisionWindows.isNotEmpty) {
                                          _revisionWindows =
                                              _buildRevisionWindowsFromTimetable();
                                          _studyRhythmLabel = null;
                                          _studyRhythmSampleSize = 0;
                                        }
                                      });
                                    },
                              icon: const Icon(Icons.clear_all_outlined),
                              label: const Text('Clear day'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Suggested revision windows',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _analyzingTimetable ||
                                    _generatingRevisionWindows
                                ? null
                                : _generateRevisionWindows,
                            icon: const Icon(Icons.auto_fix_high_outlined),
                            label: Text(_generatingRevisionWindows
                                ? 'Generating...'
                                : 'Generate'),
                          ),
                        ],
                      ),
                      if (_revisionWindows.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.1),
                              ),
                              child: Text(
                                '${_revisionWindows.length} windows this week',
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                            if (_studyRhythmLabel != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: theme.colorScheme.secondary
                                      .withValues(alpha: 0.12),
                                ),
                                child: Text(
                                  _studyRhythmSampleSize >= 6
                                      ? 'Adapted to your $_studyRhythmLabel rhythm'
                                      : 'Using default balanced rhythm',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      if (selectedDayRevisionWindows.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: 0.35),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.18),
                            ),
                          ),
                          child: Text(
                            _revisionWindows.isEmpty
                                ? 'No revision windows generated yet. Tap Generate to convert school periods into revision slots.'
                                : 'No revision windows on ${_dayLabel(_selectedTimetableDay)}.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        )
                      else
                        ...selectedDayRevisionWindows.map((entry) {
                          final row = entry.value;
                          final index = entry.key;
                          final duration =
                              (row['durationMinutes'] as num?)?.toInt() ?? 0;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.3),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.28),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${row['start']}-${row['end']} • ${duration}m ${_dayLabel(row['day']?.toString() ?? _selectedTimetableDay)}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Remove window',
                                  onPressed: () {
                                    setState(() {
                                      final next = _revisionWindows.toList(
                                          growable: true);
                                      next.removeAt(index);
                                      _revisionWindows =
                                          _normalizeRevisionWindows(next);
                                    });
                                  },
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18),
                                ),
                              ],
                            ),
                          );
                        }),
                      if (weeklyRevisionPreview.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Week overview',
                          style: theme.textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        ...weeklyRevisionPreview.map((window) {
                          final duration =
                              (window['durationMinutes'] as num?)?.toInt() ?? 0;
                          final day =
                              _dayLabel(window['day']?.toString() ?? '');
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '$day • ${window['start']}-${window['end']} • ${duration}m',
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        }),
                      ],
                      if (_revisionWindows.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _analyzingTimetable ||
                                      _generatingRevisionWindows
                                  ? null
                                  : () {
                                      setState(() {
                                        _revisionWindows = _revisionWindows
                                            .where((window) =>
                                                window['day']?.toString() !=
                                                _selectedTimetableDay)
                                            .toList(growable: false);
                                      });
                                    },
                              icon: const Icon(Icons.clear_all_outlined),
                              label: const Text('Clear day windows'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _analyzingTimetable ||
                                      _generatingRevisionWindows
                                  ? null
                                  : () {
                                      setState(() {
                                        _revisionWindows = const [];
                                        _studyRhythmLabel = null;
                                        _studyRhythmSampleSize = 0;
                                      });
                                    },
                              icon: const Icon(Icons.layers_clear_outlined),
                              label: const Text('Clear all windows'),
                            ),
                          ],
                        ),
                      ],
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
                      const SizedBox(height: 6),
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
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _savingTimetable || totalOverlapCount > 0
                            ? null
                            : _saveTimetablePlan,
                        icon: const Icon(Icons.schedule_outlined),
                        label: Text(_savingTimetable
                            ? 'Saving timetable...'
                            : totalOverlapCount > 0
                                ? 'Resolve overlaps to save'
                                : 'Save timetable plan'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Mock planning by subject',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...gcseTargets.map((target) {
                final targetId = target['_id']?.toString() ?? '';
                if (targetId.isEmpty) return const SizedBox.shrink();

                final subject = target['subject']?.toString() ?? 'Subject';
                final board = target['board']?.toString() ?? '';
                final level = target['level']?.toString() ?? '';
                final mockDate = _mockDatesByTarget[targetId];

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
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
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ActionChip(
                              label: const Text('~4 weeks'),
                              onPressed: () {
                                setState(() {
                                  _mockDatesByTarget[targetId] = DateTime.now()
                                      .add(const Duration(days: 28));
                                  _clearMockDateForTarget.remove(targetId);
                                  _dirtyTargets.add(targetId);
                                });
                              },
                            ),
                            ActionChip(
                              label: const Text('~8 weeks'),
                              onPressed: () {
                                setState(() {
                                  _mockDatesByTarget[targetId] = DateTime.now()
                                      .add(const Duration(days: 56));
                                  _clearMockDateForTarget.remove(targetId);
                                  _dirtyTargets.add(targetId);
                                });
                              },
                            ),
                            ActionChip(
                              label: const Text('~12 weeks'),
                              onPressed: () {
                                setState(() {
                                  _mockDatesByTarget[targetId] = DateTime.now()
                                      .add(const Duration(days: 84));
                                  _clearMockDateForTarget.remove(targetId);
                                  _dirtyTargets.add(targetId);
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.2),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mock date',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDate(mockDate),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final selected = await _pickDate(mockDate);
                                  if (selected == null) return;
                                  setState(() {
                                    _mockDatesByTarget[targetId] = selected;
                                    _clearMockDateForTarget.remove(targetId);
                                    _dirtyTargets.add(targetId);
                                  });
                                },
                                icon: const Icon(Icons.event_outlined),
                                label: const Text('Choose'),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: 'Clear mock date',
                                onPressed: () {
                                  setState(() {
                                    _mockDatesByTarget[targetId] = null;
                                    _clearMockDateForTarget.add(targetId);
                                    _dirtyTargets.add(targetId);
                                  });
                                },
                                icon: const Icon(Icons.clear),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _savingDates || _dirtyTargets.isEmpty
                    ? null
                    : () => _saveSubjectDates(gcseTargets),
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  _savingDates
                      ? 'Saving mock plans...'
                      : _dirtyTargets.isEmpty
                          ? 'No mock changes'
                          : 'Save mock plans',
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _PlanningModeBadge extends StatelessWidget {
  final String mode;

  const _PlanningModeBadge({required this.mode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    IconData icon;
    String label;
    switch (mode) {
      case 'manual':
        icon = Icons.edit_note_outlined;
        label = 'Manual';
        break;
      case 'sync_pending':
        icon = Icons.sync_outlined;
        label = 'Analyzing';
        break;
      case 'synced':
        icon = Icons.cloud_done_outlined;
        label = 'Synced';
        break;
      default:
        icon = Icons.link_off_outlined;
        label = 'Not connected';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _PlanningQuickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _PlanningQuickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final enabled = onTap != null;
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        side: BorderSide(
          color: enabled
              ? colorScheme.outline.withValues(alpha: 0.26)
              : colorScheme.outline.withValues(alpha: 0.14),
        ),
      ),
      icon: Icon(
        icon,
        size: 16,
        color: enabled
            ? colorScheme.primary
            : colorScheme.onSurface.withValues(alpha: 0.45),
      ),
      label: Text(
        label,
        style: theme.textTheme.labelLarge,
      ),
    );
  }
}
