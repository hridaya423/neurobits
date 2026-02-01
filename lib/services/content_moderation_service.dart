import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:neurobits/services/ai_service.dart';

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
  static bool _hackclubApiAvailable = false;

  static final Map<String, _RateLimit> _userRateLimits = {};
  static const int _maxRequestsPerMinute = 10;
  static const Duration _rateLimitWindow = Duration(minutes: 1);

  static DateTime? _lastApiErrorNotification;
  static const Duration _notificationThrottle = Duration(minutes: 5);

  static Future<void> init() async {
    _hackclubApiAvailable = AIService.isConfigured();
    if (!_hackclubApiAvailable) {
      debugPrint(
          'Warning: OPENROUTER_API_KEY not found. Content moderation will be limited.');
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

  // Basic blocklist for fallback moderation when API is unavailable
  static final List<String> _blockedPatterns = [
    r'\b(kill|murder|suicide|harm)\b',
    r'\b(porn|xxx|nsfw)\b',
    r'\b(hack|exploit|injection)\b',
  ];

  static bool _basicContentCheck(String content) {
    final lowerContent = content.toLowerCase();
    for (final pattern in _blockedPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lowerContent)) {
        return false; // Content is inappropriate
      }
    }
    return true; // Content passes basic check
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

    if (_hackclubApiAvailable) {
      try {
        return await _checkWithHackclubGuard(content);
      } catch (e) {
        debugPrint('Hackclub moderation error: $e');
        final passesBasicCheck = _basicContentCheck(content);
        return ModerationResult(
          isAppropriate: passesBasicCheck,
          message: passesBasicCheck
              ? 'Moderation service unavailable, basic check passed'
              : 'Content blocked by safety filter',
          isApiError: true,
        );
      }
    }

    debugPrint(
        'Warning: Content moderation API unavailable. Using basic content filter.');
    final passesBasicCheck = _basicContentCheck(content);
    return ModerationResult(
      isAppropriate: passesBasicCheck,
      message: passesBasicCheck ? null : 'Content blocked by safety filter',
    );
  }

  static Future<ModerationResult> _checkWithHackclubGuard(
      String content) async {
    try {
      final response = await AIService.postModerationRequest(content);

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

        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody['error'] != null) {
            errorMessage = errorBody['error']['message'] ?? errorMessage;
          }
        } catch (_) {}

        debugPrint('Hackclub moderation API error: $errorMessage');

        return ModerationResult(
          isAppropriate: true,
          message: 'Moderation service error: $errorMessage',
          isApiError: true,
        );
      }
    } catch (e) {
      debugPrint('Hackclub moderation API exception: $e');
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
