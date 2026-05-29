import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/friend_model.dart';
import '../services/friend_service.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import '../widgets/modern_card.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/mesh_background.dart';
import 'add_friend_screen.dart';
import 'split_bill_detail_screen.dart';
import 'create_split_bill_screen.dart';

/// Premium modernized SplitBillsScreen showcasing Bento-grid summary layouts,
/// native vector MeshBackground visualization, high-contrast states, and smooth entrance choreography.
class SplitBillsScreen extends StatefulWidget {
  const SplitBillsScreen({super.key});

  @override
  State<SplitBillsScreen> createState() => _SplitBillsScreenState();
}

class _SplitBillsScreenState extends State<SplitBillsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FriendService _friendService = FriendService();

  final picker = ImagePicker();

  Future<void> _processImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    final imageFile = File(pickedFile.path);

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateSplitBillScreen(lines: const [], receiptImage: imageFile),
      ),
    );
  }

  Future<void> _createNewBill(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface1,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
          border: Border.all(
            color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top grab handle indicator
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              "Create Split Bill",
              style: AppTextStyles.h2.copyWith(
                color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 16),
            _buildOptionTile(
              icon: Icons.camera_alt_rounded,
              iconColor: AppColors.secondaryAccent,
              title: "Take Photo of Bill",
              subtitle: "Attach a reference receipt image from camera",
              onTap: () async {
                Navigator.pop(context);
                await _processImage(ImageSource.camera);
              },
              isDark: isDark,
            ),
            _buildOptionTile(
              icon: Icons.photo_library_rounded,
              iconColor: AppColors.accentViolet,
              title: "Upload Bill Image",
              subtitle: "Attach a reference photo for transparency",
              onTap: () async {
                Navigator.pop(context);
                await _processImage(ImageSource.gallery);
              },
              isDark: isDark,
            ),
            _buildOptionTile(
              icon: Icons.edit_rounded,
              iconColor: AppColors.primaryAccent,
              title: "Enter Manually",
              subtitle: "Define allocations, itemized splits, and share ratios",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateSplitBillScreen(lines: [], receiptImage: null),
                  ),
                );
              },
              isDark: isDark,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: isDark ? 0.15 : 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: iconColor.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyL.copyWith(
          color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.label.copyWith(
          color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
              .withValues(alpha: 0.8),
          fontSize: 11,
          fontWeight: FontWeight.normal,
          letterSpacing: 0,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
            .withValues(alpha: 0.4),
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          title: Text(
            "Split Bills",
            style: AppTextStyles.h2.copyWith(
              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: Icon(
                  Icons.notifications_none_rounded,
                  color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                ),
                onPressed: () {},
              ),
            ),
          ],
        ),
        body: Builder(
          builder: (context) {
            final userEmail = user?.email;
            final hasEmail = userEmail != null && userEmail.isNotEmpty;
            if (!hasEmail) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  child: ModernCard(
                    color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mark_email_unread_rounded,
                          size: 48,
                          color: AppColors.warning.withValues(alpha: 0.8),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Email Required",
                          style: AppTextStyles.h3.copyWith(
                            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Please update your email address in your Profile to view and manage split bills seamlessly.",
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyM.copyWith(
                            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(
                left: AppSpacing.screenPadding,
                right: AppSpacing.screenPadding,
                top: 8,
                bottom: 120, // Pad extra space for bottom floating main nav shell
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Real-time Bento-grid Financial metrics engine
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('split_bills')
                        .where('participants', arrayContains: userEmail)
                        .orderBy('createdAt', descending: true)
                        .limit(20)
                        .snapshots(),
                    builder: (context, snapshot) {
                      double totalYouOwe = 0;
                      double totalOwedToYou = 0;

                      if (snapshot.hasData) {
                        final docs = snapshot.data!.docs;
                        final currentUserEmail = user?.email;

                        for (var doc in docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final createdBy = data['createdBy'] as String?;
                          final totalAmount = (data['totalAmount'] as num).toDouble();
                          final participants = (data['participants'] as List?)?.cast<String>() ?? [];
                          final paidStatus = (data['paidStatus'] as Map?)?.cast<String, bool>() ?? {};
                          final splitType = data['splitType'] as String? ?? 'equal';
                          final amounts = (data['amounts'] as Map?)?.cast<String, num>() ?? {};

                          if (createdBy == currentUserEmail) {
                            // People owe the current user
                            for (var participant in participants) {
                              if (participant != currentUserEmail) {
                                final isPaid = paidStatus[participant] ?? false;
                                if (!isPaid) {
                                  double amountOwed = 0;
                                  if (splitType.contains('unequal') || splitType.contains('itemized')) {
                                    amountOwed = (amounts[participant] ?? 0).toDouble();
                                  } else {
                                    amountOwed = participants.isNotEmpty ? totalAmount / participants.length : 0;
                                  }
                                  totalOwedToYou += amountOwed;
                                }
                              }
                            }
                          } else {
                            // Current user might owe the creator
                            final isPaid = paidStatus[currentUserEmail] ?? false;
                            if (!isPaid) {
                              double amountOwed = 0;
                              if (splitType.contains('unequal') || splitType.contains('itemized')) {
                                amountOwed = (amounts[currentUserEmail] ?? 0).toDouble();
                              } else {
                                amountOwed = participants.isNotEmpty ? totalAmount / participants.length : 0;
                              }
                              totalYouOwe += amountOwed;
                            }
                          }
                        }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Two-column secondary Bento row
                          Row(
                            children: [
                              Expanded(
                                child: ModernCard(
                                  margin: EdgeInsets.zero,
                                  padding: const EdgeInsets.all(16),
                                  color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'YOU OWE',
                                            style: AppTextStyles.label.copyWith(
                                              color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                                                  .withValues(alpha: 0.8),
                                              fontSize: 10,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: AppColors.error.withValues(alpha: 0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.arrow_outward_rounded, color: AppColors.error, size: 14),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        "₹${totalYouOwe.toStringAsFixed(2)}",
                                        style: AppTextStyles.h2.copyWith(
                                          color: totalYouOwe > 0 
                                              ? AppColors.error 
                                              : (isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ModernCard(
                                  margin: EdgeInsets.zero,
                                  padding: const EdgeInsets.all(16),
                                  color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'OWED TO YOU',
                                            style: AppTextStyles.label.copyWith(
                                              color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                                                  .withValues(alpha: 0.8),
                                              fontSize: 10,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: AppColors.success.withValues(alpha: 0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.arrow_downward_rounded, color: AppColors.success, size: 14),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        "₹${totalOwedToYou.toStringAsFixed(2)}",
                                        style: AppTextStyles.h2.copyWith(
                                          color: totalOwedToYou > 0 
                                              ? AppColors.success 
                                              : (isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ).animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0),
                          const SizedBox(height: 24),

                          // Pending Bills Section Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Pending Bills",
                                style: AppTextStyles.h3.copyWith(
                                  color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pushNamed('/split_history'),
                                child: Text(
                                  "View All",
                                  style: AppTextStyles.label.copyWith(
                                    color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Pending Bills Feed
                          if (!snapshot.hasData)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                  color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                                ),
                              ),
                            )
                          else if (snapshot.data!.docs.isEmpty)
                            ModernCard(
                              color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                              padding: const EdgeInsets.all(20),
                              child: Center(
                                child: Text(
                                  "No pending split bills at the moment",
                                  style: AppTextStyles.bodyM.copyWith(
                                    color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: snapshot.data!.docs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final doc = snapshot.data!.docs[index];
                                final data = doc.data() as Map<String, dynamic>;
                                return AnimatedListItem(
                                  index: index,
                                  child: _buildBillCard(context, data, doc.id, userEmail, isDark),
                                );
                              },
                            ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Friends Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Friends",
                        style: AppTextStyles.h3.copyWith(
                          color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.person_add_alt_1_rounded,
                          color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                          size: 20,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddFriendScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Friends Feed Stream
                  StreamBuilder<List<Friend>>(
                    stream: _friendService.getFriendsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                            ),
                          ),
                        );
                      }
                      final friends = snapshot.data ?? [];
                      if (friends.isEmpty) {
                        return ModernCard(
                          color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              "No friends added yet. Add friends to split bills instantly!",
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyM.copyWith(
                                color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: friends.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return AnimatedListItem(
                            index: index,
                            child: _buildFriendItem(friends[index], isDark),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 80.0),
          child: FloatingActionButton.extended(
            heroTag: 'split_bill_fab',
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
            onPressed: () => _createNewBill(context),
            backgroundColor: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
            icon: Icon(
              Icons.add_rounded,
              color: isDark ? AppColors.textDarkPrimary : Colors.white,
            ),
            label: Text(
              "Create Bill",
              style: AppTextStyles.button.copyWith(
                color: isDark ? AppColors.textDarkPrimary : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBillCard(
    BuildContext context,
    Map<String, dynamic> data,
    String splitId,
    String? userEmail,
    bool isDark,
  ) {
    final title = data['title'] ?? 'Unknown';
    final totalAmount = (data['totalAmount'] as num).toDouble();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final dateStr = createdAt != null 
        ? "${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}" 
        : "";

    final createdBy = data['createdBy'];
    final isOwed = createdBy == userEmail;
    final statusText = isOwed ? "You are owed" : "You owe";
    final statusColor = isOwed ? AppColors.success : AppColors.error;

    // Estimate share or specific amount
    final participants = (data['participants'] as List?)?.cast<String>() ?? [];
    final amounts = (data['amounts'] as Map?)?.cast<String, num>() ?? {};
    final splitType = data['splitType'] as String? ?? 'equal';

    double shareAmount = 0;
    if (isOwed) {
      // Calculate amount owed to current user by those who haven't paid
      final paidStatus = (data['paidStatus'] as Map?)?.cast<String, bool>() ?? {};
      for (var p in participants) {
        if (p != userEmail && !(paidStatus[p] ?? false)) {
          if (splitType.contains('unequal') || splitType.contains('itemized')) {
            shareAmount += (amounts[p] ?? 0).toDouble();
          } else {
            shareAmount += participants.isNotEmpty ? totalAmount / participants.length : 0;
          }
        }
      }
    } else {
      // Amount current user owes
      if (splitType.contains('unequal') || splitType.contains('itemized')) {
        shareAmount = (amounts[userEmail] ?? 0).toDouble();
      } else {
        shareAmount = participants.isNotEmpty ? totalAmount / participants.length : 0;
      }
    }

    return ModernCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SplitBillDetailScreen(splitId: splitId)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent)
                  .withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent)
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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
                  dateStr,
                  style: AppTextStyles.label.copyWith(
                    color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                        .withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "₹${totalAmount.toStringAsFixed(2)}",
                style: AppTextStyles.bodyL.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "$statusText ₹${shareAmount.toStringAsFixed(2)}",
                  style: AppTextStyles.label.copyWith(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFriendItem(Friend friend, bool isDark) {
    final name = friend.name != null && friend.name!.trim().isNotEmpty 
        ? friend.name! 
        : friend.email.split('@').first;

    return ModernCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent)
                    .withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
              backgroundImage: friend.photoUrl != null ? NetworkImage(friend.photoUrl!) : null,
              onBackgroundImageError: (_, __) {},
              child: friend.photoUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: AppTextStyles.h3.copyWith(
                        color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
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
                  friend.email,
                  style: AppTextStyles.label.copyWith(
                    color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                        .withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                .withValues(alpha: 0.4),
            size: 20,
          ),
        ],
      ),
    );
  }
}
