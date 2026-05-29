import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../utils/colors.dart';
import '../utils/app_spacing.dart';
import '../utils/text_styles.dart';
import '../widgets/modern_card.dart';
import '../widgets/mesh_background.dart';
import '../widgets/custom_button.dart';
import '../services/auth_service.dart';
import '../services/theme_provider.dart';
import '../services/notification_preferences.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          userData = doc.data();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _showEditBudgetDialog() async {
    final budgetController = TextEditingController();
    final user = _auth.currentUser;
    if (user == null) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        final dialogIsDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
          title: Text("Set Monthly Budget", style: AppTextStyles.h3),
          content: TextField(
            controller: budgetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: "Amount",
              prefixText: "₹ ",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Cancel", style: AppTextStyles.bodyM.copyWith(color: dialogIsDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)),
            ),
            CustomButton(
              text: "Save",
              width: 100,
              height: 44,
              onPressed: () async {
                final newBudget = double.tryParse(budgetController.text);
                if (newBudget != null && newBudget > 0) {
                  await _firestore
                      .collection('users')
                      .doc(user.uid)
                      .set({'monthlyBudget': newBudget}, SetOptions(merge: true));

                  _loadUserData(); // Reload data
                  if (mounted) Navigator.pop(context);
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please enter a valid amount.")),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Profile", style: AppTextStyles.h2.copyWith(color: isDark ? Colors.white : AppColors.textDarkPrimary)),
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : AppColors.textDarkPrimary,
        elevation: 0,
      ),
      body: MeshBackground(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  120, // Space for AppBar
                  AppSpacing.screenPadding,
                  120, // Space for bottom navigation
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primaryGold, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGold.withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: user?.photoURL != null
                            ? NetworkImage(user!.photoURL!)
                            : null,
                        child: user?.photoURL == null
                            ? Icon(Icons.person, size: 50, color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      userData?['name'] ?? user?.displayName ?? "User",
                      style: AppTextStyles.h2.copyWith(color: isDark ? Colors.white : AppColors.textDarkPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userData?['email'] ?? user?.email ?? "No Email",
                      style: AppTextStyles.bodyM.copyWith(color: isDark ? Colors.white70 : AppColors.textDarkSecondary),
                    ),
                    const SizedBox(height: 30),
                    ModernCard(
                      child: Column(
                        children: [
                          _buildInfoRow("User ID", user?.uid ?? "N/A"),
                          Divider(height: 32, color: isDark ? Colors.white12 : AppColors.lightSurfaceBorder),
                          _buildInfoRow(
                            "Joined On",
                            userData?['createdAt'] != null
                                ? (userData!['createdAt'] as Timestamp)
                                    .toDate()
                                    .toString()
                                    .substring(0, 10)
                                : "Unknown",
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ModernCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Monthly Budget", style: AppTextStyles.h3),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  "₹ ${userData?['monthlyBudget']?.toStringAsFixed(2) ?? 'Not Set'}",
                                  style: AppTextStyles.h1.copyWith(color: AppColors.primaryGold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: AppColors.primaryGold),
                                onPressed: _showEditBudgetDialog,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                    Consumer<NotificationPreferences>(
                      builder: (context, notificationPrefs, _) => Column(
                        children: [
                          ModernCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Notifications", style: AppTextStyles.h3),
                                const SizedBox(height: 12),
                                _buildNotificationToggle(
                                  title: "Push Notifications",
                                  subtitle: "Enable all notifications",
                                  value: notificationPrefs.pushNotificationsEnabled,
                                  onChanged: (value) =>
                                      notificationPrefs.setPushNotifications(value),
                                  icon: Icons.notifications,
                                ),
                                if (notificationPrefs.pushNotificationsEnabled) ...[
                                  Divider(height: 20, color: isDark ? Colors.white12 : AppColors.lightSurfaceBorder),
                                  _buildNotificationToggle(
                                    title: "Settlement Reminders",
                                    subtitle: "Get reminded about pending payments",
                                    value: notificationPrefs.settlementRemindersEnabled,
                                    onChanged: (value) =>
                                        notificationPrefs.setSettlementReminders(value),
                                    icon: Icons.payment,
                                    indented: true,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildNotificationToggle(
                                    title: "Group Invites",
                                    subtitle: "Receive group invitation notifications",
                                    value: notificationPrefs.groupInvitesEnabled,
                                    onChanged: (value) =>
                                        notificationPrefs.setGroupInvites(value),
                                    icon: Icons.group_add,
                                    indented: true,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildNotificationToggle(
                                    title: "Expense Updates",
                                    subtitle: "Get notified about new expenses",
                                    value: notificationPrefs.expenseUpdatesEnabled,
                                    onChanged: (value) =>
                                        notificationPrefs.setExpenseUpdates(value),
                                    icon: Icons.receipt,
                                    indented: true,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildNotificationToggle(
                                    title: "Payment Reminders",
                                    subtitle: "Reminders for overdue payments",
                                    value: notificationPrefs.paymentRemindersEnabled,
                                    onChanged: (value) =>
                                        notificationPrefs.setPaymentReminders(value),
                                    icon: Icons.alarm,
                                    indented: true,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    ModernCard(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text("Dark Mode", style: AppTextStyles.bodyL),
                        secondary: Icon(
                          themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                          color: AppColors.primaryGold,
                        ),
                        value: themeProvider.isDarkMode,
                        onChanged: (value) {
                          themeProvider.toggleTheme(value);
                          _firestore
                              .collection('users')
                              .doc(user!.uid)
                              .set({'theme': value ? 'dark' : 'light'}, SetOptions(merge: true));
                        },
                      ),
                    ),
                    const SizedBox(height: 40),
                    CustomButton(
                      variant: ButtonVariant.secondary,
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                      textColor: Colors.redAccent,
                      onPressed: () async {
                        await AuthService().signOut();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        }
                      },
                      icon: Icons.logout,
                      text: "Logout",
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyM.copyWith(color: isDark ? Colors.white60 : AppColors.textDarkSecondary)),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyL.copyWith(color: isDark ? Colors.white : AppColors.textDarkPrimary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    bool indented = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        if (indented) const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.primaryGold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: AppTextStyles.bodyL),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTextStyles.bodyM.copyWith(color: isDark ? Colors.white60 : AppColors.textDarkSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primaryGold,
        ),
      ],
    );
  }
}
