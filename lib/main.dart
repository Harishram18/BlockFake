import 'package:app_1/screens/capture_vid.dart';
import 'package:app_1/screens/vid_pick.dart';
import 'package:flutter/material.dart';
import 'package:app_1/screens/firebase_options.dart';
import 'package:app_1/screens/home_screen.dart';
import 'package:app_1/screens/login_screen.dart';
import 'package:app_1/screens/signup_screen.dart';
import 'package:app_1/screens/welcome.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
          textTheme: const TextTheme(
            bodyMedium: TextStyle(
              fontFamily: 'Ubuntu',
            ),
          )),
      initialRoute: HomeScreen.id,
      routes: {
        HomeScreen.id: (context) => const HomeScreen(),
        LoginScreen.id: (context) => const LoginScreen(),
        SignUpScreen.id: (context) => const SignUpScreen(),
        WelcomeScreen.id: (context) => const WelcomeScreen(),
        VideoPickerScreen.id: (context) => const VideoPickerScreen(),
        VideoRecorderScreen.id: (context) => const VideoRecorderScreen(),
      },
    );
  }
}
