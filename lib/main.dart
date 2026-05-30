import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'package:sliceit/screens/split_history_screen.dart';
import 'package:sliceit/screens/subscriptions_screen.dart';
import 'package:sliceit/screens/add_friend_screen.dart';
import 'package:sliceit/screens/create_split_bill_screen.dart';
import 'package:sliceit/screens/settlement_history_screen.dart';
import 'package:sliceit/services/theme_provider.dart';
import 'package:sliceit/services/notification_service.dart';
import 'package:sliceit/services/notification_preferences.dart';
import 'package:sliceit/services/offline_service.dart';
import 'package:sliceit/services/connectivity_service.dart';
import 'package:sliceit/screens/analytics_screen.dart';
import 'package:sliceit/screens/expenses_screen.dart';
import 'package:sliceit/screens/profile_screen.dart';
import 'package:sliceit/screens/split_bills_screen.dart';
import 'package:sliceit/screens/groups_screen.dart';
import 'package:sliceit/screens/group_detail_screen.dart';
import 'package:sliceit/screens/notifications_screen.dart';
import 'package:sliceit/models/friend_model.dart';
import 'package:sliceit/services/friend_service.dart';
import 'package:sliceit/utils/colors.dart';
import 'package:sliceit/utils/text_styles.dart';
import 'package:sliceit/utils/app_spacing.dart';
import 'firebase_options.dart';
import 'utils/app_theme.dart';
import 'screens/splash_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize offline support
  await OfflineService.initialize();
  await ConnectivityService().initialize();

  // Initialize notifications
  await NotificationService().initializeNotifications();

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
  late NotificationPreferences _notificationPreferences;
  StreamSubscription? _authSub;
  StreamSubscription? _dynamicLinkSub;
  StreamSubscription? _appLinkSub;

  @override
  void initState() {
    super.initState();
    _initializeNotificationPreferences();
    if (!kIsWeb) {
      _initDynamicLinks();
      _initAppLinks();
    }
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && _pendingInvite != null) {
        final uri = _pendingInvite!;
        _pendingInvite = null;
        _handleIncomingUri(uri);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _dynamicLinkSub?.cancel();
    _appLinkSub?.cancel();
    super.dispose();
  }

  void _initializeNotificationPreferences() {
    _notificationPreferences = NotificationPreferences();
    NotificationService().setNotificationPreferences(_notificationPreferences);
  }

  Future<void> _initDynamicLinks() async {
    // Handle links when app is already open
    // ignore: deprecated_member_use
    _dynamicLinkSub = FirebaseDynamicLinks.instance.onLink.listen((dynamicLink) {
      _handleDynamicLink(dynamicLink.link);
    }, onError: (error) {
      debugPrint('onLink error: $error');
    });

    // Handle initial link that opened the app
    // ignore: deprecated_member_use
    final PendingDynamicLinkData? initialLink =
        // ignore: deprecated_member_use
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
      _appLinkSub = _appLinks!.uriLinkStream.listen((uri) {
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
          barrierDismissible: false,
          builder: (dialogContext) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('groups').doc(groupId).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return AlertDialog(
                    backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      side: BorderSide(
                        color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
                        width: 1,
                      ),
                    ),
                    content: SizedBox(
                      height: 80,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                        ),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                  return AlertDialog(
                    backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      side: BorderSide(
                        color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
                        width: 1,
                      ),
                    ),
                    title: Text(
                      'Group Not Found',
                      style: AppTextStyles.h2.copyWith(
                        color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                        fontSize: 20,
                      ),
                    ),
                    content: Text(
                      'This group link is invalid or the group has been deleted.',
                      style: AppTextStyles.bodyM.copyWith(
                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(
                          'Dismiss',
                          style: AppTextStyles.button.copyWith(
                            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                final groupData = snapshot.data!.data() as Map<String, dynamic>?;
                final groupName = groupData?['name'] ?? 'Unnamed Group';

                // Check if user is already a member
                final members = groupData?['members'] as List? ?? [];
                final isAlreadyMember = members.contains(FirebaseAuth.instance.currentUser?.uid);

                if (isAlreadyMember) {
                  return AlertDialog(
                    backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      side: BorderSide(
                        color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
                        width: 1,
                      ),
                    ),
                    title: Text(
                      'Already a Member',
                      style: AppTextStyles.h2.copyWith(
                        color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                        fontSize: 20,
                      ),
                    ),
                    content: Text(
                      'You are already a member of "$groupName".',
                      style: AppTextStyles.bodyM.copyWith(
                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(
                          'Close',
                          style: AppTextStyles.button.copyWith(
                            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                          foregroundColor: isDark ? AppColors.textDarkPrimary : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          navigatorKey.currentState?.push(
                            MaterialPageRoute(
                              builder: (_) => GroupDetailScreen(groupId: groupId),
                            ),
                          );
                        },
                        child: const Text('View Group', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  );
                }

                return AlertDialog(
                  backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    side: BorderSide(
                      color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
                      width: 1,
                    ),
                  ),
                  title: Text(
                    'Join Group?',
                    style: AppTextStyles.h2.copyWith(
                      color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                      fontSize: 20,
                    ),
                  ),
                  content: Text(
                    'Are you sure you want to join the group "$groupName"?',
                    style: AppTextStyles.bodyM.copyWith(
                      color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        'Cancel',
                        style: AppTextStyles.button.copyWith(
                          color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                        foregroundColor: isDark ? AppColors.textDarkPrimary : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        debugPrint('DeepLink: joining groupId=$groupId');
                        await _joinGroup(groupId);
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Joined "$groupName" successfully!'),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                        // Navigate directly to the newly joined group details screen
                        navigatorKey.currentState?.push(
                          MaterialPageRoute(
                            builder: (_) => GroupDetailScreen(groupId: groupId),
                          ),
                        );
                      },
                      child: const Text('Join', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                );
              },
            );
          },
        );
      } else {
        debugPrint('DeepLink: group link missing id parameter');
      }
    }

    final isFriendInviteLink =
        uri.pathSegments.contains('friend-invite') || uri.host == 'friend-invite';
    if (isFriendInviteLink) {
      final inviterUid = uri.queryParameters['inviter'];
      if (inviterUid != null) {
        debugPrint('DeepLink: detected friend invite link, inviterUid=$inviterUid');
        showDialog(
          context: ctx,
          barrierDismissible: false,
          builder: (dialogContext) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(inviterUid).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return AlertDialog(
                    backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      side: BorderSide(
                        color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
                        width: 1,
                      ),
                    ),
                    content: SizedBox(
                      height: 80,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                        ),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                  return AlertDialog(
                    backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      side: BorderSide(
                        color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
                        width: 1,
                      ),
                    ),
                    title: Text(
                      'User Not Found',
                      style: AppTextStyles.h2.copyWith(
                        color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                        fontSize: 20,
                      ),
                    ),
                    content: Text(
                      'This user link is invalid or the user no longer exists.',
                      style: AppTextStyles.bodyM.copyWith(
                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(
                          'Dismiss',
                          style: AppTextStyles.button.copyWith(
                            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                final inviterName = userData?['name'] ?? 'A user';
                final inviterEmail = userData?['email'] ?? '';

                // Check if already friends
                final friendsRef = FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .collection('friends');

                return FutureBuilder<DocumentSnapshot>(
                  future: friendsRef.doc(inviterUid).get(),
                  builder: (context, friendSnapshot) {
                    final isAlreadyFriend =
                        friendSnapshot.hasData && friendSnapshot.data!.exists;

                    if (isAlreadyFriend) {
                      return AlertDialog(
                        backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                          side: BorderSide(
                            color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
                            width: 1,
                          ),
                        ),
                        title: Text(
                          'Already Friends',
                          style: AppTextStyles.h2.copyWith(
                            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                            fontSize: 20,
                          ),
                        ),
                        content: Text(
                          'You are already friends with $inviterName.',
                          style: AppTextStyles.bodyM.copyWith(
                            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: Text(
                              'Close',
                              style: AppTextStyles.button.copyWith(
                                color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return AlertDialog(
                      backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        side: BorderSide(
                          color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
                          width: 1,
                        ),
                      ),
                      title: Text(
                        'Add Friend?',
                        style: AppTextStyles.h2.copyWith(
                          color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                          fontSize: 20,
                        ),
                      ),
                      content: Text(
                        'Add $inviterName as a friend?',
                        style: AppTextStyles.bodyM.copyWith(
                          color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: Text(
                            'Cancel',
                            style: AppTextStyles.button.copyWith(
                              color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                            foregroundColor: isDark ? AppColors.textDarkPrimary : Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            debugPrint('DeepLink: adding friend $inviterUid');
                            final friend = Friend(
                              uid: inviterUid,
                              email: inviterEmail,
                              name: inviterName,
                              photoUrl: userData?['photoUrl'],
                            );
                            await FriendService().addFriend(friend);
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('$inviterName added to friends!'),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          child: const Text('Add Friend', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      } else {
        debugPrint('DeepLink: friend invite link missing inviter parameter');
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

    // Mark the invite as accepted if an email is present
    if (user.email != null && user.email!.isNotEmpty) {
      try {
        await groupRef
            .collection('invites')
            .doc(user.email)
            .update({'status': 'accepted'});
      } catch (_) {
        // Invite doc might not exist if joined via universal link directly
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => _notificationPreferences),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'SliceIt',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
            routes: {
              '/expenses': (context) => const ExpensesScreen(),
              '/analytics': (context) => const AnalyticsScreen(),
              '/split': (context) => const SplitBillsScreen(),
              '/profile': (context) => const ProfileScreen(),
              '/groups': (context) => const GroupsScreen(),
              '/split_history': (context) => const SplitHistoryScreen(),
              '/subscriptions': (context) => const SubscriptionsScreen(),
              '/notifications': (context) => const NotificationsScreen(),
              '/add_friend': (context) => const AddFriendScreen(),
              '/create_split_bill': (context) {
                final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
                return CreateSplitBillScreen(
                  lines: args?['lines'] ?? const [],
                  receiptImage: args?['receiptImage'],
                );
              },
              '/settlements': (context) {
                final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
                return SettlementHistoryScreen(
                  groupId: args?['groupId'] ?? '',
                );
              },
            },
          );
        },
      ),
    );
  }
}
