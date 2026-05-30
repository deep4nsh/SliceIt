import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import '../widgets/app_card.dart';
import '../widgets/app_button.dart' show AppButton, ButtonVariant, ButtonSize;
import '../services/debt_simplifier.dart';
import 'group_settings_screen.dart';
import 'settlement_history_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late TabController _tabController;

  Stream<DocumentSnapshot> _getGroupStream() {
    return _firestore.collection('groups').doc(widget.groupId).snapshots();
  }

  Stream<QuerySnapshot> _getGroupExpensesStream() {
    return _firestore
        .collection('groups')
        .doc(widget.groupId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .limit(50)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _getGroupStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Group not found'));
          }

          final groupData = snapshot.data!.data() as Map<String, dynamic>;
          final groupName = groupData['name'] ?? 'Group';
          final members = (groupData['members'] as List<dynamic>?) ?? [];

          return CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: _buildHeader(context, groupName),
                ),
              ),

              // Balance Overview
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                    vertical: AppSpacing.gapMd,
                  ),
                  child: _buildBalanceOverview(context, groupName),
                ),
              ),

              // Tabs
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.darkBackground,
                  child: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Expenses'),
                      Tab(text: 'Members'),
                      Tab(text: 'Settlements'),
                    ],
                    indicatorColor: AppColors.primary,
                    labelStyle: AppTextStyles.label.copyWith(
                      color: AppColors.primary,
                    ),
                    unselectedLabelStyle: AppTextStyles.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),

              // Tab Content
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildExpensesTab(context),
                    _buildMembersTab(context, members),
                    _buildSettlementsTab(context, groupData),
                  ],
                ),
              ),

              // Bottom padding for add button
              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.safeAreaBottom),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddExpenseDialog(context),
        child: const Icon(Icons.add_rounded, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String groupName) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.base,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: AppColors.textPrimary,
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: AppSpacing.gapSm),
                Text(
                  groupName,
                  style: AppTextStyles.h1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.history_rounded),
                color: AppColors.textPrimary,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettlementHistoryScreen(groupId: widget.groupId),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                color: AppColors.textPrimary,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupSettingsScreen(groupId: widget.groupId),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded),
                color: AppColors.textPrimary,
                onPressed: () => _shareGroup(groupName),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceOverview(BuildContext context, String groupName) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getGroupExpensesStream(),
      builder: (context, snapshot) {
        double totalSpent = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final expense = doc.data() as Map<String, dynamic>;
            totalSpent += (expense['amount'] as num?)?.toDouble() ?? 0;
          }
        }

        return AppCard(
          interactive: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Group Total',
                style: AppTextStyles.subtitle.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.gapSm),
              Text(
                '₹ ${totalSpent.toStringAsFixed(2)}',
                style: AppTextStyles.display,
              ),
              const SizedBox(height: AppSpacing.gapMd),
              Text(
                'Total expenses in this group',
                style: AppTextStyles.helper.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpensesTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: StreamBuilder<QuerySnapshot>(
        stream: _getGroupExpensesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_rounded,
                    size: 64,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: AppSpacing.gapMd),
                  Text(
                    'No expenses yet',
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.gapMd),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final expense = doc.data() as Map<String, dynamic>;

              return AppCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.gapMd),
                interactive: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                expense['name'] ?? 'Expense',
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                expense['category'] ?? 'Other',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹ ${(expense['amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                          style: AppTextStyles.h3.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMembersTab(BuildContext context, List<dynamic> members) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.gapMd),
        itemCount: members.length,
        itemBuilder: (context, index) {
          final memberId = members[index] as String;
          return AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.gapMd),
            interactive: false,
            child: Row(
              children: [
                FutureBuilder<DocumentSnapshot>(
                  future: _firestore.collection('users').doc(memberId).get(),
                  builder: (context, snapshot) {
                    final userData = snapshot.data?.data() as Map?;
                    final photoURL = userData?['photoURL'] as String?;
                    final name = userData?['name'] as String? ?? 'User';
                    final initials = name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase();

                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.darkSurface2,
                          backgroundImage: photoURL != null && photoURL.isNotEmpty
                              ? NetworkImage(photoURL)
                              : null,
                          child: photoURL == null || photoURL.isEmpty
                              ? Text(
                                  initials.isEmpty ? '?' : initials.substring(0, 1),
                                  style: AppTextStyles.label.copyWith(
                                    color: AppColors.primary,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: AppSpacing.gapMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettlementsTab(
      BuildContext context, Map<String, dynamic> groupData) {

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: StreamBuilder<QuerySnapshot>(
        stream: _getGroupExpensesStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final expenses = snapshot.data!.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();

          final settlements =
              DebtSimplifier.simplifyDebts(expenses);

          if (settlements.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 64,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: AppSpacing.gapMd),
                  Text(
                    'All settled!',
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.gapMd),
            itemCount: settlements.length,
            itemBuilder: (context, index) {
              final settlement = settlements[index];
              return AppCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.gapMd),
                interactive: false,
                backgroundColor:
                    AppColors.success.withValues(alpha: 0.08),
                borderColor: AppColors.success.withValues(alpha: 0.3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<List<DocumentSnapshot>>(
                            future: Future.wait([
                              _firestore.collection('users').doc(settlement.fromUser).get(),
                              _firestore.collection('users').doc(settlement.toUser).get(),
                            ]),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Text(
                                  'Loading...',
                                  style: AppTextStyles.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                );
                              }
                              final fromName = (snapshot.data?[0].data() as Map?)?['name'] ?? 'User';
                              final toName = (snapshot.data?[1].data() as Map?)?['name'] ?? 'User';
                              return Text(
                                '$fromName pays $toName',
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹ ${settlement.amount.toStringAsFixed(2)}',
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddExpenseDialog(BuildContext context) async {
    final amountController = TextEditingController();
    final nameController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.darkSurface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.borderDefault),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.gapLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Expense', style: AppTextStyles.h2),
              const SizedBox(height: AppSpacing.gapMd),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Expense name',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.gapMd),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Amount',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.gapLg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Cancel',
                    variant: ButtonVariant.secondary,
                    size: ButtonSize.small,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: AppSpacing.gapSm),
                  AppButton(
                    label: 'Add',
                    size: ButtonSize.small,
                    onPressed: () async {
                      if (nameController.text.isEmpty ||
                          amountController.text.isEmpty) {
                        return;
                      }
                      await _firestore
                          .collection('groups')
                          .doc(widget.groupId)
                          .collection('expenses')
                          .add({
                        'name': nameController.text,
                        'amount': double.parse(amountController.text),
                        'paidBy': _auth.currentUser?.uid,
                        'category': 'Other',
                        'date': DateTime.now(),
                        'participants': (await _firestore
                                .collection('groups')
                                .doc(widget.groupId)
                                .get())
                            .data()?['members'] ??
                            [],
                      });
                      if (mounted) Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareGroup(String groupName) {
    Share.share(
      'Join "$groupName" on SliceIt!',
      subject: 'Join $groupName',
    );
  }
}
