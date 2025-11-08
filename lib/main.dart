import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sliceit/screens/split_history_screen.dart';
import 'package:sliceit/services/theme_provider.dart';
import 'package:sliceit/screens/analytics_screen.dart';
import 'package:sliceit/screens/expenses_screen.dart';
import 'package:sliceit/screens/profile_screen.dart';
import 'package:sliceit/screens/split_bills_screen.dart';
import 'package:sliceit/screens/groups_screen.dart';
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
    _initDynamicLinks();
  }

  Future<void> _initDynamicLinks() async {
    FirebaseDynamicLinks.instance.onLink.listen((dynamicLink) async {
      final Uri deepLink = dynamicLink.link;
      _handleDynamicLink(deepLink);
    }).onError((error) {
      debugPrint('onLink error: $error');
    });

    final PendingDynamicLinkData? initialLink = await FirebaseDynamicLinks.instance.getInitialLink();
    if (initialLink != null) {
      final Uri deepLink = initialLink.link;
      _handleDynamicLink(deepLink);
    }
  }

  void _handleDynamicLink(Uri deepLink) {
    if (deepLink.pathSegments.contains('group')) {
      final groupId = deepLink.queryParameters['id'];
      if (groupId != null) {
        _joinGroup(groupId);
      }
    }
  }

  Future<void> _joinGroup(String groupId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
    await groupRef.update({
      'members': FieldValue.arrayUnion([user.uid])
    });
  }

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
              primaryColor: AppColors.sageGreen,
              scaffoldBackgroundColor: AppColors.cream,
              fontFamily: 'Poppins',
              cardColor: Colors.white,
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.sageGreen,
                foregroundColor: Colors.white,
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primaryColor: AppColors.sageGreen,
              scaffoldBackgroundColor: const Color(0xFF121212),
              fontFamily: 'Poppins',
              cardColor: const Color(0xFF1E1E1E),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1E1E1E),
                foregroundColor: Colors.white,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sageGreen,
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
              '/groups': (context) => const GroupsScreen(),
              '/split_history': (context) => const SplitHistoryScreen(),
            },
          );
        },
      ),
    );
  }
}
