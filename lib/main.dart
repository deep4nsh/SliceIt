import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
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

final navigatorKey = GlobalKey<NavigatorState>();

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
  AppLinks? _appLinks;

  @override
  void initState() {
    super.initState();
    _initDynamicLinks();
  }

  Future<void> _initDynamicLinks() async {
    try {
      _appLinks = AppLinks();

      // Listen for incoming links while the app is running
      _appLinks!.uriLinkStream.listen((Uri uri) {
        _handleDynamicLink(uri);
      }, onError: (error) {
        debugPrint('app_links stream error: $error');
      });

      // Handle the app being launched via a link
      final initialUri = await _appLinks!.getInitialAppLink();
      if (initialUri != null) {
        _handleDynamicLink(initialUri);
      }
    } catch (e) {
      debugPrint('app_links init error: $e');
    }
  }

  void _handleDynamicLink(Uri deepLink) {
    if (deepLink.pathSegments.contains('group')) {
      final groupId = deepLink.queryParameters['id'];
      final inviterUid = deepLink.queryParameters['inviter'];
      if (groupId != null) {
        // Use the navigatorKey to show a dialog
        showDialog(
          context: navigatorKey.currentContext!,
          builder: (context) => AlertDialog(
            title: const Text('Join Group?'),
            content: const Text('Are you sure you want to join this group?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _joinGroup(groupId, inviterUid: inviterUid);
                  if (mounted) Navigator.of(context).pop();
                },
                child: const Text('Join'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _joinGroup(String groupId, {String? inviterUid}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestore = FirebaseFirestore.instance;
    final groupRef = firestore.collection('groups').doc(groupId);

    // Add current user to group members
    await groupRef.update({
      'members': FieldValue.arrayUnion([user.uid])
    });

    // Optionally add contacts for easier future use
    if (inviterUid != null && inviterUid.isNotEmpty && inviterUid != user.uid) {
      try {
        final inviterDoc = await firestore.collection('users').doc(inviterUid).get();
        final inviterData = inviterDoc.data() as Map<String, dynamic>?;
        final inviterEmail = inviterData?['email'] as String?;

        final selfDoc = await firestore.collection('users').doc(user.uid).get();
        final selfData = selfDoc.data() as Map<String, dynamic>?;
        final selfEmail = selfData?['email'] as String? ?? user.email;

        // Add joiner to inviter's contacts
        if (selfEmail != null) {
          await firestore
              .collection('users')
              .doc(inviterUid)
              .collection('contacts')
              .doc(user.uid)
              .set({'uid': user.uid, 'email': selfEmail, 'addedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        }

        // Add inviter to joiner's contacts
        if (inviterEmail != null) {
          await firestore
              .collection('users')
              .doc(user.uid)
              .collection('contacts')
              .doc(inviterUid)
              .set({'uid': inviterUid, 'email': inviterEmail, 'addedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('Failed to add contacts after joining group: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
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
