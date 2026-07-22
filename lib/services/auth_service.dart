import 'package:firebase_auth/firebase_auth.dart';
import 'database_service.dart';

class AuthResult {
  final User? user;
  final String? errorCode;

  const AuthResult({this.user, this.errorCode});

  bool get isSuccess => user != null;
  bool get isNetworkError => errorCode == 'network-request-failed';
}

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = DatabaseService();

  // 💡 升級：接收 username 並傳遞給 DatabaseService
  Future<User?> signUp(String email, String password, String username) async {
    final result = await signUpWithResult(email, password, username);
    return result.user;
  }

  Future<AuthResult> signUpWithResult(String email, String password, String username) async {
    try {
      UserCredential res = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password
      );
      if (res.user != null) {
        await _db.saveUserData(email, username);
      }
      return AuthResult(user: res.user);
    } on FirebaseAuthException catch (e) {
      print("❌ Firebase 註冊錯誤: $e"); // 錯誤會顯示在終端機
      return AuthResult(errorCode: e.code);
    } catch (e) {
      print("❌ Firebase 註冊錯誤: $e");
      return const AuthResult(errorCode: 'unknown');
    }
  }

  Future<User?> signIn(String email, String password) async {
    final result = await signInWithResult(email, password);
    return result.user;
  }

  Future<AuthResult> signInWithResult(String email, String password) async {
    try {
      final user = (await _auth.signInWithEmailAndPassword(
          email: email,
          password: password
      )).user;
      return AuthResult(user: user);
    } on FirebaseAuthException catch (e) {
      print("❌ Firebase 登入錯誤: $e");
      return AuthResult(errorCode: e.code);
    } catch (e) {
      print("❌ Firebase 登入錯誤: $e");
      return const AuthResult(errorCode: 'unknown');
    }
  }

  Future<void> signOut() async => await _auth.signOut();
}
