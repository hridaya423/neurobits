import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance!;

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  final _authStateController = StreamController<AuthStatus>.broadcast();

  Stream<AuthStatus> get authStateChanges => _authStateController.stream;

  Stream<User?> get idTokenChanges => _firebaseAuth.idTokenChanges();

  AuthStatus _currentStatus = AuthStatus.unknown;
  AuthStatus get currentStatus => _currentStatus;

  StreamSubscription<User?>? _firebaseAuthSub;

  AuthService._();

  static Future<AuthService> init() async {
    if (_instance != null) return _instance!;

    final service = AuthService._();

    service._firebaseAuthSub =
        service._firebaseAuth.authStateChanges().listen((user) {
      if (user != null) {
        service._setStatus(AuthStatus.authenticated);
      } else {
        service._setStatus(AuthStatus.unauthenticated);
      }
    });

    if (service._firebaseAuth.currentUser != null) {
      service._setStatus(AuthStatus.authenticated);
    } else {
      service._setStatus(AuthStatus.unauthenticated);
    }

    _instance = service;
    return service;
  }

  void _setStatus(AuthStatus status) {
    _currentStatus = status;
    _authStateController.add(status);
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthService: Sign-in error: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthService: Sign-up error: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthService: Password reset error: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      debugPrint('AuthService: Logout error: $e');
    }
  }

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      _setStatus(AuthStatus.unauthenticated);
      return null;
    }
    try {
      return await user.getIdToken(forceRefresh);
    } catch (e) {
      debugPrint('AuthService: Error getting ID token: $e');
      _setStatus(AuthStatus.unauthenticated);
      return null;
    }
  }

  bool get isLoggedIn => _firebaseAuth.currentUser != null;

  String? get currentEmail => _firebaseAuth.currentUser?.email;

  String? get currentSubject => _firebaseAuth.currentUser?.uid;

  User? get currentUser => _firebaseAuth.currentUser;

  void dispose() {
    _firebaseAuthSub?.cancel();
    _authStateController.close();
  }
}
