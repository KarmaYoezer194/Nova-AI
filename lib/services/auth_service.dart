import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Thrown by [AuthService] with a message that is safe to show to users.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// All sign-in work goes through this class. Screens never call Firebase Auth
/// directly.
///
/// Security: passwords are passed straight to Firebase Auth and never stored,
/// logged or sent anywhere else.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _authOverride = auth;

  final FirebaseAuth? _authOverride;

  // Looked up only when first used, so screens can be tested without Firebase.
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  /// Emits the signed-in user, or null when signed out. Drives the auth gate.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) {
    return _run(
      () => _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );
  }

  Future<void> register({required String email, required String password}) {
    return _run(
      () => _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );
  }

  /// Sends a reset link. For privacy we never reveal whether the email has an
  /// account, so "no such user" is treated as success.
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return;
      _logInDebug(e);
      throw AuthFailure(friendlyAuthMessage(e.code));
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// Checks the password again before something serious (deleting the
  /// account). Firebase also requires a recent sign-in for that.
  Future<void> confirmPassword(String password) {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthFailure('Please sign in again.');
    }
    return _run(
      () => user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      ),
    );
  }

  /// Deletes the sign-in account itself. Call [confirmPassword] first.
  Future<void> deleteAccount() {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure('Please sign in again.');
    return _run(user.delete);
  }

  /// Runs a Firebase Auth call and turns its errors into friendly messages.
  Future<void> _run(Future<Object?> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      _logInDebug(e);
      throw AuthFailure(friendlyAuthMessage(e.code));
    } catch (e) {
      if (kDebugMode) debugPrint('Auth error: $e');
      throw const AuthFailure('Something went wrong. Please try again.');
    }
  }

  // Only the error code and message; never the password.
  void _logInDebug(FirebaseAuthException e) {
    if (kDebugMode) debugPrint('Auth error [${e.code}]: ${e.message}');
  }
}

/// Maps Firebase Auth error codes to plain-language messages.
///
/// Wrong email and wrong password get the same message on purpose: telling
/// them apart would let strangers check which emails have accounts.
String friendlyAuthMessage(String code) {
  switch (code) {
    case 'invalid-email':
      return 'That email address doesn\'t look right.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'INVALID_LOGIN_CREDENTIALS':
      return 'Email or password is incorrect.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'email-already-in-use':
      return 'An account with this email already exists. Try signing in.';
    case 'weak-password':
    case 'password-does-not-meet-requirements':
      return 'Please choose a stronger password (at least 8 characters).';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a minute and try again.';
    case 'network-request-failed':
      return 'No connection. Check your internet and try again.';
    case 'operation-not-allowed':
      return 'Email sign-in isn\'t turned on yet for this app.';
    case 'requires-recent-login':
    case 'user-mismatch':
    case 'user-token-expired':
      return 'For your safety, please sign out, sign in again, and retry.';
    default:
      return 'Something went wrong. Please try again.';
  }
}
