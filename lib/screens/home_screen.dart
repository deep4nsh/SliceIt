import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import '../widgets/app_card.dart';
import '../widgets/app_button.dart' show AppButton, ButtonVariant;
import '../services/home_stats_service.dart';
import '../services/app_notification_service.dart';

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
          AppCard(
            margin: EdgeInsets.zero,
            interactive: false,
            child: Column(
              children: [
                _buildActivityItem(
                  'Dinner at XYZ',
                  '₹ 1,200',
                  '2 days ago',
                  Icons.restaurant_rounded,
                ),
                const Divider(
                  color: AppColors.borderDefault,
                  height: 1,
                  thickness: 1,
                ),
                _buildActivityItem(
                  'Paid Deepansh',
                  '₹ 500',
                  'Settlement • 1 day ago',
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                ),
                const Divider(
                  color: AppColors.borderDefault,
                  height: 1,
                  thickness: 1,
                ),
                _buildActivityItem(
                  'Added to Friends trip',
                  '₹ 2,500',
                  '3 days ago',
                  Icons.people_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.gapMd),
          Center(
            child: AppButton(
              label: 'View All Activity',
              variant: ButtonVariant.tertiary,
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
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
          AppCard(
            margin: EdgeInsets.zero,
            interactive: false,
            child: Column(
              children: [
                _buildGroupItem(
                  'Friends Trip',
                  '3 members',
                  'You owe: ₹ 1,200',
                  isOwe: true,
                ),
                const Divider(
                  color: AppColors.borderDefault,
                  height: 1,
                  thickness: 1,
                ),
                _buildGroupItem(
                  'Apartment',
                  '2 members',
                  'Owed to you: ₹ 5,030',
                  isOwe: false,
                ),
              ],
            ),
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
          const SizedBox(height: AppSpacing.gapSm),
          Text(
            balance,
            style: AppTextStyles.body.copyWith(
              color: isOwe ? AppColors.error : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}