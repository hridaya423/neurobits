import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class TimetableSlotDraft {
  final String day;
  final String start;
  final String end;
  final String subject;

  const TimetableSlotDraft({
    required this.day,
    required this.start,
    required this.end,
    required this.subject,
  });
}

class TimetablePlanDraft {
  final int weeklyStudyMinutes;
  final int weeklySessionsTarget;
  final int schoolDaysPerWeek;
  final int averageSchoolHoursPerDay;
  final String summary;
  final List<String> highlights;
  final String extractedText;
  final List<TimetableSlotDraft> timetableSlots;

  const TimetablePlanDraft({
    required this.weeklyStudyMinutes,
    required this.weeklySessionsTarget,
    required this.schoolDaysPerWeek,
    required this.averageSchoolHoursPerDay,
    required this.summary,
    required this.highlights,
    required this.extractedText,
    required this.timetableSlots,
  });
}

class TimetableSyncService {
  static const String _apiKeyEnvName = 'OPENROUTER_API_KEY';
  static const String _chatCompletionsUrl =
      'https://ai.hackclub.com/proxy/v1/chat/completions';
  static const String _replicateBaseUrl =
      'https://ai.hackclub.com/proxy/v1/replicate';
  static const String _analysisModel = 'google/gemini-3-flash-preview';
  static const String _replicateModelSlug = 'lucataco/deepseek-ocr';

  TimetableSyncService._();

