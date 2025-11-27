import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_links/app_links.dart';
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
  Uri? _pendingInvite;
  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initDynamicLinks();
      _initAppLinks();
    }
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && _pendingInvite != null) {
        final uri = _pendingInvite!;
        _pendingInvite = null;
        _handleIncomingUri(uri);
      }
    });
  }

  Future<void> _initDynamicLinks() async {
    // Handle links when app is already open
    FirebaseDynamicLinks.instance.onLink.listen((dynamicLink) {
      _handleDynamicLink(dynamicLink.link);
    }).onError((error) {
      debugPrint('onLink error: $error');
    });

    // Handle initial link that opened the app
    final PendingDynamicLinkData? initialLink =
        await FirebaseDynamicLinks.instance.getInitialLink();
    if (initialLink != null) {
      // Wait until the first frame is rendered to ensure context is available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleDynamicLink(initialLink.link);
      });
    }
  }

  void _handleDynamicLink(Uri deepLink) {
    _handleIncomingUri(deepLink);
  }

  Future<void> _initAppLinks() async {
    try {
      _appLinks = AppLinks();
      // Stream for links while app is running
      _appLinks!.uriLinkStream.listen((uri) {
        _handleIncomingUri(uri);
      }, onError: (err) {
        debugPrint('AppLinks stream error: $err');
      });

      // Link that initially opened the app
      final initialUri = await _appLinks!.getInitialLink();
      if (initialUri != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleIncomingUri(initialUri);
        });
      }
    } catch (e) {
      debugPrint('initAppLinks error: $e');
    }
  }

  void _handleIncomingUri(Uri uri) {
    debugPrint('DeepLink: received uri=$uri');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Defer handling until after login
      _pendingInvite = uri;
      return;
    }

    // Ensure we have a Navigator context; if not, try again next frame
    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      debugPrint('DeepLink: navigator context not ready, deferring to next frame');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // If user signed out during deferral, keep it pending
        if (FirebaseAuth.instance.currentUser == null) {
          _pendingInvite = uri;
        } else {
          _handleIncomingUri(uri);
        }
      });
      return;
    }

    final isGroupLink = uri.pathSegments.contains('group') || uri.host == 'group';
    if (isGroupLink) {
      final groupId = uri.queryParameters['id'];
      if (groupId != null) {
        debugPrint('DeepLink: detected group link, groupId=$groupId (host=${uri.host}, path=${uri.path})');
        showDialog(
          context: ctx,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Join Group?'),
            content: const Text('Are you sure you want to join this group?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  debugPrint('DeepLink: joining groupId=$groupId');
                  await _joinGroup(groupId);
                  if (Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop();
                  }
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Group joined successfully!')),
                  );
                },
                child: const Text('Join'),
              ),
            ],
          ),
        );
      } else {
        debugPrint('DeepLink: group link missing id parameter');
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
