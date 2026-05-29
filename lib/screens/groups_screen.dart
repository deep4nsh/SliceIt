import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/foundation.dart';

import '../utils/deep_link_config.dart';
import '../screens/group_detail_screen.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import '../services/invite_service.dart';
import '../services/app_notification_service.dart';
import '../widgets/modern_card.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/mesh_background.dart';

/// Modernized GroupsScreen showcasing high-fidelity dark-first design, 
/// glassmorphic item layouts, atmospheric background meshes, and clean typography.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot> _getGroupsStream() {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: _auth.currentUser!.uid)
        .limit(50)
        .snapshots();
  }

  Future<void> _launchEmailComposer(List<String> emails, {required String subject, required String body}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: emails.join(','),
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await Share.share(body, subject: subject);
      }
    } catch (_) {
      await Share.share(body, subject: subject);
    }
  }

  Future<void> _createGroup() async {
    final groupNameController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(
            color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
            width: 1,
          ),
        ),
        title: Text(
          'Create Group',
          style: AppTextStyles.h2.copyWith(
            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
            fontSize: 20,
          ),
        ),
        content: TextField(
          controller: groupNameController,
          style: AppTextStyles.bodyL.copyWith(
            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
          ),
          decoration: InputDecoration(
            labelText: 'Group Name',
            labelStyle: AppTextStyles.bodyM.copyWith(
              color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent).withValues(alpha: 0.3)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
              if (groupNameController.text.trim().isEmpty) return;
              await _firestore.collection('groups').add({
                'name': groupNameController.text.trim(),
                'createdBy': _auth.currentUser!.uid,
                'members': [_auth.currentUser!.uid],
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareGroup(String groupId, String groupName) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(
            color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
            width: 1,
          ),
        ),
        title: Text(
          'Invite by Email',
          style: AppTextStyles.h2.copyWith(
            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
            fontSize: 20,
          ),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            maxLines: 4,
            style: AppTextStyles.bodyM.copyWith(
              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Email addresses',
              hintText: 'Enter comma or newline separated emails',
              labelStyle: AppTextStyles.bodyM.copyWith(
                color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
              ),
              hintStyle: AppTextStyles.bodyM.copyWith(
                color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary).withValues(alpha: 0.5),
                fontSize: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: BorderSide(color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: BorderSide(color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: BorderSide(color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent),
              ),
            ),
            validator: (value) {
              final emails = _parseEmails(value ?? '');
              if (emails.isEmpty) return 'Enter at least one email';
              final invalid = emails.where((e) => !_isValidEmail(e)).toList();
              if (invalid.isNotEmpty) return 'Invalid: ${invalid.join(', ')}';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
              if (!formKey.currentState!.validate()) return;
              final emails = _parseEmails(controller.text);

              // Persist invites
              final batch = _firestore.batch();
              for (final email in emails) {
                final doc = _firestore
                    .collection('groups')
                    .doc(groupId)
                    .collection('invites')
                    .doc(email);
                batch.set(doc, {
                  'email': email,
                  'inviterUid': currentUser.uid,
                  'sentAt': FieldValue.serverTimestamp(),
                  'status': 'pending',
                }, SetOptions(merge: true));
              }
              await batch.commit();

              // Send in-app notifications to existing users
              for (final email in emails) {
                try {
                  final userQuery = await _firestore
                      .collection('users')
                      .where('email', isEqualTo: email)
                      .limit(1)
                      .get();

                  if (userQuery.docs.isNotEmpty) {
                    final uid = userQuery.docs.first.id;
                    await AppNotificationService.writeNotification(
                      uid,
                      type: 'group_invite',
                      title: '$groupName',
                      body: '${currentUser.displayName ?? "Someone"} invited you to join',
                      relatedId: groupId,
                      actionUserName: currentUser.displayName,
                    );
                  }
                } catch (e) {
                  debugPrint('Error sending notification for $email: $e');
                }
              }

              // Send real emails via Cloud Function
              try {
                final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
                final inviterName = userDoc.data()?['name'] ?? currentUser.displayName ?? 'A friend';

                await InviteService.sendGroupInvites(
                  groupId: groupId,
                  inviterUid: currentUser.uid,
                  inviterName: inviterName,
                  groupName: groupName,
                  emails: emails,
                  subject: 'Join my SliceIt group',
                  body: _composeInviteBody(groupId, currentUser.uid),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Invites sent to ${emails.length} recipient(s)', style: AppTextStyles.bodyM),
                      backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.textDarkPrimary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                    ),
                  );
                }
              } catch (_) {
                await _launchEmailComposer(
                  emails,
                  subject: 'Join my SliceIt group',
                  body: _composeInviteBody(groupId, currentUser.uid),
                );
              }

              if (mounted) Navigator.pop(context);
            },
            child: const Text('Send Invites', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  List<String> _parseEmails(String raw) {
    return raw
        .split(RegExp(r'[\n,; ]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email);
  }

  String _composeInviteBody(String groupId, String inviterUid) {
    final httpLink = DeepLinkConfig.groupHttp(groupId, inviterUid);
    final schemeLink = DeepLinkConfig.groupScheme(groupId, inviterUid);
    return 'Hi,\n\nI\'d like you to join my SliceIt group.\n\nJoin link (opens app if installed):\n$httpLink\n\nIf the above does not open the app, tap this:\n$schemeLink\n\nThanks!';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Groups',
            style: AppTextStyles.h2.copyWith(
              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _getGroupsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                ),
              );
            }
            if (snapshot.hasError) {
              debugPrint("Firestore Error in GroupsScreen: ${snapshot.error}");
              return Center(
                child: Text(
                  'Error loading groups. Check logs for details.',
                  style: AppTextStyles.bodyL.copyWith(color: AppColors.error),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isDark ? AppColors.darkSurface2 : AppColors.lightSurface2).withValues(alpha: 0.6),
                        border: Border.all(
                          color: (isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.groups_outlined,
                        size: 48,
                        color: (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent).withValues(alpha: 0.6),
                      ),
                    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 20),
                    Text(
                      'No groups found',
                      style: AppTextStyles.h3.copyWith(
                        color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ).animate().fade(duration: 300.ms, delay: 100.ms),
                    const SizedBox(height: 8),
                    Text(
                      'Create one to start splitting bills!',
                      style: AppTextStyles.bodyM.copyWith(
                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                      ),
                    ).animate().fade(duration: 300.ms, delay: 200.ms),
                  ],
                ),
              );
            }

            final docs = snapshot.data!.docs;

            return ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(
                left: AppSpacing.screenPadding,
                right: AppSpacing.screenPadding,
                top: 8,
                bottom: 120, // Pad for bottom shell nav
              ),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final groupName = data['name'] ?? 'Unnamed Group';
                final groupEmoji = data['emoji'] as String? ?? '';
                final themeColorIndex = data['themeColorIndex'] as int? ?? (index % 5);
                final groupPhotoUrl = data['photoUrl'] as String? ?? '';

                final List<Map<String, dynamic>> groupThemes = [
                  {
                    'color': const Color(0xFF5B6F82),
                    'gradient': [const Color(0xFF5B6F82), const Color(0xFF7A8B9E)],
                  },
                  {
                    'color': const Color(0xFF6B9EAA),
                    'gradient': [const Color(0xFF6B9EAA), const Color(0xFF8BB5BD)],
                  },
                  {
                    'color': const Color(0xFF8F7EAA),
                    'gradient': [const Color(0xFF8F7EAA), const Color(0xFFA597BE)],
                  },
                  {
                    'color': const Color(0xFFD68A65),
                    'gradient': [const Color(0xFFD68A65), const Color(0xFFE2A385)],
                  },
                  {
                    'color': const Color(0xFF5CA387),
                    'gradient': [const Color(0xFF5CA387), const Color(0xFF7CB8A0)],
                  },
                ];

                final activeTheme = groupThemes[themeColorIndex.clamp(0, groupThemes.length - 1)];
                final List<Color> avatarGradient = activeTheme['gradient'] as List<Color>;

                return AnimatedListItem(
                  index: index,
                  child: ModernCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: doc.id)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: groupPhotoUrl.isNotEmpty ? null : LinearGradient(
                              colors: avatarGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            image: groupPhotoUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(groupPhotoUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: groupPhotoUrl.isNotEmpty
                              ? null
                              : Center(
                                  child: Text(
                                    groupEmoji.isNotEmpty ? groupEmoji : (groupName.isNotEmpty ? groupName[0].toUpperCase() : 'G'),
                                    style: AppTextStyles.h3.copyWith(
                                      color: Colors.white,
                                      fontSize: groupEmoji.isNotEmpty ? 22 : 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                groupName,
                                style: AppTextStyles.bodyL.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tap to view split bills',
                                style: AppTextStyles.label.copyWith(
                                  color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                                      .withValues(alpha: 0.7),
                                  fontSize: 10,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.person_add_alt_1_rounded,
                            color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                            size: 20,
                          ),
                          tooltip: 'Invite by email',
                          onPressed: () => _shareGroup(doc.id, groupName),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                              .withValues(alpha: 0.5),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 80.0),
          child: FloatingActionButton.extended(
            heroTag: 'create_group_fab',
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
            onPressed: _createGroup,
            icon: Icon(
              Icons.add_rounded,
              color: isDark ? AppColors.textDarkPrimary : Colors.white,
            ),
            label: Text(
              'Create Group',
              style: AppTextStyles.button.copyWith(
                color: isDark ? AppColors.textDarkPrimary : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
          ),
        ),
      ),
    );
  }
}
