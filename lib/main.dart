import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/auth/login_screen.dart';
import 'screens/welcome/welcome_screen.dart';
import 'theme/db_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  final prefs = await SharedPreferences.getInstance();
  final seenWelcome = prefs.getBool('seen_welcome_v3') ?? false;
  runApp(DbTakipApp(showWelcome: !seenWelcome));
}

class DbTakipApp extends StatelessWidget {
  const DbTakipApp({super.key, required this.showWelcome});

  final bool showWelcome;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DB Takip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Nunito',
        splashFactory: NoSplash.splashFactory,
        colorScheme: ColorScheme.fromSeed(
          seedColor: DbColors.navy,
          primary: DbColors.navy,
          surface: Colors.white,
        ),
      ),
      home: showWelcome ? const WelcomeScreen() : const LoginScreen(),
    );
  }
}
