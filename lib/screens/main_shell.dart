import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/colors.dart';
import '../utils/app_spacing.dart';
import 'home_screen.dart';
import 'groups_screen.dart';
import 'split_bills_screen.dart';
import 'profile_screen.dart';

/// Centralized application navigation shell providing a persistent UI container
/// with a state-of-the-art floating glassmorphic island bottom navigation bar.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    GroupsScreen(),
    SplitBillsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Preserves inner view state across active navigation transitions
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // Floating Glassmorphic Bottom Navigation Bar
          Positioned(
            left: AppSpacing.screenPadding,
            right: AppSpacing.screenPadding,
            bottom: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface1
                        : AppColors.lightSurface1,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkSurfaceBorder.withValues(alpha: 0.5)
                          : AppColors.lightSurfaceBorder.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(
                        index: 0,
                        icon: Icons.dashboard_rounded,
                        label: 'Home',
                        isDark: isDark,
                      ),
                      _buildNavItem(
                        index: 1,
                        icon: Icons.groups_rounded,
                        label: 'Groups',
                        isDark: isDark,
                      ),
                      _buildNavItem(
                        index: 2,
                        icon: Icons.call_split_rounded,
                        label: 'Splits',
                        isDark: isDark,
                      ),
                      _buildNavItem(
                        index: 3,
                        icon: Icons.person_rounded,
                        label: 'Profile',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),
            )
                .animate()
                .fade(duration: 500.ms, curve: Curves.easeOut)
                .slideY(begin: 0.8, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = _currentIndex == index;
    final activeColor = isDark ? AppColors.secondaryAccent : AppColors.primaryAccent;
    final inactiveColor = isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary;

    return GestureDetector(
      onTap: () {
        if (_currentIndex != index) {
          setState(() => _currentIndex = index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16.0 : 12.0,
          vertical: 8.0,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 24,
            )
                .animate(target: isSelected ? 1 : 0)
                .scaleXY(end: 1.15, duration: 200.ms, curve: Curves.easeOut),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: activeColor,
                ),
              )
                  .animate()
                  .fade(duration: 200.ms)
                  .slideX(begin: -0.1, end: 0, duration: 200.ms, curve: Curves.easeOut),
            ],
          ],
        ),
      ),
    );
  }
}
