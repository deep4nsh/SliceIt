import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import '../services/shell_navigation_provider.dart';
import 'home_screen.dart';
import 'groups_screen.dart';
import 'activity_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const List<Widget> _screens = [
    HomeScreen(),
    GroupsScreen(),
    ActivityScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<ShellNavigationProvider>(
      builder: (context, navProvider, child) {
        final currentIndex = navProvider.currentIndex;
        return Scaffold(
          body: IndexedStack(
            index: currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: AppColors.darkSurface1,
              border: Border(
                top: BorderSide(
                  color: AppColors.borderDefault,
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(context, navProvider, 0, Icons.home_rounded, 'Home'),
                    _buildNavItem(context, navProvider, 1, Icons.groups_rounded, 'Groups'),
                    _buildNavItem(context, navProvider, 2, Icons.history_rounded, 'Activity'),
                    _buildNavItem(context, navProvider, 3, Icons.person_rounded, 'Profile'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    ShellNavigationProvider navProvider,
    int index,
    IconData icon,
    String label,
  ) {
    final isActive = navProvider.currentIndex == index;
    final color = isActive ? AppColors.primary : AppColors.textTertiary;

    return GestureDetector(
      onTap: () => navProvider.setIndex(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
