import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  static Future<User> ensureSignedIn() async {
    final cur = _auth.currentUser;
    if (cur != null) return cur;

    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw Exception('Google 로그인 취소됨');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCred = await _auth.signInWithCredential(credential);
    return userCred.user!;
  }
}
