import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
//import 'services/database_service.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const FoodExpiryApp());
}

class FoodExpiryApp extends StatelessWidget {
  const FoodExpiryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '食間管理大師',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.subtleBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.actionBlue,
          primary: AppColors.primaryIceBlue,
          secondary: AppColors.actionBlue,
          error: AppColors.dangerRed,
          surface: AppColors.neutralWhite,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryIceBlue,
          foregroundColor: AppColors.textGrey,
          elevation: 1,
          centerTitle: true,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.actionBlue,
          foregroundColor: AppColors.neutralWhite,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.actionBlue,
            foregroundColor: AppColors.neutralWhite,
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: AppColors.neutralWhite,
          labelStyle: TextStyle(color: AppColors.textGrey),
          prefixIconColor: AppColors.textGrey,
          suffixIconColor: AppColors.actionBlue,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.textGrey),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.actionBlue, width: 1.5),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textGrey,
            side: const BorderSide(color: AppColors.textGrey),
          ),
        ),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: AppColors.textGrey,
          displayColor: AppColors.textGrey,
        ),
      ),
      // 監聽登入狀態切換 UI
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) return const HomePage();
          return  LoginPage();
        },
      ),
    );
  }
}
