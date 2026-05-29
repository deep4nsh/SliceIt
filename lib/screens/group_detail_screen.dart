import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/debt_simplifier.dart';
import '../services/pdf_export_service.dart';
import '../services/group_analytics_service.dart';
import '../widgets/custom_button.dart';
import 'settlement_history_screen.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import '../utils/deep_link_config.dart';
import '../widgets/modern_card.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/mesh_background.dart';

/// Highly stylized GroupDetailScreen integrating rich Tab structures,
/// reactive modern settlement calculation cards, glass dialog forms, and smooth kinetics.
class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Map<String, String> _nameCache = {};

  Stream<DocumentSnapshot> _getGroupStream() {
    return _firestore.collection('groups').doc(widget.groupId).snapshots();
  }

  Future<String> _getCachedName(String uid) async {
    if (_nameCache.containsKey(uid)) {
      return _nameCache[uid]!;
    }
    final doc = await _firestore.collection('users').doc(uid).get();
    final name = doc.data()?['name'] ?? 'User';
    _nameCache[uid] = name;
    return name;
  }

  Stream<QuerySnapshot> _getGroupExpensesStream() {
    return _firestore
        .collection('groups')
        .doc(widget.groupId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> _showExpenseDialog({DocumentSnapshot? expenseDoc}) async {
    final groupDoc = await _getGroupStream().first;
    final members = (groupDoc.data() as Map<String, dynamic>?)?['members']?.cast<String>() ?? [];
    final currentUser = _auth.currentUser;

    if (mounted) {
      await showDialog(
        context: context,
        builder: (_) => _AddEditExpenseDialog(
          groupId: widget.groupId,
          groupMemberUids: members,
          expenseDoc: expenseDoc,
          canEdit: expenseDoc == null || ((expenseDoc.data() as Map<String, dynamic>)['paidBy'] == currentUser?.uid),
        ),
      );
    }
  }

  Future<void> _sendSettlementReminders(List<dynamic> settlements) async {
    if (settlements.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No settlements to remind about', style: AppTextStyles.bodyM),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryGold,
              ),
            ),
          ),
        );
      }

      // Get all expenses for the group
      final expensesSnapshot = await _firestore
          .collection('groups')
          .doc(widget.groupId)
          .collection('expenses')
          .get();

      final expenseIds = expensesSnapshot.docs.map((doc) => doc.id).toList();

      // Call the Cloud Function
      final result = await FirebaseFunctions.instance
          .httpsCallable('notifySettlementReminder')
          .call({
        'groupId': widget.groupId,
        'expenseIds': expenseIds,
      });

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        final notifiedCount = result.data['notified'] as int? ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              notifiedCount > 0
                  ? 'Settlement reminders sent to $notifiedCount member${notifiedCount > 1 ? 's' : ''}!'
                  : 'No notifications sent. Make sure group members have FCM tokens registered.',
              style: AppTextStyles.bodyM,
            ),
            backgroundColor: notifiedCount > 0 ? AppColors.success : AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending reminders: $e', style: AppTextStyles.bodyM),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      debugPrint('Error sending settlement reminders: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MeshBackground(
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary),
            title: StreamBuilder<DocumentSnapshot>(
              stream: _getGroupStream(),
              builder: (context, snapshot) {
                final groupName = (snapshot.data?.data() as Map<String, dynamic>?)?['name'] ?? 'Group Details';
                return Text(
                  groupName,
                  style: AppTextStyles.h2.copyWith(
                    color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.history_rounded, color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary),
                tooltip: 'Settlement History',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettlementHistoryScreen(groupId: widget.groupId),
                    ),
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.download_rounded, color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary),
                tooltip: 'Export as PDF',
                onPressed: () async {
                  try {
                    final groupDoc = await _firestore.collection('groups').doc(widget.groupId).get();
                    final groupName = groupDoc.data()?['name'] ?? 'Group';

                    final expensesSnapshot = await _firestore
                        .collection('groups')
                        .doc(widget.groupId)
                        .collection('expenses')
                        .get();

                    final expenses = expensesSnapshot.docs
                        .map((doc) => {
                              'title': doc.data()['title'] as String? ?? 'Unknown',
                              'amount': (doc.data()['amount'] as num?)?.toDouble() ?? 0.0,
                              'paidBy': doc.data()['paidBy'] as String? ?? 'Unknown',
                              'date': doc.data()['createdAt'] as dynamic,
                            })
                        .toList();

                    final members = groupDoc.data()?['members'] as List? ?? [];
                    final balances = <String, double>{};
                    for (final member in members) {
                      balances[member] = 0.0;
                    }

                    await PdfExportService.exportGroupStatement(
                      groupName: groupName,
                      expenses: expenses,
                      balances: balances,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error exporting PDF: $e', style: AppTextStyles.bodyM),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              ),
              IconButton(
                icon: Icon(Icons.share_rounded, color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary),
                tooltip: 'Copy and Share Invite Link',
                onPressed: () async {
                  final groupDoc = await _firestore.collection('groups').doc(widget.groupId).get();
                  final groupName = groupDoc.data()?['name'] ?? 'SliceIt Group';

                  final currentUser = FirebaseAuth.instance.currentUser;
                  final inviterUid = currentUser?.uid ?? '';
                  final httpLink = DeepLinkConfig.groupHttp(widget.groupId, inviterUid);

                  // Copy to Clipboard
                  await Clipboard.setData(ClipboardData(text: httpLink));

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text('Invite link copied to clipboard!', style: AppTextStyles.bodyM.copyWith(color: Colors.white)),
                          ],
                        ),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }

                  // Trigger Native Share Sheet
                  final text = "Hey! Join my group '$groupName' on SliceIt to split bills easily.\n\nTap here to join automatically:\n$httpLink";
                  await Share.share(text, subject: "Join my SliceIt group '$groupName'");
                },
              ),
            ],
            bottom: TabBar(
              indicatorColor: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
              indicatorWeight: 3,
              labelColor: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
              labelStyle: AppTextStyles.bodyL.copyWith(fontWeight: FontWeight.bold),
              unselectedLabelColor: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary).withValues(alpha: 0.7),
              unselectedLabelStyle: AppTextStyles.bodyL.copyWith(fontWeight: FontWeight.normal),
              dividerColor: (isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder).withValues(alpha: 0.5),
              tabs: const [
                Tab(text: "Expenses"),
                Tab(text: "Balances"),
                Tab(text: "Analytics"),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildExpensesTab(isDark),
              _buildBalancesTab(isDark),
              _buildAnalyticsTab(isDark),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'group_add_expense_fab',
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
            onPressed: () => _showExpenseDialog(),
            backgroundColor: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
            label: Text(
              "Add Expense",
              style: AppTextStyles.button.copyWith(
                color: isDark ? AppColors.textDarkPrimary : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            icon: Icon(
              Icons.add_rounded,
              color: isDark ? AppColors.textDarkPrimary : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpensesTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 16, AppSpacing.screenPadding, 8),
          child: Text(
            "Members",
            style: AppTextStyles.h3.copyWith(
              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: StreamBuilder<DocumentSnapshot>(
            stream: _getGroupStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent),
                  ),
                );
              }
              final members = (snapshot.data!.data() as Map<String, dynamic>?)?['members']?.cast<String>() ?? [];
              if (members.isEmpty) {
                return Center(
                  child: Text(
                    "No members yet.",
                    style: AppTextStyles.bodyM.copyWith(color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary),
                  ),
                );
              }
              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  return MemberChip(uid: members[index], cacheFn: _getCachedName, isDark: isDark);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Divider(color: (isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder).withValues(alpha: 0.5), height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getGroupExpensesStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text("Error loading expenses", style: AppTextStyles.bodyL.copyWith(color: AppColors.error)),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent),
                );
              }
              if (snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 48,
                        color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary).withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "No expenses yet",
                        style: AppTextStyles.h3.copyWith(
                          color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Tap below to add the first expense!",
                        style: AppTextStyles.bodyM.copyWith(
                          color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                        ),
                      ),
                    ],
                  ).animate().fade(duration: 300.ms),
                );
              }

              final docs = snapshot.data!.docs;

              return ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(
                  left: AppSpacing.screenPadding,
                  right: AppSpacing.screenPadding,
                  top: 16,
                  bottom: 120, // Cushion to completely avoid floating action button overlap
                ),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final expenseDoc = docs[index];
                  final data = expenseDoc.data() as Map<String, dynamic>;
                  final participants = (data['participants'] as List?)?.cast<String>() ?? [];
                  final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                  final title = data['title'] ?? 'No Title';
                  final isSettlement = data['isSettlement'] == true;

                  return AnimatedListItem(
                    index: index,
                    child: ModernCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                      onTap: () => _showExpenseDialog(expenseDoc: expenseDoc),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (isSettlement
                                      ? AppColors.success
                                      : (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent))
                                  .withValues(alpha: isDark ? 0.15 : 0.1),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              border: Border.all(
                                color: (isSettlement
                                        ? AppColors.success
                                        : (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent))
                                    .withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              isSettlement ? Icons.handshake_rounded : Icons.receipt_rounded,
                              color: isSettlement
                                  ? AppColors.success
                                  : (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent),
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
                                UserNameDisplay(
                                  uid: data['paidBy'] ?? '',
                                  cacheFn: _getCachedName,
                                  builder: (name) => Text(
                                    isSettlement
                                        ? 'Paid by $name'
                                        : 'Paid by $name • Split with ${participants.length}',
                                    style: AppTextStyles.label.copyWith(
                                      color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                                          .withValues(alpha: 0.8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "₹${amount.toStringAsFixed(2)}",
                            style: AppTextStyles.h3.copyWith(
                              color: isSettlement
                                  ? AppColors.success
                                  : (isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBalancesTab(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getGroupExpensesStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error loading balances", style: AppTextStyles.bodyL.copyWith(color: AppColors.error)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent));
        }

        final expenses = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

        final settlements = DebtSimplifier.simplifyDebts(expenses);
        if (settlements.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success.withValues(alpha: 0.15),
                  ),
                  child: const Icon(Icons.check_circle_rounded, size: 54, color: AppColors.success),
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 16),
                Text(
                  "All settled up!",
                  style: AppTextStyles.h2.copyWith(
                    color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().fade(duration: 300.ms, delay: 100.ms),
                const SizedBox(height: 4),
                Text(
                  "Group balances are perfectly matched.",
                  style: AppTextStyles.bodyM.copyWith(
                    color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                  ),
                ).animate().fade(duration: 300.ms, delay: 200.ms),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                16,
                AppSpacing.screenPadding,
                16,
              ),
              child: CustomButton(
                icon: Icons.notifications,
                text: "Send Settlement Reminders",
                onPressed: () => _sendSettlementReminders(settlements),
              ),
            ),
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(
                  left: AppSpacing.screenPadding,
                  right: AppSpacing.screenPadding,
                  top: 0,
                  bottom: 120,
                ),
                itemCount: settlements.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final settlement = settlements[index];

                  return AnimatedListItem(
                    index: index,
                    child: ModernCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.all(16),
                      color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_outward_rounded, color: AppColors.error, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: UserNameDisplay(
                                        uid: settlement.fromUser,
                                        cacheFn: _getCachedName,
                                        builder: (name) => Text(
                                          name,
                                          style: AppTextStyles.bodyL.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                      child: Text(
                                        "owes",
                                        style: AppTextStyles.bodyM.copyWith(
                                          color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                    Flexible(
                                      child: UserNameDisplay(
                                        uid: settlement.toUser,
                                        cacheFn: _getCachedName,
                                        builder: (name) => Text(
                                          name,
                                          style: AppTextStyles.bodyL.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "₹${settlement.amount.toStringAsFixed(2)}",
                            style: AppTextStyles.h3.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnalyticsTab(bool isDark) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _getGroupStream(),
      builder: (context, groupSnapshot) {
        if (groupSnapshot.hasError) {
          return Center(
            child: Text("Error loading group", style: AppTextStyles.bodyL.copyWith(color: AppColors.error)),
          );
        }
        if (groupSnapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent),
          );
        }

        final groupData = groupSnapshot.data!.data() as Map<String, dynamic>?;
        final members = (groupData?['members'] as List?)?.cast<String>() ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: _getGroupExpensesStream(),
          builder: (context, expenseSnapshot) {
            if (expenseSnapshot.hasError) {
              return Center(
                child: Text("Error loading expenses", style: AppTextStyles.bodyL.copyWith(color: AppColors.error)),
              );
            }
            if (expenseSnapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent),
              );
            }

            final expenses = expenseSnapshot.data!.docs
                .map((doc) => {
                      ...doc.data() as Map<String, dynamic>,
                      'id': doc.id,
                    })
                .toList();

            final analytics = GroupAnalyticsService.calculateGroupAnalytics(expenses, members);

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: 16),
              children: [
                // Summary Cards
                ModernCard(
                  color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Overview",
                        style: AppTextStyles.h3.copyWith(
                          color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Total Spent",
                                style: AppTextStyles.label.copyWith(
                                  color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "₹${analytics.totalSpent.toStringAsFixed(2)}",
                                style: AppTextStyles.h3.copyWith(
                                  color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Expenses",
                                style: AppTextStyles.label.copyWith(
                                  color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${analytics.expenseCount}",
                                style: AppTextStyles.h3.copyWith(
                                  color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Average Bill",
                                style: AppTextStyles.label.copyWith(
                                  color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "₹${GroupAnalyticsService.getAverageBillAmount(expenses).toStringAsFixed(2)}",
                                style: AppTextStyles.h3.copyWith(
                                  color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fade(duration: 300.ms),
                const SizedBox(height: 16),

                // Spending by Person
                ModernCard(
                  color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Spending Breakdown",
                        style: AppTextStyles.h3.copyWith(
                          color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...analytics.spendingByPerson.entries.map((entry) {
                        final percentage = analytics.percentageByPerson[entry.key] ?? 0.0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      style: AppTextStyles.bodyM.copyWith(
                                        color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "₹${entry.value.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)",
                                    style: AppTextStyles.label.copyWith(
                                      color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                child: LinearProgressIndicator(
                                  value: analytics.totalSpent > 0 ? entry.value / analytics.totalSpent : 0,
                                  minHeight: 6,
                                  backgroundColor: (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent)
                                      .withValues(alpha: 0.15),
                                  valueColor: AlwaysStoppedAnimation(
                                    isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ).animate().fade(duration: 300.ms, delay: 100.ms),
                const SizedBox(height: 16),

                // Top Expense
                ModernCard(
                  color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Top Expense",
                        style: AppTextStyles.h3.copyWith(
                          color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (expenses.isNotEmpty)
                        Text(
                          GroupAnalyticsService.getTopExpenseTitle(expenses),
                          style: AppTextStyles.bodyL.copyWith(
                            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                          ),
                        )
                      else
                        Text(
                          "No expenses yet",
                          style: AppTextStyles.bodyM.copyWith(
                            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                          ),
                        ),
                    ],
                  ),
                ).animate().fade(duration: 300.ms, delay: 200.ms),
                const SizedBox(height: 100),
              ],
            );
          },
        );
      },
    );
  }
}

class _AddEditExpenseDialog extends StatefulWidget {
  final String groupId;
  final List<String> groupMemberUids;
  final DocumentSnapshot? expenseDoc;
  final bool canEdit;

  const _AddEditExpenseDialog({
    required this.groupId,
    required this.groupMemberUids,
    this.expenseDoc,
    this.canEdit = true,
  });

  @override
  State<_AddEditExpenseDialog> createState() => _AddEditExpenseDialogState();
}

class _AddEditExpenseDialogState extends State<_AddEditExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late Map<String, bool> _selectedMembers;
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    final existingData = widget.expenseDoc?.data() as Map<String, dynamic>?;
    _titleController = TextEditingController(text: existingData?['title']);
    _amountController = TextEditingController(text: existingData?['amount']?.toString());

    _selectedMembers = {
      for (var uid in widget.groupMemberUids)
        uid: (existingData?['participants'] as List?)?.contains(uid) ?? true,
    };
    _checkSelectAll();
  }

  void _checkSelectAll() {
    _selectAll = _selectedMembers.values.every((isSelected) => isSelected);
  }

  void _onSelectAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      _selectedMembers.updateAll((key, value) => _selectAll);
    });
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    final currentUser = FirebaseAuth.instance.currentUser;
    if (amount == null || currentUser == null) return;

    final participants = _selectedMembers.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please select at least one participant.", style: AppTextStyles.bodyM),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final expenseData = {
      'title': title,
      'amount': amount,
      'paidBy': currentUser.uid,
      'participants': participants,
      'date': FieldValue.serverTimestamp(),
    };

    final collection = FirebaseFirestore.instance.collection('groups').doc(widget.groupId).collection('expenses');

    if (widget.expenseDoc == null) {
      await collection.add(expenseData);
    } else {
      await collection.doc(widget.expenseDoc!.id).update(expenseData);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: BorderSide(
          color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
          width: 1,
        ),
      ),
      title: Text(
        widget.expenseDoc == null ? "Add Expense" : "Expense Details",
        style: AppTextStyles.h2.copyWith(
          color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
          fontSize: 20,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                style: AppTextStyles.bodyL.copyWith(color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary),
                decoration: InputDecoration(
                  labelText: "Title",
                  labelStyle: AppTextStyles.bodyM.copyWith(color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent).withValues(alpha: 0.3)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent),
                  ),
                ),
                enabled: widget.canEdit,
                validator: (value) => (value?.trim().isEmpty ?? true) ? "Please enter a title" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                style: AppTextStyles.bodyL.copyWith(color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary),
                decoration: InputDecoration(
                  labelText: "Amount",
                  prefixText: "₹ ",
                  prefixStyle: AppTextStyles.bodyL.copyWith(color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent),
                  labelStyle: AppTextStyles.bodyM.copyWith(color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent).withValues(alpha: 0.3)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                enabled: widget.canEdit,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return "Please enter an amount";
                  if (double.tryParse(value.trim()) == null) return "Please enter a valid number";
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text(
                "Split with:",
                style: AppTextStyles.label.copyWith(
                  color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Theme(
                data: Theme.of(context).copyWith(
                  checkboxTheme: CheckboxThemeData(
                    fillColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return isDark ? AppColors.secondaryAccent : AppColors.primaryAccent;
                      }
                      return Colors.transparent;
                    }),
                    checkColor: WidgetStateProperty.all(isDark ? AppColors.textDarkPrimary : Colors.white),
                    side: BorderSide(color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary).withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                child: Column(
                  children: [
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        "Select All",
                        style: AppTextStyles.bodyM.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                        ),
                      ),
                      value: _selectAll,
                      onChanged: widget.canEdit ? _onSelectAll : null,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    Divider(color: (isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder).withValues(alpha: 0.5), height: 8),
                    ...widget.groupMemberUids.map((uid) {
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: UserNameDisplay(
                          uid: uid,
                          builder: (name) => Text(
                            name,
                            style: AppTextStyles.bodyM.copyWith(
                              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                            ),
                          ),
                        ),
                        value: _selectedMembers[uid] ?? false,
                        onChanged: widget.canEdit
                            ? (bool? value) {
                                setState(() {
                                  _selectedMembers[uid] = value ?? false;
                                  _checkSelectAll();
                                });
                              }
                            : null,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            "Close",
            style: AppTextStyles.button.copyWith(
              color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
            ),
          ),
        ),
        if (widget.canEdit)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
              foregroundColor: isDark ? AppColors.textDarkPrimary : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
              elevation: 0,
            ),
            onPressed: _saveExpense,
            child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        if (widget.expenseDoc != null)
          _SettleButton(
            expenseDoc: widget.expenseDoc!,
            currentUserUid: FirebaseAuth.instance.currentUser?.uid,
            groupId: widget.groupId,
          ),
      ],
    );
  }
}

class UserNameDisplay extends StatelessWidget {
  final String uid;
  final Widget Function(String name) builder;
  final Future<String> Function(String uid)? cacheFn;

  const UserNameDisplay({super.key, required this.uid, required this.builder, this.cacheFn});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return builder('Unknown');

    final Future<String> future = cacheFn != null
        ? cacheFn!(uid)
        : FirebaseFirestore.instance.collection('users').doc(uid).get().then<String>((doc) {
            final data = doc.data();
            return (data?['name'] as String?) ?? 'User';
          });

    return FutureBuilder<String>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return builder('...');
        if (snapshot.hasError || !snapshot.hasData) return builder('Unknown');
        return builder(snapshot.data!);
      },
    );
  }
}

class MemberChip extends StatelessWidget {
  final String uid;
  final Future<String> Function(String uid)? cacheFn;
  final bool isDark;

  const MemberChip({super.key, required this.uid, this.cacheFn, this.isDark = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FutureBuilder<Map<String, dynamic>>(
        future: FirebaseFirestore.instance.collection('users').doc(uid).get().then((doc) {
          return doc.data() ?? {};
        }),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Chip(
              label: Text('...', style: AppTextStyles.bodyM),
              backgroundColor: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
              side: BorderSide(color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder),
            );
          }
          final data = snapshot.data!;
          final name = data['name'] ?? 'Unknown';
          final photoUrl = data['photoUrl'];

          return Chip(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            avatar: CircleAvatar(
              radius: 12,
              backgroundColor: (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent).withValues(alpha: 0.2),
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: AppTextStyles.label.copyWith(
                        color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                        fontSize: 10,
                      ),
                    )
                  : null,
            ),
            label: Text(
              name,
              style: AppTextStyles.bodyM.copyWith(
                color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
            side: BorderSide(color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
          );
        },
      ),
    );
  }
}

class _SettleButton extends StatefulWidget {
  final DocumentSnapshot expenseDoc;
  final String? currentUserUid;
  final String groupId;

  const _SettleButton({
    required this.expenseDoc,
    required this.currentUserUid,
    required this.groupId,
  });

  @override
  State<_SettleButton> createState() => _SettleButtonState();
}

class _SettleButtonState extends State<_SettleButton> {
  bool _isLoading = false;

  Future<void> _settleWithUpi() async {
    setState(() => _isLoading = true);
    try {
      final data = widget.expenseDoc.data() as Map<String, dynamic>;
      final paidByUid = data['paidBy'];
      final amount = (data['amount'] as num).toDouble();
      final participants = (data['participants'] as List).cast<String>();

      if (!participants.contains(widget.currentUserUid)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You are not a participant in this expense.', style: AppTextStyles.bodyM),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final splitAmount = participants.isNotEmpty ? amount / participants.length : 0.0;

      final result = await FirebaseFunctions.instance.httpsCallable('initiatePay').call({
        'expenseId': widget.expenseDoc.id,
        'amount': splitAmount,
        'receiverUid': paidByUid,
      });

      final resp = result.data as Map<dynamic, dynamic>;
      final txnId = resp['txnId'];
      final vpa = resp['vpa'];
      final name = resp['name'];
      final note = resp['note'];

      final uriString = 'upi://pay?pa=$vpa&pn=$name&tr=$txnId&tn=$note&am=$splitAmount&cu=INR';
      final uri = Uri.parse(uriString);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _pollTransactionStatus(txnId, splitAmount, paidByUid);
      } else {
        throw "Could not launch UPI app";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: AppTextStyles.bodyM),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _pollTransactionStatus(String txnId, double amount, String receiverUid) async {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent),
            const SizedBox(height: 16),
            Text(
              "Verifying Payment...",
              style: AppTextStyles.bodyL.copyWith(color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary),
            ),
          ],
        ),
      ),
    );

    int attempts = 0;
    bool success = false;

    while (attempts < 10) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;

      final doc = await FirebaseFirestore.instance.collection('transactions').doc(txnId).get();
      if (doc.exists && doc.data()?['status'] == 'SUCCESS') {
        success = true;
        break;
      }
      attempts++;
    }

    if (!mounted) return;
    Navigator.pop(context);

    if (success) {
      await _recordSettlement(amount, receiverUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment Successful! Bill Settled.', style: AppTextStyles.bodyM),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment processing or failed. Check status later.', style: AppTextStyles.bodyM),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _recordSettlement(double amount, String receiverUid) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('expenses')
        .add({
      'title': "Settlement Payment",
      'amount': amount,
      'paidBy': widget.currentUserUid,
      'participants': [receiverUid],
      'date': FieldValue.serverTimestamp(),
      'isSettlement': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.expenseDoc.data() as Map<String, dynamic>;
    final paidBy = data['paidBy'];
    final isPayer = paidBy == widget.currentUserUid;

    if (isPayer) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        ),
        child: const Text("You Paid"),
      );
    }

    return ElevatedButton(
      onPressed: _isLoading ? null : _settleWithUpi,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        elevation: 0,
      ),
      child: _isLoading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Text("Settle with UPI", style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
