import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF2A4D69), // Blue background
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A4D69),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "SliceIt",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {},
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        decoration: const BoxDecoration(
          color: Color(0xFFF4F7F8),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 👤 Welcome Header
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : const AssetImage('assets/images/user.png')
                  as ImageProvider,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back,',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    Text(
                      user?.displayName ?? user?.phoneNumber ?? "User",
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 25),

            // 💰 Total Overview Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFA4B640),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: const [
                  Text(
                    'Your Total Balance',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '₹ 12,540',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // 🧩 Feature Cards Grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1,
                children: [
                  _buildFeatureCard(
                    context,
                    icon: Icons.account_balance_wallet_outlined,
                    title: "Expenses",
                    color: const Color(0xFF2A4D69),
                    route: '/expenses',
                    
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.bar_chart_outlined,
                    title: "Analytics",
                    color: const Color(0xFF41729F),
                    route: '/analytics',
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.people_alt_outlined,
                    title: "Split Bills",
                    color: const Color(0xFF5885AF),
                    route: '/split',
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.history,
                    title: "Split History",
                    color: const Color(0xFF8DC6D9),
                    route: '/split_history',
                  ),
                   _buildFeatureCard(
                    context,
                    icon: Icons.group_work_outlined,
                    title: "Groups",
                    color: const Color(0xFF6E92B4),
                    route: '/groups',
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.person_outline,
                    title: "Profile",
                    color: const Color(0xFF74A4BC),
                    route: '/profile',
                  ),
                ],
              ),
            ),

            // 🚪 Logout Button
            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Ensure complete sign-out (Firebase + Google)
                  await AuthService().signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  "Logout",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A4D69),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🧱 Reusable Feature Card Widget
  Widget _buildFeatureCard(BuildContext context,
      {required IconData icon,
        required String title,
        required Color color,
        required String route}) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, route);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}