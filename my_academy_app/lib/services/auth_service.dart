import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<User> loginWithEmailPassword(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password,
      );
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found': message = 'No admin account found with this email.'; break;
        case 'wrong-password': message = 'Incorrect password. Please try again.'; break;
        case 'invalid-email': message = 'The email address is invalid.'; break;
        case 'user-disabled': message = 'This admin account has been disabled.'; break;
        case 'too-many-requests': message = 'Too many attempts. Please try again later.'; break;
        default: message = 'Login failed: ${e.message}';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('An unexpected error occurred.');
    }
  }

  static Future<void> logout() async {
    await _auth.signOut();
  }

  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found': message = 'No account found with this email.'; break;
        case 'invalid-email': message = 'The email address is invalid.'; break;
        default: message = 'Failed: ${e.message}';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('An unexpected error occurred.');
    }
  }
}