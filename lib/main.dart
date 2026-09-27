import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/site_session.dart';
import 'demo/demo_account.dart';
import 'screens/auth/login_screen.dart';
import 'screens/program/program_screen.dart';
import 'screens/welcome/welcome_screen.dart';
import 'theme/db_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  final prefs = await SharedPreferences.getInstance();
  final seenWelcome = prefs.getBool('seen_welcome_v3') ?? false;
  final loggedIn = prefs.getBool(DemoAccount.sessionKey) ?? false;
  final live = prefs.getBool(SiteSession.liveKey) ?? false;
  runApp(DbTakipApp(showWelcome: !seenWelcome && !loggedIn, loggedIn: loggedIn, live: live));
}

class DbTakipApp extends StatelessWidget {
  const DbTakipApp({super.key, required this.showWelcome, this.loggedIn = false, this.live = false});

  final bool showWelcome;
  final bool loggedIn;
  final bool live;

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
      home: loggedIn
          ? ProgramScreen(live: live)
          : (showWelcome ? const WelcomeScreen() : const LoginScreen()),
    );
  }
}
