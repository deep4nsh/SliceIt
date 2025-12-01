import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../utils/colors.dart';
import '../widgets/modern_card.dart';
import '../widgets/animated_list_item.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total Balance Card
                  ModernCard(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryOrange, AppColors.primaryPeach],
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
                              'Total Balance',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.wallet, color: Colors.white, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '₹ 12,540',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _buildBalanceAction(Icons.add, "Add Money"),
                            const SizedBox(width: 16),
                            _buildBalanceAction(Icons.arrow_outward, "Send"),
                          ],
                        ),
                      ],
                    ),
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