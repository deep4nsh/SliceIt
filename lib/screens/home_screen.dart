import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import '../widgets/modern_card.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/mesh_background.dart';
import '../services/home_stats_service.dart';

/// State-of-the-art restyled HomeScreen featuring rich Bento-grid geometry,
/// atmospheric MeshBackground visualization, and unified Poppins typography scale.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final statsService = HomeStatsService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MeshBackground(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Core Financial Bento Dashboard
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: StreamBuilder<Map<String, double>>(
                stream: statsService.getHomeStats(),
                initialData: const {'spent': 0.0, 'owe': 0.0, 'owed': 0.0},
                builder: (context, snapshot) {
                  final stats = snapshot.data ?? {'spent': 0.0, 'owe': 0.0, 'owed': 0.0};
                  final totalSpent = stats['spent']!;
                  final youOwe = stats['owe']!;
                  final owedToYou = stats['owed']!;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        // Restyled profile header row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent).withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                                    backgroundImage: user?.photoURL != null
                                        ? NetworkImage(user!.photoURL!)
                                        : const AssetImage('assets/images/user.png') as ImageProvider,
                                    onBackgroundImageError: (_, __) {},
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Welcome back,",
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      user?.displayName?.split(' ').first ?? "User",
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.notifications_none_rounded,
                                color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                              ),
                              onPressed: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Bento Primary Banner: Total Spent
                        ModernCard(
                          margin: EdgeInsets.zero,
                          gradient: LinearGradient(
                          colors: isDark
                              ? [AppColors.primaryAccent.withValues(alpha: 0.85), const Color(0xFF1E203C)]
                              : [AppColors.primaryAccent, AppColors.secondaryAccent.withValues(alpha: 0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Spent',
                                  style: AppTextStyles.label.copyWith(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '₹ ${totalSpent.toStringAsFixed(2)}',
                              style: AppTextStyles.h1.copyWith(
                                color: Colors.white,
                                fontSize: 32,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
                      
                      const SizedBox(height: 16),
                      
                      // Bento Secondary Cells: Owe vs Owed
                      Row(
                        children: [
                          Expanded(
                            child: ModernCard(
                              margin: EdgeInsets.zero,
                              padding: const EdgeInsets.all(16),
                              color: isDark
                                  ? AppColors.error.withValues(alpha: 0.12)
                                  : AppColors.error.withValues(alpha: 0.08),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.arrow_upward_rounded, color: AppColors.error, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        "You Owe",
                                        style: AppTextStyles.label.copyWith(color: AppColors.error),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "₹ ${youOwe.toStringAsFixed(2)}",
                                    style: AppTextStyles.h3.copyWith(
                                      color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ModernCard(
                              margin: EdgeInsets.zero,
                              padding: const EdgeInsets.all(16),
                              color: isDark
                                  ? AppColors.success.withValues(alpha: 0.12)
                                  : AppColors.success.withValues(alpha: 0.08),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.arrow_downward_rounded, color: AppColors.success, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Owed to You",
                                        style: AppTextStyles.label.copyWith(color: AppColors.success),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "₹ ${owedToYou.toStringAsFixed(2)}",
                                    style: AppTextStyles.h3.copyWith(
                                      color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ).animate().fade(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),

                      const SizedBox(height: 32),
                      
                      Text(
                        "Quick Actions",
                        style: AppTextStyles.h2.copyWith(
                          color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                          fontSize: 20,
                        ),
                      ).animate().fade(duration: 400.ms, delay: 200.ms),
                      
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

          // Synchronized Action Matrix
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.15,
              children: [
                _buildBentoActionCell(
                  context,
                  index: 0,
                  icon: Icons.receipt_long_rounded,
                  title: "Expenses",
                  color: AppColors.secondaryAccent,
                  route: '/expenses',
                  isDark: isDark,
                ),
                _buildBentoActionCell(
                  context,
                  index: 1,
                  icon: Icons.analytics_rounded,
                  title: "Analytics",
                  color: const Color(0xFF8B5CF6),
                  route: '/analytics',
                  isDark: isDark,
                ),
                _buildBentoActionCell(
                  context,
                  index: 2,
                  icon: Icons.call_split_rounded,
                  title: "Split Bills",
                  color: const Color(0xFFF59E0B),
                  route: '/split',
                  isDark: isDark,
                ),
                _buildBentoActionCell(
                  context,
                  index: 3,
                  icon: Icons.history_rounded,
                  title: "History",
                  color: const Color(0xFF10B981),
                  route: '/split_history',
                  isDark: isDark,
                ),
                _buildBentoActionCell(
                  context,
                  index: 4,
                  icon: Icons.groups_rounded,
                  title: "Groups",
                  color: const Color(0xFFEC4899),
                  route: '/groups',
                  isDark: isDark,
                ),
                _buildBentoActionCell(
                  context,
                  index: 5,
                  icon: Icons.person_rounded,
                  title: "Profile",
                  color: const Color(0xFF3B82F6),
                  route: '/profile',
                  isDark: isDark,
                ),
                _buildBentoActionCell(
                  context,
                  index: 6,
                  icon: Icons.event_repeat_rounded,
                  title: "Subscriptions",
                  color: const Color(0xFF14B8A6),
                  route: '/subscriptions',
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // Extra footer scroll headroom to comfortably clear the persistent bottom shell bar
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildBentoActionCell(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String title,
    required Color color,
    required String route,
    required bool isDark,
  }) {
    return AnimatedListItem(
      index: index + 3, // Delays sequential flow after header stats
      child: ModernCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(14),
        color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
        onTap: () => Navigator.pushNamed(context, route),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: color.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(
              title,
              style: AppTextStyles.bodyM.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}