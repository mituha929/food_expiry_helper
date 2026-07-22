import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'food_input_screen.dart';
import 'home_page.dart';
import 'register_page.dart';
import '../theme/app_colors.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _auth = AuthService();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();

  // 💡 終極版 Email 驗證：支援英數與特定符號 (._-+)，並防止符號在頭尾或連續出現
  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9]+([._+-][a-zA-Z0-9]+)*@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  // 顯示錯誤彈窗
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("登入失敗"),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("確定")),
        ],
      ),
    );
  }

  Future<bool> _showLocalModeWarning() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("本機暫存模式"),
        content: const Text(
          "目前尚未登入，資料只會暫存在本機。\n\n"
          "若更換裝置、清除 App 資料或尚未同步，資料可能遺失。登入後可上傳到雲端並啟用寄信提醒。",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("取消")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("繼續")),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _openLocalFoodInput() async {
    final shouldContinue = await _showLocalModeWarning();
    if (!shouldContinue || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FoodInputScreen(isLocalMode: true)),
    );
  }

  Future<void> _openLocalFoodList() async {
    final shouldContinue = await _showLocalModeWarning();
    if (!shouldContinue || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HomePage(isLocalMode: true)),
    );
  }

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.subtleBackground,
      appBar: AppBar(title: const Text("食間管理大師 - 登入")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 112,
                height: 112,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 10),
            const Text("歡迎回來", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),

            TextField(
              controller: _accountController,
              decoration: const InputDecoration(labelText: "帳號 (請輸入完整 Email)", border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "密碼", border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () async {
                String email = _accountController.text.trim();
                String password = _passwordController.text.trim();

                // 💡 需求 4: 空白防呆
                if (email.isEmpty || password.isEmpty) {
                  _showErrorDialog("請務必輸入帳號與密碼！");
                  return;
                }

                // 💡 嚴格格式防呆
                if (!_isValidEmail(email)) {
                  _showErrorDialog("帳號格式錯誤！\n\n@ 前面只能包含英文、數字，以及點(.)、底線(_)、連字號(-)與加號(+)。\n\n注意：符號不能在最前面或最後面，也不能連續出現！");
                  return;
                }

                // 執行登入
                var result = await _auth.signInWithResult(email, password);
                if (!result.isSuccess && mounted) {
                  if (result.isNetworkError) {
                    _showErrorDialog("目前沒有網路連線，請檢查網路後再試一次。\n\n若要先新增食物，可使用本機暫存模式。");
                  } else {
                    // 💡 需求 4: 登入失敗的提示
                    _showErrorDialog("您輸入的帳號或密碼有誤，請再試一次。");
                  }
                }
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text("登入"),
            ),
            const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: _openLocalFoodInput,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text("先新增本機食物"),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _openLocalFoodList,
              icon: const Icon(Icons.phone_android),
              label: const Text("查看本機暫存食物"),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
            const SizedBox(height: 15),

            // 💡 需求 6: 點選這裡跳轉註冊頁面
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage()));
              },
              child: const Text("還沒有帳號？點此註冊"),
            ),
          ],
        ),
      ),
    );
  }
}
