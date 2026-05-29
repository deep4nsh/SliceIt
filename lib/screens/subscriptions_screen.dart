import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/subscription_model.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import '../widgets/modern_card.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/mesh_background.dart';
import '../widgets/custom_button.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<Subscription>> _getSubscriptionsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    // Querying all subscriptions where current user is part of sharedWith
    return _firestore
        .collection('subscriptions')
        .where('sharedWith', arrayContains: user.uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Subscription.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<void> _addSubscription() async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = 'Streaming';
    String selectedCycle = 'monthly';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));

    final categories = ['Streaming', 'Music', 'Cloud Storage', 'Fitness', 'Software', 'Other'];
    final cycles = ['monthly', 'yearly'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              side: BorderSide(
                color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
              ),
            ),
            title: Text(
              'Add Subscription',
              style: AppTextStyles.h2.copyWith(
                color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    style: AppTextStyles.bodyL.copyWith(
                      color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Service Name',
                      labelStyle: AppTextStyles.bodyM.copyWith(
                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        borderSide: const BorderSide(color: AppColors.primaryAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    style: AppTextStyles.bodyL.copyWith(
                      color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      labelStyle: AppTextStyles.bodyM.copyWith(
                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                      ),
                      prefixText: '₹ ',
                      prefixStyle: AppTextStyles.bodyL.copyWith(
                        color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                        fontWeight: FontWeight.bold,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        borderSide: const BorderSide(color: AppColors.primaryAccent),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Category',
                    style: AppTextStyles.label.copyWith(
                      color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSelected = selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => selectedCategory = cat);
                          }
                        },
                        selectedColor: AppColors.secondaryAccent.withValues(alpha: 0.2),
                        backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.secondaryAccent
                              : (isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder),
                        ),
                        labelStyle: AppTextStyles.label.copyWith(
                          color: isSelected
                              ? (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent)
                              : (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Billing Cycle',
                    style: AppTextStyles.label.copyWith(
                      color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: cycles.map((cyc) {
                      final isSelected = selectedCycle == cyc;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Center(child: Text(cyc.toUpperCase())),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setDialogState(() => selectedCycle = cyc);
                              }
                            },
                            selectedColor: AppColors.primaryAccent.withValues(alpha: 0.2),
                            backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primaryAccent
                                  : (isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder),
                            ),
                            labelStyle: AppTextStyles.label.copyWith(
                              color: isSelected
                                  ? AppColors.primaryAccent
                                  : (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Next Due Date',
                    style: AppTextStyles.label.copyWith(
                      color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: isDark
                                  ? const ColorScheme.dark(
                                      primary: AppColors.secondaryAccent,
                                      onPrimary: Colors.black,
                                      onSurface: Colors.white,
                                    )
                                  : const ColorScheme.light(
                                      primary: AppColors.primaryAccent,
                                      onPrimary: Colors.white,
                                      onSurface: Colors.black,
                                    ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                        border: Border.all(
                          color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
                        ),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                            style: AppTextStyles.bodyL.copyWith(
                              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Icon(
                            Icons.calendar_today_rounded,
                            color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.bodyM.copyWith(
                    color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CustomButton(
                text: "Add",
                width: 100,
                height: 44,
                onPressed: () async {
                  final title = titleController.text.trim();
                  final amount = double.tryParse(amountController.text) ?? 0.0;
                  final user = _auth.currentUser;

                  if (title.isNotEmpty && amount > 0 && user != null) {
                    final newSub = Subscription(
                      id: '',
                      title: title,
                      amount: amount,
                      category: selectedCategory,
                      billingCycle: selectedCycle,
                      nextDueDate: selectedDate,
                      sharedWith: [user.uid],
                      paidBy: user.uid,
                      createdAt: DateTime.now(),
                    );

                    await _firestore.collection('subscriptions').add(newSub.toMap());
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } else {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text('Please enter valid details', style: AppTextStyles.bodyM),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _renewSubscription(Subscription sub) async {
    final nextDate = sub.billingCycle == 'yearly'
        ? DateTime(sub.nextDueDate.year + 1, sub.nextDueDate.month, sub.nextDueDate.day)
        : DateTime(sub.nextDueDate.year, sub.nextDueDate.month + 1, sub.nextDueDate.day);

    await _firestore.collection('subscriptions').doc(sub.id).update({
      'nextDueDate': Timestamp.fromDate(nextDate),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${sub.title} renewed! Next due: ${nextDate.day}/${nextDate.month}/${nextDate.year}',
            style: AppTextStyles.bodyM.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _deleteSubscription(String id) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          side: BorderSide(
            color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
          ),
        ),
        title: Text(
          'Delete Subscription?',
          style: AppTextStyles.h2.copyWith(
            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to stop tracking this recurring bill?',
          style: AppTextStyles.bodyM.copyWith(
            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyM.copyWith(
                color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CustomButton(
            text: "Delete",
            width: 100,
            height: 44,
            backgroundColor: AppColors.error,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('subscriptions').doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscription deleted', style: AppTextStyles.bodyM.copyWith(color: Colors.white)),
            backgroundColor: AppColors.textDarkSecondary,
          ),
        );
      }
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Streaming':
        return Icons.live_tv_rounded;
      case 'Music':
        return Icons.music_note_rounded;
      case 'Cloud Storage':
        return Icons.cloud_queue_rounded;
      case 'Fitness':
        return Icons.fitness_center_rounded;
      case 'Software':
        return Icons.code_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Streaming':
        return AppColors.warning;
      case 'Music':
        return AppColors.accentViolet;
      case 'Cloud Storage':
        return AppColors.secondaryAccent;
      case 'Fitness':
        return AppColors.success;
      case 'Software':
        return AppColors.primaryAccent;
      default:
        return AppColors.textLightSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Subscriptions',
            style: AppTextStyles.h2.copyWith(
              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        body: StreamBuilder<List<Subscription>>(
          stream: _getSubscriptionsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading subscriptions.',
                  style: AppTextStyles.bodyM.copyWith(color: AppColors.error),
                ),
              );
            }

            final subs = snapshot.data ?? [];

            // Sort upcoming nearest first
            subs.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

            // Calculate summary analytics
            double totalMonthly = 0.0;
            double totalYearly = 0.0;
            for (final s in subs) {
              if (s.billingCycle == 'yearly') {
                totalYearly += s.amount;
                totalMonthly += s.amount / 12;
              } else {
                totalMonthly += s.amount;
                totalYearly += s.amount * 12;
              }
            }

            return Column(
              children: [
                // Premium Visual Summary Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: 8.0),
                  child: ModernCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'Total Recurring Outflow',
                          style: AppTextStyles.label.copyWith(
                            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '₹${totalMonthly.toStringAsFixed(0)} /mo',
                          style: AppTextStyles.h1.copyWith(
                            color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                            fontSize: 34,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.darkSurface2 : AppColors.lightSurface2).withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
                            border: Border.all(
                              color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
                            ),
                          ),
                          child: Text(
                            'Est. Annual: ₹${totalYearly.toStringAsFixed(0)}',
                            style: AppTextStyles.label.copyWith(
                              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fade().scaleXY(begin: 0.95, end: 1.0),
                ),

                // Title Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Cycles',
                        style: AppTextStyles.h2.copyWith(
                          color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${subs.length} Tracked',
                        style: AppTextStyles.label.copyWith(
                          color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Main List
                Expanded(
                  child: subs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_repeat_rounded,
                                size: 72,
                                color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                                    .withValues(alpha: 0.2),
                              ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 0.95, end: 1.05),
                              const SizedBox(height: 16),
                              Text(
                                'No Subscriptions Tracked',
                                style: AppTextStyles.h3.copyWith(
                                  color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add streaming, cloud, or gym memberships\nto stay ahead of automatic renewals.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodyM.copyWith(
                                  color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: 8),
                          itemCount: subs.length,
                          itemBuilder: (context, index) {
                            final sub = subs[index];
                            final now = DateTime.now();
                            final today = DateTime(now.year, now.month, now.day);
                            final due = DateTime(sub.nextDueDate.year, sub.nextDueDate.month, sub.nextDueDate.day);
                            final daysLeft = due.difference(today).inDays;

                            String statusText;
                            Color statusColor;

                            if (daysLeft < 0) {
                              statusText = 'Overdue by ${-daysLeft}d';
                              statusColor = AppColors.error;
                            } else if (daysLeft == 0) {
                              statusText = 'Renews Today!';
                              statusColor = AppColors.warning;
                            } else if (daysLeft <= 3) {
                              statusText = 'Due in ${daysLeft}d';
                              statusColor = AppColors.warning;
                            } else {
                              statusText = 'In ${daysLeft}d';
                              statusColor = AppColors.success;
                            }

                            final catColor = _getCategoryColor(sub.category);
                            final catIcon = _getCategoryIcon(sub.category);

                            return AnimatedListItem(
                              index: index,
                              child: ModernCard(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: catColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                          ),
                                          child: Icon(catIcon, color: catColor, size: 24),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                sub.title,
                                                style: AppTextStyles.bodyL.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: (isDark ? AppColors.darkSurface2 : AppColors.lightSurface2)
                                                          .withValues(alpha: 0.8),
                                                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                                      border: Border.all(
                                                        color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      sub.category,
                                                      style: AppTextStyles.label.copyWith(
                                                        fontSize: 10,
                                                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '•  ${sub.billingCycle.toUpperCase()}',
                                                    style: AppTextStyles.label.copyWith(
                                                      fontSize: 10,
                                                      color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '₹${sub.amount.toStringAsFixed(0)}',
                                              style: AppTextStyles.h3.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                              ),
                                              child: Text(
                                                statusText,
                                                style: AppTextStyles.label.copyWith(
                                                  color: statusColor,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            foregroundColor: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                          label: Text('Remove', style: AppTextStyles.label.copyWith(fontSize: 12)),
                                          onPressed: () => _deleteSubscription(sub.id),
                                        ),
                                        const SizedBox(width: 12),
                                        CustomButton(
                                          text: "Renew Cycle",
                                          width: 130,
                                          height: 36,
                                          icon: Icons.check_circle_outline_rounded,
                                          backgroundColor: AppColors.success.withValues(alpha: 0.15),
                                          textColor: AppColors.success,
                                          variant: ButtonVariant.secondary,
                                          borderRadius: AppSpacing.radiusMd,
                                          onPressed: () => _renewSubscription(sub),
                                        ),
                                      ],
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
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'add_subscription_fab',
          onPressed: _addSubscription,
          backgroundColor: AppColors.primaryAccent,
          foregroundColor: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            'Add Subscription',
            style: AppTextStyles.button.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
