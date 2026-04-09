import 'package:neurobits/services/convex_client_service.dart';

class ExamRepository {
  final ConvexClientService _client;
  static bool _catalogEndpointUnavailable = false;
  static int _catalogEndpointRetryAfterMs = 0;
  static bool _catalogSupportsCoreOnly = true;
  static const int _catalogRetryCooldownMs = 60 * 1000;

  static const Map<String, String> _gcseCoreBoardBySubject = <String, String>{
    'mathematics': 'pearson edexcel',
    'english language': 'aqa',
    'english literature': 'aqa',
    'biology': 'aqa',
    'chemistry': 'aqa',
    'physics': 'aqa',
  };

  static const List<Map<String, dynamic>> _localCatalog = [
    {
      'slug': 'gb-gcse-pearson-edexcel-mathematics',
      'displayName': 'GCSE Mathematics - Pearson Edexcel',
      'countryCode': 'GB',
      'countryName': 'United Kingdom',
      'examFamily': 'gcse',
      'board': 'Pearson Edexcel',
      'level': 'GCSE',
      'subject': 'Mathematics',
      'aliases': ['GCSE Maths Edexcel', 'Edexcel Maths', 'GCSE Mathematics'],
      'isActive': true,
    },
    {
      'slug': 'gb-gcse-aqa-english-language',
      'displayName': 'GCSE English Language - AQA',
      'countryCode': 'GB',
      'countryName': 'United Kingdom',
      'examFamily': 'gcse',
      'board': 'AQA',
      'level': 'GCSE',
      'subject': 'English Language',
      'aliases': [
        'GCSE English Language AQA',
        'AQA English Language',
      ],
      'isActive': true,
    },
    {
      'slug': 'gb-gcse-aqa-english-literature',
      'displayName': 'GCSE English Literature - AQA',
      'countryCode': 'GB',
      'countryName': 'United Kingdom',
      'examFamily': 'gcse',
      'board': 'AQA',
      'level': 'GCSE',
      'subject': 'English Literature',
      'aliases': [
        'GCSE English Literature AQA',
        'AQA English Literature',
      ],
      'isActive': true,
    },
    {
      'slug': 'gb-gcse-aqa-biology',
      'displayName': 'GCSE Biology - AQA',
      'countryCode': 'GB',
      'countryName': 'United Kingdom',
      'examFamily': 'gcse',
      'board': 'AQA',
      'level': 'GCSE',
      'subject': 'Biology',
      'aliases': ['GCSE Biology AQA', 'AQA Biology'],
      'isActive': true,
    },
    {
      'slug': 'gb-gcse-aqa-chemistry',
      'displayName': 'GCSE Chemistry - AQA',
      'countryCode': 'GB',
      'countryName': 'United Kingdom',
      'examFamily': 'gcse',
      'board': 'AQA',
      'level': 'GCSE',
      'subject': 'Chemistry',
      'aliases': ['GCSE Chemistry AQA', 'AQA Chemistry'],
      'isActive': true,
    },
    {
      'slug': 'gb-gcse-aqa-physics',
      'displayName': 'GCSE Physics - AQA',
      'countryCode': 'GB',
      'countryName': 'United Kingdom',
      'examFamily': 'gcse',
      'board': 'AQA',
      'level': 'GCSE',
      'subject': 'Physics',
      'aliases': ['GCSE Physics AQA', 'AQA Physics'],
      'isActive': true,
    },
  ];

  ExamRepository(this._client);

  bool _isCoreGcseEntry(Map<String, dynamic> entry) {
    final family = (entry['examFamily']?.toString() ?? '').trim().toLowerCase();
    final country =
        (entry['countryCode']?.toString() ?? '').trim().toUpperCase();
    final subject = (entry['subject']?.toString() ?? '').trim().toLowerCase();
    final board = (entry['board']?.toString() ?? '').trim().toLowerCase();
    if (family != 'gcse' || country != 'GB') return false;
    final expectedBoard = _gcseCoreBoardBySubject[subject];
    if (expectedBoard == null) return false;
    return board == expectedBoard;
  }

