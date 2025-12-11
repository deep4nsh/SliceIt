import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../utils/colors.dart';
import '../widgets/modern_card.dart';
import '../widgets/animated_list_item.dart';
import '../services/home_stats_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final statsService = HomeStatsService();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: true,
            pinned: true,
            backgroundColor: AppColors.backgroundLight,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : const AssetImage('assets/images/user.png') as ImageProvider,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hello,",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      Text(
                        user?.displayName?.split(' ').first ?? "User",
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary),
                onPressed: () {},
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: StreamBuilder<Map<String, double>>(
              stream: statsService.getHomeStats(),
              initialData: const {'spent': 0.0, 'owe': 0.0, 'owed': 0.0},
              builder: (context, snapshot) {
                final stats = snapshot.data ?? {'spent': 0.0, 'owe': 0.0, 'owed': 0.0};
                final totalSpent = stats['spent']!;
                final youOwe = stats['owe']!;
                final owedToYou = stats['owed']!;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total Spent Card
                      ModernCard(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryNavy, Color(0xFF2A2D3E)],
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
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.account_balance_wallet, color: AppColors.primaryGold, size: 20),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹ ${totalSpent.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Debts and Credits
                      Row(
                        children: [
                          Expanded(
                            child: ModernCard(
                              color: AppColors.errorRed.withOpacity(0.1),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("You Owe", style: TextStyle(color: AppColors.errorRed, fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text("₹ ${youOwe.toStringAsFixed(2)}", style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ModernCard(
                              color: AppColors.successGreen.withOpacity(0.1),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Owed to You", style: TextStyle(color: AppColors.successGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text("₹ ${owedToYou.toStringAsFixed(2)}", style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        "Quick Actions",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                _buildAnimatedFeatureCard(
                  context,
                  index: 0,
                  icon: Icons.receipt_long_rounded,
                  title: "Expenses",
                  color: AppColors.secondaryTeal,
                  route: '/expenses',
                ),
                _buildAnimatedFeatureCard(
                  context,
                  index: 1,
                  icon: Icons.analytics_rounded,
                  title: "Analytics",
                  color: const Color(0xFF6C63FF),
                  route: '/analytics',
                ),
                _buildAnimatedFeatureCard(
                  context,
                  index: 2,
                  icon: Icons.call_split_rounded,
                  title: "Split Bills",
                  color: AppColors.primaryOrange,
                  route: '/split',
                ),
                _buildAnimatedFeatureCard(
                  context,
                  index: 3,
                  icon: Icons.history_rounded,
                  title: "History",
                  color: const Color(0xFF4ECDC4),
                  route: '/split_history',
                ),
                _buildAnimatedFeatureCard(
                  context,
                  index: 4,
                  icon: Icons.groups_rounded,
                  title: "Groups",
                  color: AppColors.primaryPeach,
                  route: '/groups',
                ),
                _buildAnimatedFeatureCard(
                  context,
                  index: 5,
                  icon: Icons.person_rounded,
                  title: "Profile",
                  color: AppColors.textPrimary,
                  route: '/profile',
                ),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }

  Widget _buildBalanceAction(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedFeatureCard(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String title,
    required Color color,
    required String route,
  }) {
    return AnimatedListItem(
      index: index,
      child: ModernCard(
        onTap: () => Navigator.pushNamed(context, route),
        color: Colors.white,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}