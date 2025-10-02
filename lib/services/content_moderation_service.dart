import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';

class ModerationResult {
  final bool isAppropriate;
  final String? message;
  final bool isApiError;

  ModerationResult({
    required this.isAppropriate,
    this.message,
    this.isApiError = false,
  });
}

class ContentModerationService {
  static bool _groqApiAvailable = false;
  static String? _groqApiKey;

  static final Map<String, _RateLimit> _userRateLimits = {};
  static const int _maxRequestsPerMinute = 10;
  static const Duration _rateLimitWindow = Duration(minutes: 1);

  static DateTime? _lastApiErrorNotification;
  static const Duration _notificationThrottle = Duration(minutes: 5);

  static Future<void> init() async {
    const groqKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
    _groqApiKey = groqKey.isNotEmpty ? groqKey : dotenv.env['GROQ_API_KEY'];
    _groqApiAvailable = _groqApiKey != null && _groqApiKey!.isNotEmpty;
    if (!_groqApiAvailable) {
      debugPrint(
          'Warning: GROQ_API_KEY not found. Content moderation will be limited.');
    }
  }

  static void showApiErrorNotification(BuildContext context, String message) {
    final now = DateTime.now();
    if (_lastApiErrorNotification == null ||
        now.difference(_lastApiErrorNotification!) > _notificationThrottle) {
      _lastApiErrorNotification = now;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 8),
          backgroundColor: Colors.orangeAccent,
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  static Future<bool> isAppropriateContent(String content,
      {String? userId}) async {
    final result = await moderateContent(content, userId: userId);
    return result.isAppropriate;
  }

  static Future<ModerationResult> moderateContent(String content,
      {String? userId}) async {
    if (content.isEmpty) {
      return ModerationResult(isAppropriate: true);
    }

    if (userId != null) {
      if (!_checkRateLimit(userId)) {
        return ModerationResult(
          isAppropriate: false,
          message: 'Rate limit exceeded. Please try again later.',
        );
      }
    }

    if (_groqApiAvailable) {
      try {
        return await _checkWithLlamaGuard(content);
      } catch (e) {
        debugPrint('LlamaGuard moderation error: $e');
        return ModerationResult(
          isAppropriate: true,
          message: 'Moderation service error: $e',
          isApiError: true,
        );
      }
    }

    debugPrint(
        'Warning: Content moderation is inactive. GROQ_API_KEY is required.');
    return ModerationResult(isAppropriate: true);
  }

  static Future<ModerationResult> _checkWithLlamaGuard(String content) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $_groqApiKey',
        },
        body: jsonEncode({
          'model': 'meta-llama/Llama-Guard-4-12B',
          'messages': [
            {
              'role': 'user',
              'content': content,
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final result = data['choices'][0]['message']['content'] as String;
        final isSafe = result.toLowerCase().trim().startsWith('safe');

        return ModerationResult(
          isAppropriate: isSafe,
          message: isSafe
              ? null
              : 'Content flagged as inappropriate by content moderation.',
        );
      } else {
        String errorMessage = 'API error: ${response.statusCode}';
        bool isApiKeyIssue = false;

        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody['error'] != null) {
            errorMessage = errorBody['error']['message'] ?? errorMessage;

            if (errorBody['error']['code'] == 'invalid_api_key' ||
                errorMessage.contains('API Key') ||
                response.statusCode == 401) {
              isApiKeyIssue = true;
            }
          }
        } catch (_) {}

        debugPrint('Llama Guard API error: $errorMessage');

        return ModerationResult(
          isAppropriate: true,
          message: 'Moderation service error: $errorMessage',
          isApiError: true,
        );
      }
    } catch (e) {
      debugPrint('Llama Guard API exception: $e');
      return ModerationResult(
        isAppropriate: true,
        message: 'Moderation service exception: $e',
        isApiError: true,
      );
    }
  }

  static bool _checkRateLimit(String userId) {
    final now = DateTime.now();

    if (_userRateLimits.length % 100 == 0) {
      _cleanupOldRateLimits(now);
    }

    if (!_userRateLimits.containsKey(userId)) {
      _userRateLimits[userId] = _RateLimit(
        requestCount: 0,
        windowStart: now,
      );
    }

    var userLimit = _userRateLimits[userId]!;

    if (now.difference(userLimit.windowStart) > _rateLimitWindow) {
      userLimit.requestCount = 0;
      userLimit.windowStart = now;
    }

    if (userLimit.requestCount >= _maxRequestsPerMinute) {
      return false;
    }

    userLimit.requestCount++;
    return true;
  }

  static void _cleanupOldRateLimits(DateTime now) {
    const maxAge = Duration(hours: 24);
    _userRateLimits.removeWhere((userId, rateLimit) {
      return now.difference(rateLimit.windowStart) > maxAge;
    });
  }

  static Future<Map<String, dynamic>?> moderateUserProfileData(
      Map<String, dynamic> profileData,
      {String? userId}) async {
    Map<String, dynamic> sanitizedData = {};
    String? rejectionReason;

    for (var key in profileData.keys) {
      if (profileData[key] is String) {
        final stringValue = profileData[key] as String;

        if (stringValue.isEmpty) {
          sanitizedData[key] = stringValue;
          continue;
        }

        final result = await moderateContent(stringValue, userId: userId);
        if (!result.isAppropriate) {
          debugPrint(
              'Content moderation blocked inappropriate profile data for field: $key');

          rejectionReason = result.message;
          return null;
        }

        sanitizedData[key] = stringValue;
      } else {
        sanitizedData[key] = profileData[key];
      }
    }

    return sanitizedData;
  }
}

class _RateLimit {
  int requestCount;
  DateTime windowStart;

  _RateLimit({
    required this.requestCount,
    required this.windowStart,
  });
}