  List<Map<String, dynamic>> _filterCatalogItems(
    List<Map<String, dynamic>> items, {
    String? countryCode,
    String? examFamily,
    String? subject,
    String? query,
    bool coreOnly = false,
    int limit = 120,
  }) {
    final country = countryCode?.trim().toUpperCase();
    final family = examFamily?.trim().toLowerCase();
    final subjectNeedle = subject?.trim().toLowerCase();
    final q = query?.trim().toLowerCase() ?? '';
    final filtered = items.where((entry) {
      if (coreOnly && !_isCoreGcseEntry(entry)) return false;
      if (country != null && country.isNotEmpty) {
        if ((entry['countryCode']?.toString() ?? '').trim().toUpperCase() !=
            country) {
          return false;
        }
      }
      if (family != null && family.isNotEmpty) {
        if ((entry['examFamily']?.toString() ?? '').trim().toLowerCase() !=
            family) {
          return false;
        }
      }
      if (subjectNeedle != null && subjectNeedle.isNotEmpty) {
        if (!(entry['subject']?.toString() ?? '')
            .toLowerCase()
            .contains(subjectNeedle)) {
          return false;
        }
      }
      if (q.isEmpty) return true;
      final aliases = entry['aliases'] is List
          ? (entry['aliases'] as List)
              .map((v) => v.toString())
              .where((v) => v.trim().isNotEmpty)
              .toList()
          : const <String>[];
      final haystack = [
        entry['displayName']?.toString() ?? '',
        entry['countryName']?.toString() ?? '',
        entry['countryCode']?.toString() ?? '',
        entry['examFamily']?.toString() ?? '',
        entry['board']?.toString() ?? '',
        entry['level']?.toString() ?? '',
        entry['subject']?.toString() ?? '',
        ...aliases,
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();

    return filtered.take(limit.clamp(1, 2000)).toList();
  }

  List<Map<String, dynamic>> _localCatalogFiltered({
    String? countryCode,
    String? examFamily,
    String? subject,
    String? query,
    bool coreOnly = false,
    int limit = 120,
  }) {
    final items = _localCatalog
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    return _filterCatalogItems(
      items,
      countryCode: countryCode,
      examFamily: examFamily,
      subject: subject,
      query: query,
      coreOnly: coreOnly,
      limit: limit,
    );
  }

  bool _shouldUseLocalCatalogOnly() {
    if (!_catalogEndpointUnavailable) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now >= _catalogEndpointRetryAfterMs) {
      _catalogEndpointUnavailable = false;
      return false;
    }
    return true;
  }

  void _markCatalogEndpointUnavailable() {
    _catalogEndpointUnavailable = true;
    _catalogEndpointRetryAfterMs =
        DateTime.now().millisecondsSinceEpoch + _catalogRetryCooldownMs;
  }

  void _markCatalogEndpointHealthy() {
    _catalogEndpointUnavailable = false;
    _catalogEndpointRetryAfterMs = 0;
  }

  Future<List<Map<String, dynamic>>> listCatalog({
    String? countryCode,
    String? examFamily,
    String? subject,
    String? query,
    bool coreOnly = false,
    int limit = 120,
  }) async {
    if (_shouldUseLocalCatalogOnly()) {
      return _localCatalogFiltered(
        countryCode: countryCode,
        examFamily: examFamily,
        subject: subject,
        query: query,
        coreOnly: coreOnly,
        limit: limit,
      );
    }

    final baseArgs = <String, dynamic>{
      if (countryCode != null && countryCode.trim().isNotEmpty)
        'countryCode': countryCode.trim(),
      if (examFamily != null && examFamily.trim().isNotEmpty)
        'examFamily': examFamily.trim(),
      if (subject != null && subject.trim().isNotEmpty)
        'subject': subject.trim(),
      if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
      'limit': limit,
    };

    Map<String, dynamic> map;
    bool usedCoreOnlyArg = coreOnly && _catalogSupportsCoreOnly;
    try {
      final result = await _client.query(name: 'exams:listCatalog', args: {
        ...baseArgs,
        if (usedCoreOnlyArg) 'coreOnly': true,
      });
      map = toMap(result);
    } catch (e) {
      if (coreOnly && usedCoreOnlyArg) {
        _catalogSupportsCoreOnly = false;
        usedCoreOnlyArg = false;
        try {
          final fallback = await _client.query(
            name: 'exams:listCatalog',
            args: baseArgs,
          );
          map = toMap(fallback);
          _markCatalogEndpointHealthy();
        } catch (_) {
          _markCatalogEndpointUnavailable();
          return _localCatalogFiltered(
            countryCode: countryCode,
            examFamily: examFamily,
            subject: subject,
            query: query,
            coreOnly: coreOnly,
            limit: limit,
          );
        }
      } else {
        _markCatalogEndpointUnavailable();
        return _localCatalogFiltered(
          countryCode: countryCode,
          examFamily: examFamily,
          subject: subject,
          query: query,
          coreOnly: coreOnly,
          limit: limit,
        );
      }
    }

    _markCatalogEndpointHealthy();

    final items = map['items'];
    if (!isConvexList(items)) {
      return _localCatalogFiltered(
        countryCode: countryCode,
        examFamily: examFamily,
        subject: subject,
        query: query,
        coreOnly: coreOnly,
        limit: limit,
      );
    }
    final rows = toMapList(items);
    return _filterCatalogItems(
      rows,
      countryCode: countryCode,
      examFamily: examFamily,
      subject: subject,
      query: query,
      coreOnly: coreOnly,
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> resolveIntent(
    String text, {
    int limit = 5,
  }) async {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return const [];

    if (_shouldUseLocalCatalogOnly()) {
      final local = _localCatalogFiltered(
        query: normalized,
        limit: limit,
      );
      return local
          .map((entry) => {
                'entry': entry,
                'score': 1.0,
                'confidence': 0.5,
                'matchedTokens': <String>[normalized],
              })
          .toList();
    }

    try {
      final result = await _client.query(
        name: 'exams:resolveIntent',
        args: {
          'text': text,
          'limit': limit,
        },
      );
      final map = toMap(result);
      final items = map['items'];
      if (!isConvexList(items)) return const [];
      _markCatalogEndpointHealthy();
      return toMapList(items);
    } catch (_) {
      _markCatalogEndpointUnavailable();
      final local = _localCatalogFiltered(
        query: normalized,
        limit: limit,
      );
      return local
          .map((entry) => {
                'entry': entry,
                'score': 1.0,
                'confidence': 0.5,
                'matchedTokens': <String>[normalized],
              })
          .toList();
    }
  }

  Future<Map<String, dynamic>> getCatalogStatus() async {
    final result = await _client.query(name: 'exams:getCatalogStatus');
    return toMap(result);
  }

  Future<Map<String, dynamic>> bulkUpsertCatalog({
    required List<Map<String, dynamic>> entries,
    bool replaceExisting = false,
  }) async {
    final result = await _client.mutation(
      name: 'exams:bulkUpsertCatalog',
      args: {
        'entries': entries,
        'replaceExisting': replaceExisting,
      },
    );
    return toMap(result);
  }

  Future<Map<String, dynamic>> bulkUpsertKnowledge({
    required List<Map<String, dynamic>> entries,
    bool replaceExisting = false,
  }) async {
    final result = await _client.mutation(
      name: 'exams:bulkUpsertKnowledge',
      args: {
        'entries': entries,
        'replaceExisting': replaceExisting,
      },
    );
    return toMap(result);
  }

  Future<Map<String, dynamic>?> getMyTarget() async {
    final result = await _client.query(name: 'exams:getMyTarget');
    return toMapOrNull(result);
  }

  Future<Map<String, dynamic>?> getMyTargetById({
    required String targetId,
  }) async {
    final result = await _client.query(
      name: 'exams:getMyTargetById',
      args: {'targetId': targetId},
    );
    return toMapOrNull(result);
  }

  Future<List<Map<String, dynamic>>> listMyTargets() async {
    final result = await _client.query(name: 'exams:listMyTargets');
    if (!isConvexList(result)) return const [];
    return toMapList(result);
  }

  Future<void> setActiveTarget({required String targetId}) async {
    await _client.mutation(
      name: 'exams:setActiveTarget',
      args: {'targetId': targetId},
    );
  }

  Future<void> archiveTarget({required String targetId}) async {
    await _client.mutation(
      name: 'exams:archiveTarget',
      args: {'targetId': targetId},
    );
  }

  Future<void> upsertMyTarget({
    required String countryCode,
    required String countryName,
    required String examFamily,
    required String board,
    required String level,
    required String subject,
    int? year,
    String? currentGrade,
    String? targetGrade,
    int? mockDateAt,
    int? examDateAt,
    String? timetableMode,
    String? timetableProvider,
    int? timetableSyncedAt,
    String? timetableSummary,
    String? timetableSourceText,
    List<Map<String, String>>? timetableSlots,
    List<Map<String, dynamic>>? revisionWindows,
    int? weeklyStudyMinutes,
    int? weeklySessionsTarget,
    String? intentQuery,
    String? sourceCatalogSlug,
    bool makeActive = true,
  }) async {
    await _client.mutation(
      name: 'exams:upsertMyTarget',
      args: {
        'countryCode': countryCode,
        'countryName': countryName,
        'examFamily': examFamily,
        'board': board,
        'level': level,
        'subject': subject,
        'makeActive': makeActive,
        if (year != null) 'year': year,
        if (currentGrade != null && currentGrade.trim().isNotEmpty)
          'currentGrade': currentGrade.trim(),
        if (targetGrade != null && targetGrade.trim().isNotEmpty)
          'targetGrade': targetGrade.trim(),
        if (mockDateAt != null) 'mockDateAt': mockDateAt,
        if (examDateAt != null) 'examDateAt': examDateAt,
        if (timetableMode != null && timetableMode.trim().isNotEmpty)
          'timetableMode': timetableMode.trim(),
        if (timetableProvider != null && timetableProvider.trim().isNotEmpty)
          'timetableProvider': timetableProvider.trim(),
        if (timetableSyncedAt != null) 'timetableSyncedAt': timetableSyncedAt,
        if (timetableSummary != null && timetableSummary.trim().isNotEmpty)
          'timetableSummary': timetableSummary.trim(),
        if (timetableSourceText != null &&
            timetableSourceText.trim().isNotEmpty)
          'timetableSourceText': timetableSourceText.trim(),
        if (timetableSlots != null) 'timetableSlots': timetableSlots,
        if (revisionWindows != null) 'revisionWindows': revisionWindows,
        if (weeklyStudyMinutes != null)
          'weeklyStudyMinutes': weeklyStudyMinutes,
        if (weeklySessionsTarget != null)
          'weeklySessionsTarget': weeklySessionsTarget,
        if (intentQuery != null && intentQuery.trim().isNotEmpty)
          'intentQuery': intentQuery.trim(),
        if (sourceCatalogSlug != null && sourceCatalogSlug.trim().isNotEmpty)
          'sourceCatalogSlug': sourceCatalogSlug.trim(),
      },
    );
  }

  Future<void> updateTargetGrades({
    required String targetId,
    String? currentGrade,
    String? targetGrade,
  }) async {
    await _client.mutation(
      name: 'exams:updateTargetGrades',
      args: {
        'targetId': targetId,
        if (currentGrade != null && currentGrade.trim().isNotEmpty)
          'currentGrade': currentGrade.trim(),
        if (targetGrade != null && targetGrade.trim().isNotEmpty)
          'targetGrade': targetGrade.trim(),
      },
    );
  }

  Future<void> updateTargetPlanning({
    required String targetId,
    int? mockDateAt,
    int? examDateAt,
    String? timetableMode,
    String? timetableProvider,
    int? timetableSyncedAt,
    String? timetableSummary,
    String? timetableSourceText,
    List<Map<String, String>>? timetableSlots,
    List<Map<String, dynamic>>? revisionWindows,
    int? weeklyStudyMinutes,
    int? weeklySessionsTarget,
    bool clearMockDate = false,
    bool clearExamDate = false,
  }) async {
    await _client.mutation(
      name: 'exams:updateTargetPlanning',
      args: {
        'targetId': targetId,
        if (clearMockDate)
          'mockDateAt': null
        else if (mockDateAt != null)
          'mockDateAt': mockDateAt,
        if (clearExamDate)
          'examDateAt': null
        else if (examDateAt != null)
          'examDateAt': examDateAt,
        if (timetableMode != null) 'timetableMode': timetableMode,
        if (timetableProvider != null) 'timetableProvider': timetableProvider,
        if (timetableSyncedAt != null) 'timetableSyncedAt': timetableSyncedAt,
        if (timetableSummary != null) 'timetableSummary': timetableSummary,
        if (timetableSourceText != null)
          'timetableSourceText': timetableSourceText,
        if (timetableSlots != null) 'timetableSlots': timetableSlots,
        if (revisionWindows != null) 'revisionWindows': revisionWindows,
        if (weeklyStudyMinutes != null)
          'weeklyStudyMinutes': weeklyStudyMinutes,
        if (weeklySessionsTarget != null)
          'weeklySessionsTarget': weeklySessionsTarget,
      },
    );
  }

  Future<int> setGcseTimetablePlan({
    String? timetableMode,
    String? timetableProvider,
    int? timetableSyncedAt,
    String? timetableSummary,
    String? timetableSourceText,
    List<Map<String, String>>? timetableSlots,
    List<Map<String, dynamic>>? revisionWindows,
    bool clearTimetableSummary = false,
    bool clearTimetableSourceText = false,
    bool clearTimetableSlots = false,
    bool clearRevisionWindows = false,
    int? weeklyStudyMinutes,
    int? weeklySessionsTarget,
  }) async {
    final result = await _client.mutation(
      name: 'exams:setGcseTimetablePlan',
      args: {
        if (timetableMode != null) 'timetableMode': timetableMode,
        if (timetableProvider != null) 'timetableProvider': timetableProvider,
        if (timetableSyncedAt != null) 'timetableSyncedAt': timetableSyncedAt,
        if (clearTimetableSummary)
          'timetableSummary': null
        else if (timetableSummary != null)
          'timetableSummary': timetableSummary,
        if (clearTimetableSourceText)
          'timetableSourceText': null
        else if (timetableSourceText != null)
          'timetableSourceText': timetableSourceText,
        if (clearTimetableSlots)
          'timetableSlots': null
        else if (timetableSlots != null)
          'timetableSlots': timetableSlots,
        if (clearRevisionWindows)
          'revisionWindows': null
        else if (revisionWindows != null)
          'revisionWindows': revisionWindows,
        if (weeklyStudyMinutes != null)
          'weeklyStudyMinutes': weeklyStudyMinutes,
        if (weeklySessionsTarget != null)
          'weeklySessionsTarget': weeklySessionsTarget,
      },
    );
    return convexInt(toMap(result)['updatedTargets']);
  }

  Future<void> clearMyTarget() async {
    await _client.mutation(name: 'exams:clearMyTarget');
  }

  Future<Map<String, dynamic>> getMyStudyTimeProfile({
    String? targetId,
    int? timezoneOffsetMinutes,
  }) async {
    final result = await _client.query(
      name: 'exams:getMyStudyTimeProfile',
      args: {
        if (targetId != null && targetId.trim().isNotEmpty)
          'targetId': targetId.trim(),
        if (timezoneOffsetMinutes != null)
          'timezoneOffsetMinutes': timezoneOffsetMinutes,
      },
    );
    return toMap(result);
  }

  Future<Map<String, dynamic>> getMyExamDashboard({
    String? targetId,
  }) async {
    final result = await _client.query(
      name: 'exams:getMyExamDashboard',
      args: {
        if (targetId != null && targetId.trim().isNotEmpty)
          'targetId': targetId.trim(),
      },
    );
    return toMap(result);
  }

  Future<Map<String, dynamic>> getMyExamProfile({
    required String targetId,
  }) async {
    final result = await _client.query(
      name: 'exams:getMyExamProfile',
      args: {'targetId': targetId},
    );
    return toMap(result);
  }

  Future<Map<String, dynamic>> getMyExamSubjectReport({
    required String targetId,
    required String period,
  }) async {
    final result = await _client.query(
      name: 'exams:getMyExamSubjectReport',
      args: {
        'targetId': targetId,
        'period': period,
      },
    );
    return toMap(result);
  }

  Future<Map<String, dynamic>> getGcseExamHome() async {
    final result = await _client.query(name: 'exams:getGcseExamHome');
    return toMap(result);
  }
}
