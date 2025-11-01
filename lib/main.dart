import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:sliceit/services/theme_provider.dart';
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
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'SliceIt',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: Brightness.light,
              primaryColor: AppColors.oliveGreen,
              scaffoldBackgroundColor: AppColors.white,
              fontFamily: 'Poppins',
              cardColor: Colors.white,
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.oliveGreen,
                foregroundColor: Colors.white,
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primaryColor: AppColors.oliveGreen,
              scaffoldBackgroundColor: const Color(0xFF121212),
              fontFamily: 'Poppins',
              cardColor: const Color(0xFF1E1E1E),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1E1E1E),
                foregroundColor: Colors.white,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.oliveGreen,
                ),
              ),
            ),
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const SplashScreen(),
            routes: {
              '/expenses': (context) => const ExpensesScreen(),
              '/analytics': (context) => const AnalyticsScreen(),
              '/split': (context) => const SplitBillsScreen(),
              '/profile': (context) => const ProfileScreen(),
            },
          );
        },
      ),
    );
  }
}
