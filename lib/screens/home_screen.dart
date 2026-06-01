import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import '../widgets/app_card.dart';
import '../widgets/app_button.dart' show AppButton, ButtonVariant;
import '../services/home_stats_service.dart';
import '../services/app_notification_service.dart';
import '../services/shell_navigation_provider.dart';
import 'group_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final statsService = HomeStatsService();

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: CustomScrollView(
        physics: const ScrollPhysics(),
        slivers: [
          // HEADER: Profile + Notifications
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: _buildHeader(context, user),
            ),
          ),

          // BALANCE CARD: Primary focus
          SliverToBoxAdapter(
            child: StreamBuilder<Map<String, double>>(
              stream: statsService.getHomeStats(),
              initialData: const {'spent': 0.0, 'owe': 0.0, 'owed': 0.0},
              builder: (context, snapshot) {
                final stats = snapshot.data ?? {'spent': 0.0, 'owe': 0.0, 'owed': 0.0};
                final netBalance = (stats['owed'] ?? 0) - (stats['owe'] ?? 0);
                return _buildBalanceCard(context, netBalance);
              },
            ),
          ),

          // BREAKDOWN: You owe vs owed
          SliverToBoxAdapter(
            child: StreamBuilder<Map<String, double>>(
              stream: statsService.getHomeStats(),
              initialData: const {'spent': 0.0, 'owe': 0.0, 'owed': 0.0},
              builder: (context, snapshot) {
                final stats = snapshot.data ?? {'spent': 0.0, 'owe': 0.0, 'owed': 0.0};
                return _buildBreakdownCard(context, stats['owe'] ?? 0, stats['owed'] ?? 0);
              },
            ),
          ),

          // ACTIONS: 2 primary buttons
          SliverToBoxAdapter(
            child: _buildActionButtons(context),
          ),

          // ACTIVITY SECTION: Recent events
          SliverToBoxAdapter(
            child: _buildActivitySection(context),
          ),

          // GROUPS SECTION: Quick summary
          SliverToBoxAdapter(
            child: _buildGroupsSection(context),
          ),

          // FOOTER: Safe area for nav bar
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.safeAreaBottom)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, User? user) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.base,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.darkSurface2,
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: user?.photoURL == null
                    ? const Icon(Icons.person, color: AppColors.textSecondary)
                    : null,
              ),
              const SizedBox(width: AppSpacing.gapMd),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.displayName?.split(' ').first ?? "User",
                    style: AppTextStyles.bodyL.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Welcome back',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          FutureBuilder<int>(
            future: AppNotificationService().getUnreadCount(user?.uid ?? ''),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                    onPressed: () => Navigator.pushNamed(context, '/notifications'),
                    tooltip: 'Notifications',
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, double balance) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: AppCard(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.gapMd),
        padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
        interactive: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Balance',
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.gapSm),
            Text(
              '₹ ${balance.toStringAsFixed(2)}',
              style: AppTextStyles.display,
            ),
            const SizedBox(height: AppSpacing.gapSm),
            Text(
              balance >= 0 ? 'You are owed this amount' : 'You owe this amount',
              style: AppTextStyles.helper.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownCard(BuildContext context, double youOwe, double owedToYou) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: AppCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.gapMd),
        interactive: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You Owe',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.gapXs),
                  Text(
                    '₹ ${youOwe.toStringAsFixed(2)}',
                    style: AppTextStyles.h3.copyWith(
                      color: youOwe > 0 ? AppColors.error : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Owed to You',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.gapXs),
                  Text(
                    '₹ ${owedToYou.toStringAsFixed(2)}',
                    style: AppTextStyles.h3.copyWith(
                      color: owedToYou > 0 ? AppColors.success : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.gapLg,
      ),
      child: Row(
        children: [
          Expanded(
            child: AppButton(
              label: 'Add Expense',
              icon: Icons.add_rounded,
              onPressed: () => Navigator.pushNamed(context, '/create_split_bill'),
            ),
          ),
          const SizedBox(width: AppSpacing.gapSm),
          Expanded(
            child: AppButton(
              label: 'Settle',
              variant: ButtonVariant.secondary,
              icon: Icons.arrow_forward_rounded,
              onPressed: () => Navigator.pushNamed(context, '/settlements'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firestore = FirebaseFirestore.instance;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.gapLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: AppSpacing.gapMd),
          StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collectionGroup('expenses')
                .where('participants', arrayContains: user?.uid)
                .orderBy('createdAt', descending: true)
                .limit(3)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 100,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return AppCard(
                  margin: EdgeInsets.zero,
                  interactive: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.gapMd),
                    child: Text(
                      'No recent activity yet.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }

              final activities = snapshot.data!.docs;

              return AppCard(
                margin: EdgeInsets.zero,
                interactive: false,
                child: Column(
                  children: List.generate(
                    activities.length,
                    (index) {
                      final activityData = activities[index].data() as Map<String, dynamic>;
                      final description = activityData['description'] ?? 'Expense';
                      final amount = activityData['amount'] ?? 0.0;
                      final createdAt = activityData['createdAt'] as Timestamp?;
                      final formattedDate = createdAt != null
                          ? _formatDate(createdAt.toDate())
                          : 'Recently';

                      return Column(
                        children: [
                          _buildActivityItem(
                            description,
                            '₹ ${amount.toStringAsFixed(2)}',
                            formattedDate,
                            Icons.receipt_rounded,
                          ),
                          if (index < activities.length - 1)
                            const Divider(
                              color: AppColors.borderDefault,
                              height: 1,
                              thickness: 1,
                            ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.gapMd),
          Center(
            child: AppButton(
              label: 'View All Activity',
              variant: ButtonVariant.tertiary,
              onPressed: () {
                Provider.of<ShellNavigationProvider>(context, listen: false).setIndex(2);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildActivityItem(
    String title,
    String amount,
    String timestamp,
    IconData icon, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.gapMd),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (color ?? AppColors.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              icon,
              color: color ?? AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  timestamp,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: AppTextStyles.h3.copyWith(
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsSection(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firestore = FirebaseFirestore.instance;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.gapLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Groups You\'re In',
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: AppSpacing.gapMd),
          StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('groups')
                .where('members', arrayContains: user?.uid)
                .limit(3)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 100,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return AppCard(
                  margin: EdgeInsets.zero,
                  interactive: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.gapMd),
                    child: Text(
                      'No groups yet. Create or join a group to get started.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }

              final groups = snapshot.data!.docs;

              return GestureDetector(
                onTap: () {
                  Provider.of<ShellNavigationProvider>(context, listen: false).setIndex(1);
                },
                child: AppCard(
                  margin: EdgeInsets.zero,
                  interactive: true,
                  child: Column(
                    children: List.generate(
                      groups.length,
                      (index) {
                        final groupDoc = groups[index];
                        final groupId = groupDoc.id;
                        final groupData = groupDoc.data() as Map<String, dynamic>;
                        final groupName = groupData['name'] ?? 'Unknown Group';
                        final members = groupData['members'] as List<dynamic>? ?? [];

                        return Column(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GroupDetailScreen(groupId: groupId),
                                ),
                              ),
                              child: _buildGroupItem(
                                groupName,
                                '${members.length} member${members.length != 1 ? 's' : ''}',
                                '', // Balance calculation would need expense data
                                isOwe: false,
                              ),
                            ),
                            if (index < groups.length - 1)
                              const Divider(
                                color: AppColors.borderDefault,
                                height: 1,
                                thickness: 1,
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGroupItem(
    String groupName,
    String members,
    String balance, {
    required bool isOwe,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.gapMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    groupName,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    members,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
          if (balance.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.gapSm),
            Text(
              balance,
              style: AppTextStyles.body.copyWith(
                color: isOwe ? AppColors.error : AppColors.success,
              ),
            ),
          ],
        ],
      ),
    );
  }
}