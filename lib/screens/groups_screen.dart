import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import '../widgets/app_card.dart';
import '../widgets/app_button.dart' show AppButton, ButtonVariant, ButtonSize;
import '../screens/group_detail_screen.dart';

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

  Future<void> _createGroup() async {
    final groupNameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => _buildCreateGroupDialog(groupNameController),
    );
  }

  Widget _buildCreateGroupDialog(TextEditingController controller) {
    return Dialog(
      backgroundColor: AppColors.darkSurface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: const BorderSide(
          color: AppColors.borderDefault,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gapLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Group',
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: AppSpacing.gapMd),
            TextField(
              controller: controller,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Group name',
                hintStyle: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base,
                  vertical: AppSpacing.gapSm,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  borderSide: const BorderSide(color: AppColors.borderDefault),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.gapLg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: 'Cancel',
                  variant: ButtonVariant.secondary,
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: AppSpacing.gapSm),
                AppButton(
                  label: 'Create',
                  onPressed: () async {
                    if (controller.text.trim().isEmpty) return;
                    await _firestore.collection('groups').add({
                      'name': controller.text.trim(),
                      'createdBy': _auth.currentUser!.uid,
                      'members': [_auth.currentUser!.uid],
                    });
                    if (mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
                vertical: AppSpacing.base,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Groups',
                    style: AppTextStyles.h1,
                  ),
                  AppButton(
                    label: 'New',
                    icon: Icons.add_rounded,
                    size: ButtonSize.small,
                    onPressed: _createGroup,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.gapMd),
            // Groups List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getGroupsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.groups_rounded,
                            size: 64,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: AppSpacing.gapMd),
                          Text(
                            'No groups yet',
                            style: AppTextStyles.h3.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.gapSm),
                          Text(
                            'Create or join a group to get started',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding,
                    ),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final groupDoc = snapshot.data!.docs[index];
                      final groupId = groupDoc.id;
                      final groupData = groupDoc.data() as Map<String, dynamic>;
                      final groupName = groupData['name'] ?? 'Unknown Group';
                      final members = groupData['members'] as List<dynamic>? ?? [];

                      return _buildGroupCard(
                        context: context,
                        groupId: groupId,
                        groupName: groupName,
                        memberCount: members.length,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard({
    required BuildContext context,
    required String groupId,
    required String groupName,
    required int memberCount,
  }) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.gapMd),
      interactive: true,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupDetailScreen(groupId: groupId),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupName,
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.gapXs),
                    Text(
                      '$memberCount member${memberCount != 1 ? 's' : ''}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: AppButton(
                  label: 'Open',
                  variant: ButtonVariant.secondary,
                  size: ButtonSize.small,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupDetailScreen(groupId: groupId),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.gapSm),
              Expanded(
                child: AppButton(
                  label: 'Share',
                  variant: ButtonVariant.tertiary,
                  size: ButtonSize.small,
                  icon: Icons.share_rounded,
                  onPressed: () => _shareGroup(groupId, groupName),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _shareGroup(String groupId, String groupName) async {
    final deepLink = 'https://sliceit.app/group/$groupId';
    await Share.share(
      'Join "$groupName" on SliceIt!\n\n$deepLink',
      subject: 'Join $groupName',
    );
  }
}
