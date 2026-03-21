import 'dart:async';

import 'package:convex_dart/src/convex_dart_for_generated_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ConvexClientService {
  static ConvexClientService? _instance;
  static ConvexClientService get instance => _instance!;

  late final InternalConvexClient _client;

  ConvexClientService._();

  static Future<ConvexClientService> init() async {
    if (_instance != null) return _instance!;

    final service = ConvexClientService._();

    const deploymentUrl =
        String.fromEnvironment('CONVEX_URL', defaultValue: '');

    final env = dotenv.isInitialized ? dotenv.env : const <String, String>{};
    final url = deploymentUrl.isNotEmpty
        ? deploymentUrl
        : (env['CONVEX_URL'] ?? env['CONVEX_DEPLOYMENT_URL'] ?? '');

    if (url.isEmpty) {
      throw Exception('CONVEX_URL must be configured');
    }

    service._client = await InternalConvexClient.init(deploymentUrl: url);

    _instance = service;
    return service;
  }

  Future<void> setAuthToken(String? token) async {
    await _client.setAuth(token: token);
  }

  BTreeMapStringValue _encodeArgs(Map<String, dynamic> args) {
    return hashmapToBtreemap(
      hashmap: args.map((k, v) => MapEntry(k, encodeValue(_coerceNum(v)))),
    );
  }

  static dynamic _coerceNum(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is Map<String, dynamic>) {
      return value.map((k, v) => MapEntry(k, _coerceNum(v)));
    }
    if (value is List) {
      return value.map(_coerceNum).toList();
    }
    return value;
  }

  bool _isTimeoutError(Object error) {
    return error is TimeoutException ||
        error.toString().contains('TimeoutException');
  }

  bool _shouldLogFailure(String name, Object error) {
    if (name == 'users:ensureCurrent' && _isTimeoutError(error)) {
      return false;
    }
    return true;
  }

  Future<dynamic> query({
    required String name,
    Map<String, dynamic> args = const {},
    Duration? timeout,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final future = _client.query(
        name: name,
        args: _encodeArgs(args),
      );
      final raw =
          timeout == null ? await future : await future.timeout(timeout);
      return decodeValue(raw);
    } catch (e) {
      if (kDebugMode && _shouldLogFailure(name, e)) {
        debugPrint(
            '[ConvexClientService] query:$name failed in ${sw.elapsedMilliseconds}ms: $e');
      }
      rethrow;
    }
  }

  Future<dynamic> mutation({
    required String name,
    Map<String, dynamic> args = const {},
    Duration? timeout,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final future = _client.mutation(
        name: name,
        args: _encodeArgs(args),
      );
      final raw =
          timeout == null ? await future : await future.timeout(timeout);
      return decodeValue(raw);
    } catch (e) {
      if (kDebugMode && _shouldLogFailure(name, e)) {
        debugPrint(
            '[ConvexClientService] mutation:$name failed in ${sw.elapsedMilliseconds}ms: $e');
      }
      rethrow;
    }
  }

  Future<dynamic> action({
    required String name,
    Map<String, dynamic> args = const {},
    Duration? timeout,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final future = _client.action(
        name: name,
        args: _encodeArgs(args),
      );
      final raw =
          timeout == null ? await future : await future.timeout(timeout);
      return decodeValue(raw);
    } catch (e) {
      if (kDebugMode && _shouldLogFailure(name, e)) {
        debugPrint(
            '[ConvexClientService] action:$name failed in ${sw.elapsedMilliseconds}ms: $e');
      }
      rethrow;
    }
  }

  Stream<T> subscribe<T>({
    required String name,
    Map<String, dynamic> args = const {},
    required T Function(dynamic decoded) decode,
  }) {
    return _client.stream(
      name: name,
      args: _encodeArgs(args),
      decodeResult: (value) => decode(decodeValue(value)),
    );
  }

  InternalConvexClient get client => _client;
}

int convexInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return fallback;
}

int? convexIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return null;
}

dynamic _deepConvert(dynamic value) {
  if (value is IMap) {
    return Map<String, dynamic>.fromEntries(
      value.entries 
          .map((e) => MapEntry(e.key as String, _deepConvert(e.value))),
    );
  }
  if (value is IList) {
    return value.map((e) => _deepConvert(e)).toList();
  }
  if (value is Map) {
    return Map<String, dynamic>.fromEntries(
      value.entries
          .map((e) => MapEntry(e.key as String, _deepConvert(e.value))),
    );
  }
  if (value is List) {
    return value.map((e) => _deepConvert(e)).toList();
  }
  return value;
}

Map<String, dynamic> toMap(dynamic decoded) {
  if (decoded == null) {
    throw ArgumentError('Expected a Convex object, got null');
  }
  final converted = _deepConvert(decoded);
  if (converted is Map<String, dynamic>) return converted;
  throw ArgumentError(
      'Expected a Convex object (IMap or Map), got ${decoded.runtimeType}');
}

Map<String, dynamic>? toMapOrNull(dynamic decoded) {
  if (decoded == null) return null;
  return toMap(decoded);
}

List<Map<String, dynamic>> toMapList(dynamic decoded) {
  if (decoded == null) return [];
  final converted = _deepConvert(decoded);
  if (converted is List) {
    return converted.cast<Map<String, dynamic>>();
  }
  throw ArgumentError(
      'Expected a Convex array (IList or List), got ${decoded.runtimeType}');
}

List<dynamic> toList(dynamic decoded) {
  if (decoded == null) return [];
  final converted = _deepConvert(decoded);
  if (converted is List) return converted;
  throw ArgumentError('Expected a Convex array, got ${decoded.runtimeType}');
}

bool isConvexList(dynamic value) {
  if (value is IList) return true;
  if (value is List) return true;
  return false;
}

List<String> convexStringList(dynamic value, [List<String>? fallback]) {
  if (value == null) return fallback ?? <String>[];
  if (value is IList) {
    return value.map((e) => e.toString()).toList().cast<String>();
  }
  if (value is List) return List<String>.from(value);
  return fallback ?? <String>[];
}
