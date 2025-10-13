import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sliceit/screens/analytics_screen.dart';
import 'package:sliceit/screens/expenses_screen.dart';
import 'package:sliceit/screens/profile_screen.dart';
import 'package:sliceit/screens/split_bills_screen.dart';
import 'firebase_options.dart';
import 'utils/colors.dart';
import 'screens/splash_screen.dart';

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
      title: 'SliceIt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.oliveGreen,
        scaffoldBackgroundColor: AppColors.white,
        fontFamily: 'Poppins',
      ),
      home: const SplashScreen(),
      routes: {
        '/expenses': (context) => const ExpensesScreen(), // 👈 Add this line
        '/analytics': (context) => const AnalyticsScreen(),
        '/split': (context) => const SplitBillsScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}
