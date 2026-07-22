import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final AuthService _auth = AuthService();
  // 💡 需求 7: 新增使用者名稱欄位
  final _usernameController = TextEditingController();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();

  // 💡 終極版 Email 驗證
  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9]+([._+-][a-zA-Z0-9]+)*@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("提示"),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("確定")),
        ],
      ),
    );
  }

  String _getSignUpErrorMessage(String? errorCode) {
    switch (errorCode) {
      case 'email-already-in-use':
        return "此信箱已被註冊，請改用其他 Email 或直接登入。";
      case 'weak-password':
        return "密碼強度不足，請至少輸入 6 碼。";
      case 'invalid-email':
        return "Email 格式錯誤，請確認後再試一次。";
      case 'network-request-failed':
        return "目前沒有網路連線，請檢查網路後再試一次。";
      default:
        return "註冊失敗，請稍後再試。";
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("建立新帳號")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          children: [
            const Icon(Icons.person_add_alt_1, size: 80, color: AppColors.actionBlue),
            const SizedBox(height: 30),

            // 使用者名稱輸入框
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: "使用者名稱 (例如: 王小明)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),

            // 帳號輸入框
            TextField(
              controller: _accountController,
              decoration: const InputDecoration(labelText: "帳號 (請輸入完整 Email)", border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),

            // 密碼輸入框
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "密碼 (至少 6 位)", border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () async {
                String username = _usernameController.text.trim();
                String email = _accountController.text.trim();
                String password = _passwordController.text.trim();

                // 檢查是否漏填
                if (username.isEmpty || email.isEmpty || password.isEmpty) {
                  _showErrorDialog("請填寫所有欄位！");
                  return;
                }

                // 💡 嚴格格式防呆提示
                if (!_isValidEmail(email)) {
                  _showErrorDialog("帳號格式錯誤！\n\n@ 前面只能包含英文、數字，以及點(.)、底線(_)、連字號(-)與加號(+)。\n\n注意：符號不能在最前面或最後面，也不能連續出現！");
                  return;
                }

                // 執行註冊
                final result = await _auth.signUpWithResult(email, password, username);

                if (result.isSuccess && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("註冊成功！正在為您登入...")));
                  Navigator.pop(context); // 註冊成功後返回登入頁
                } else if (mounted) {
                  _showErrorDialog(_getSignUpErrorMessage(result.errorCode));
                }
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text("確認註冊"),
            ),
          ],
        ),
      ),
    );
  }
}