  static Future<TimetablePlanDraft> analyzeFromManualText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw Exception('Timetable text is empty.');
    }
    return _analyzeExtractedText(trimmed);
  }

  static Future<TimetablePlanDraft> analyzeFromImageBytes(
      Uint8List bytes) async {
    if (bytes.isEmpty) {
      throw Exception('Image is empty.');
    }
    final extracted = await _extractTextWithDeepSeekOcr(bytes);
    if (extracted.trim().isEmpty) {
      throw Exception('OCR returned no readable text.');
    }
    return _analyzeExtractedText(extracted);
  }

  static String _resolveApiKey() {
    final envKey = dotenv.isInitialized ? dotenv.env[_apiKeyEnvName] : null;
    const definedKey = String.fromEnvironment(_apiKeyEnvName, defaultValue: '');
    final apiKey = definedKey.isNotEmpty ? definedKey : envKey;
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw Exception('$_apiKeyEnvName is not configured.');
    }
    return apiKey.trim();
  }

  static Map<String, String> _jsonHeaders(String apiKey) {
    return {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
  }

  static Future<String> _extractTextWithDeepSeekOcr(Uint8List bytes) async {
    final apiKey = _resolveApiKey();
    final dataUri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    try {
      final createUri = Uri.parse(
          '$_replicateBaseUrl/models/$_replicateModelSlug/predictions');

      final createResponse = await http
          .post(
            createUri,
            headers: _jsonHeaders(apiKey),
            body: jsonEncode({
              'input': {
                'image': dataUri,
              },
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (createResponse.statusCode >= 400) {
        throw Exception(
          'OCR request failed (${createResponse.statusCode}): ${createResponse.body}',
        );
      }

      final created = _toJsonMap(createResponse.body);
      if (created['output'] != null) {
        return _resolveOcrOutputText(created['output'], apiKey);
      }

      final predictionId = created['id']?.toString().trim() ?? '';
      if (predictionId.isEmpty) {
        throw Exception('OCR request did not return a prediction id.');
      }

      final statusUri = created['urls'] is Map &&
              (created['urls'] as Map)['get']?.toString().trim().isNotEmpty ==
                  true
          ? Uri.parse((created['urls'] as Map)['get'].toString().trim())
          : Uri.parse('$_replicateBaseUrl/predictions/$predictionId');

      for (int attempt = 0; attempt < 30; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 900));
        }
        final statusResponse = await http
            .get(statusUri, headers: _jsonHeaders(apiKey))
            .timeout(const Duration(seconds: 30));

        if (statusResponse.statusCode >= 400) {
          throw Exception(
            'OCR status polling failed (${statusResponse.statusCode}).',
          );
        }

        final statusMap = _toJsonMap(statusResponse.body);
        final status = statusMap['status']?.toString().toLowerCase() ?? '';

        if (status == 'succeeded' || status == 'completed') {
          return _resolveOcrOutputText(statusMap['output'], apiKey);
        }

        if (status == 'failed' ||
            status == 'canceled' ||
            status == 'cancelled') {
          final error = statusMap['error']?.toString().trim();
          throw Exception(
              error?.isNotEmpty == true ? 'OCR failed: $error' : 'OCR failed.');
        }
      }

      throw Exception('OCR timed out. Please try again.');
    } catch (error) {
      debugPrint(
          '[TimetableSync] Replicate OCR failed, using vision fallback: $error');
      final fallback = await _extractTextWithVisionFallback(dataUri, apiKey);
      if (fallback.trim().isNotEmpty) return fallback.trim();
      rethrow;
    }
  }

  static Future<String> _extractTextWithVisionFallback(
      String imageDataUri, String apiKey) async {
    final response = await http
        .post(
          Uri.parse(_chatCompletionsUrl),
          headers: _jsonHeaders(apiKey),
          body: jsonEncode({
            'model': _analysisModel,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'text',
                    'text':
                        'Extract all timetable text from this image. Return plain text only, preserving day/time lines. No explanation.'
                  },
                  {
                    'type': 'image_url',
                    'image_url': {'url': imageDataUri}
                  }
                ],
              }
            ],
            'temperature': 0,
            'max_tokens': 2000,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode >= 400) {
      throw Exception(
        'Vision OCR fallback failed (${response.statusCode}): ${response.body}',
      );
    }

    final payload = _toJsonMap(response.body);
    final choices = payload['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final message = first['message'];
        if (message is Map) {
          return message['content']?.toString().trim() ?? '';
        }
      }
    }
    return '';
  }

  static Future<String> _resolveOcrOutputText(
      dynamic output, String apiKey) async {
    final raw = _coerceReplicateOutput(output);
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      try {
        final response = await http.get(Uri.parse(raw), headers: {
          'Authorization': 'Bearer $apiKey'
        }).timeout(const Duration(seconds: 30));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response.body.trim();
        }
      } catch (_) {
        // Fall back to raw output.
      }
    }
    return raw;
  }

  static String _coerceReplicateOutput(dynamic output) {
    if (output == null) return '';
    if (output is String) {
      final trimmed = output.trim();
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return trimmed;
      }
      return trimmed;
    }
    if (output is List) {
      final parts = output
          .map(_coerceReplicateOutput)
          .where((part) => part.trim().isNotEmpty)
          .toList(growable: false);
      return parts.join('\n\n').trim();
    }
    if (output is Map) {
      for (final key in const ['text', 'markdown', 'content', 'output']) {
        if (output[key] != null) {
          return _coerceReplicateOutput(output[key]);
        }
      }
    }
    return output.toString().trim();
  }

  static Future<TimetablePlanDraft> _analyzeExtractedText(
      String extractedText) async {
    final apiKey = _resolveApiKey();
    final trimmed = extractedText.trim();
    final cappedText =
        trimmed.length > 12000 ? trimmed.substring(0, 12000) : trimmed;

    final prompt = '''
You are a timetable analyst for GCSE students.
Read this school timetable text and return JSON only.

Return keys:
- schoolDaysPerWeek (1-7 integer)
- averageSchoolHoursPerDay (1-12 integer)
- recommendedDailyStudyMinutes (10-180 integer)
- recommendedWeeklySessions (2-14 integer)
- summary (max 180 chars, practical and direct)
- highlights (array of 2-5 concise bullets)
- slots (optional array of objects: {day,start,end,subject} where day in mon/tue/wed/thu/fri/sat/sun and time in HH:mm)

Guidelines:
- Heavier school load -> lower daily study minutes, but keep consistency.
- Aim realistic GCSE cadence.
- No markdown, no explanation, JSON only.

Timetable text:
"""
$cappedText
"""
''';

    final response = await http
        .post(
          Uri.parse(_chatCompletionsUrl),
          headers: _jsonHeaders(apiKey),
          body: jsonEncode({
            'model': _analysisModel,
            'messages': [
              {
                'role': 'system',
                'content':
                    'Return only strict JSON. No markdown fences, no prose.'
              },
              {'role': 'user', 'content': prompt},
            ],
            'temperature': 0.2,
            'max_tokens': 500,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode >= 400) {
      throw Exception(
        'Timetable analysis failed (${response.statusCode}): ${response.body}',
      );
    }

    final payload = _toJsonMap(response.body);
    String content = '';
    final choices = payload['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final message = first['message'];
        if (message is Map) {
          content = message['content']?.toString().trim() ?? '';
        }
      }
    }

    final parsed = _extractJsonMap(content);
    final inferredDays = _inferSchoolDays(trimmed);
    final schoolDays = _clampInt(
      _toInt(parsed['schoolDaysPerWeek']) ?? inferredDays,
      1,
      7,
    );
    final averageHours = _clampInt(
      _toInt(parsed['averageSchoolHoursPerDay']) ?? 6,
      1,
      12,
    );
    final recommendedDaily = _clampInt(
      _toInt(parsed['recommendedDailyStudyMinutes']) ??
          _defaultDailyStudyMinutes(
            schoolDaysPerWeek: schoolDays,
            avgSchoolHoursPerDay: averageHours,
          ),
      10,
      180,
    );
    final weeklyStudyMinutes = _clampInt(recommendedDaily * 7, 70, 1260);
    final weeklySessions = _clampInt(
      _toInt(parsed['recommendedWeeklySessions']) ??
          _defaultWeeklySessions(weeklyStudyMinutes),
      2,
      14,
    );
    final summary = parsed['summary']?.toString().trim().isNotEmpty == true
        ? parsed['summary'].toString().trim()
        : 'Plan set from timetable: ${recommendedDaily}m/day across $schoolDays school days.';
    final highlights = (parsed['highlights'] is List
            ? (parsed['highlights'] as List)
                .map((entry) => entry.toString().trim())
                .where((entry) => entry.isNotEmpty)
                .toList(growable: false)
            : const <String>[])
        .take(5)
        .toList(growable: false);
    final slotsFromModel = _normalizeSlotsFromDynamic(parsed['slots']);
    final slots = slotsFromModel.isNotEmpty
        ? slotsFromModel
        : _extractSlotsFromText(trimmed);

    return TimetablePlanDraft(
      weeklyStudyMinutes: weeklyStudyMinutes,
      weeklySessionsTarget: weeklySessions,
      schoolDaysPerWeek: schoolDays,
      averageSchoolHoursPerDay: averageHours,
      summary: summary,
      highlights: highlights,
      extractedText: trimmed,
      timetableSlots: slots,
    );
  }

  static Map<String, dynamic> _toJsonMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw Exception('Unexpected JSON response type.');
  }

  static Map<String, dynamic> _extractJsonMap(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return <String, dynamic>{};

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Fallback below.
    }

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final candidate = trimmed.substring(start, end + 1);
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        debugPrint('[TimetableSync] Could not parse JSON candidate.');
      }
    }
    return <String, dynamic>{};
  }

  static String? _normalizeDayKey(String? value) {
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

  static String? _normalizeTime(String? value) {
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

  static List<TimetableSlotDraft> _sortAndDedupeSlots(
      List<TimetableSlotDraft> input) {
    final seen = <String>{};
    final out = <TimetableSlotDraft>[];
    int dayOrder(String day) {
      switch (day) {
        case 'mon':
          return 0;
        case 'tue':
          return 1;
        case 'wed':
          return 2;
        case 'thu':
          return 3;
        case 'fri':
          return 4;
        case 'sat':
          return 5;
        case 'sun':
          return 6;
        default:
          return 99;
      }
    }

    for (final slot in input) {
      final key =
          '${slot.day}|${slot.start}|${slot.end}|${slot.subject.toLowerCase()}';
      if (!seen.add(key)) continue;
      out.add(slot);
      if (out.length >= 120) break;
    }
    out.sort((a, b) {
      final dayDiff = dayOrder(a.day) - dayOrder(b.day);
      if (dayDiff != 0) return dayDiff;
      final startDiff = a.start.compareTo(b.start);
      if (startDiff != 0) return startDiff;
      return a.subject.compareTo(b.subject);
    });
    return out;
  }

  static List<TimetableSlotDraft> _normalizeSlotsFromDynamic(dynamic raw) {
    if (raw is! List) return const <TimetableSlotDraft>[];
    final out = <TimetableSlotDraft>[];
    for (final row in raw) {
      if (row is! Map) continue;
      final day = _normalizeDayKey(row['day']?.toString());
      final start = _normalizeTime(row['start']?.toString());
      final end = _normalizeTime(row['end']?.toString());
      final subject = row['subject']?.toString().trim() ?? '';
      if (day == null || start == null || end == null || subject.isEmpty) {
        continue;
      }
      if (start.compareTo(end) >= 0) continue;
      out.add(TimetableSlotDraft(
        day: day,
        start: start,
        end: end,
        subject: subject,
      ));
    }
    return _sortAndDedupeSlots(out);
  }

  static List<TimetableSlotDraft> _extractSlotsFromText(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    final out = <TimetableSlotDraft>[];
    String? currentDay;
    final dayPattern = RegExp(
      r'^(monday|mon|tuesday|tue|wednesday|wed|thursday|thu|friday|fri|saturday|sat|sunday|sun)\b',
      caseSensitive: false,
    );
    final rangePattern = RegExp(
      r'(\d{1,2}[:.]\d{2})\s*(?:-|–|to)\s*(\d{1,2}[:.]\d{2})',
      caseSensitive: false,
    );

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final dayMatch = dayPattern.firstMatch(line);
      if (dayMatch != null) {
        currentDay = _normalizeDayKey(dayMatch.group(1));
      }

      if (currentDay == null) continue;
      final timeMatch = rangePattern.firstMatch(line);
      if (timeMatch == null) continue;

      final start = _normalizeTime(timeMatch.group(1));
      final end = _normalizeTime(timeMatch.group(2));
      if (start == null || end == null || start.compareTo(end) >= 0) continue;

      var subject =
          line.substring(timeMatch.end).replaceAll(RegExp(r'^[\s:\-–]+'), '');
      subject = subject.trim();
      if (subject.isEmpty) {
        subject = 'School period';
      }
      out.add(TimetableSlotDraft(
        day: currentDay,
        start: start,
        end: end,
        subject: subject,
      ));
    }

    return _sortAndDedupeSlots(out);
  }

  static int _inferSchoolDays(String text) {
    final normalized = text.toLowerCase();
    const names = <String>[
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
      'mon',
      'tue',
      'wed',
      'thu',
      'fri',
      'sat',
      'sun',
    ];
    final matched = <String>{};
    for (final day in names) {
      if (normalized.contains(day)) {
        matched.add(day.substring(0, 3));
      }
    }
    if (matched.isNotEmpty) return matched.length;
    return 5;
  }

  static int _defaultDailyStudyMinutes({
    required int schoolDaysPerWeek,
    required int avgSchoolHoursPerDay,
  }) {
    final load = schoolDaysPerWeek * avgSchoolHoursPerDay;
    if (load >= 42) return 35;
    if (load >= 34) return 45;
    if (load >= 26) return 55;
    return 65;
  }

  static int _defaultWeeklySessions(int weeklyStudyMinutes) {
    final sessions = (weeklyStudyMinutes / 90).round();
    return _clampInt(sessions, 3, 10);
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  static int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
