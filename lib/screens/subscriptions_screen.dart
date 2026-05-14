import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/subscription_model.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../widgets/modern_card.dart';
import '../widgets/animated_list_item.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

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

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Add Subscription', style: AppTextStyles.heading2),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Service Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ', border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  const Text('Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
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
                        selectedColor: AppColors.secondaryTeal.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.successGreen : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Billing Cycle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
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
                            selectedColor: AppColors.primaryOrange.withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.primaryOrange : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Next Due Date', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          const Icon(Icons.calendar_today_rounded, color: AppColors.secondaryTeal, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                ),
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
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Add'),
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
          content: Text('${sub.title} renewed! Next due: ${nextDate.day}/${nextDate.month}/${nextDate.year}'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    }
  }

  Future<void> _deleteSubscription(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subscription?'),
        content: const Text('Are you sure you want to stop tracking this recurring bill?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('subscriptions').doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription deleted'), backgroundColor: AppColors.textSecondary),
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
        return AppColors.primaryOrange;
      case 'Music':
        return const Color(0xFF6C63FF);
      case 'Cloud Storage':
        return AppColors.secondaryTeal;
      case 'Fitness':
        return AppColors.successGreen;
      case 'Software':
        return AppColors.primaryPeach;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<Subscription>>(
        stream: _getSubscriptionsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error loading subscriptions.'));
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ModernCard(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF4ECDC4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Total Recurring Outflow',
                        style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '₹${totalMonthly.toStringAsFixed(0)} /mo',
                        style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Est. Annual: ₹${totalYearly.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Title Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Active Cycles', style: AppTextStyles.heading2),
                    Text('${subs.length} Tracked', style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
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
                            Icon(Icons.event_repeat_rounded, size: 72, color: AppColors.textSecondary.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            const Text('No Subscriptions Tracked', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            const Text('Add streaming, cloud, or gym memberships\nto stay ahead of automatic renewals.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            statusColor = AppColors.errorRed;
                          } else if (daysLeft == 0) {
                            statusText = 'Renews Today!';
                            statusColor = AppColors.primaryOrange;
                          } else if (daysLeft <= 3) {
                            statusText = 'Due in ${daysLeft}d';
                            statusColor = AppColors.warningOrange;
                          } else {
                            statusText = 'In ${daysLeft}d';
                            statusColor = AppColors.successGreen;
                          }

                          final catColor = _getCategoryColor(sub.category);
                          final catIcon = _getCategoryIcon(sub.category);

                          return AnimatedListItem(
                            index: index,
                            child: ModernCard(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: catColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(14),
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
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    sub.category,
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '•  ${sub.billingCycle.toUpperCase()}',
                                                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
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
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              statusText,
                                              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
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
                                          foregroundColor: AppColors.textSecondary,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                        label: const Text('Remove', style: TextStyle(fontSize: 12)),
                                        onPressed: () => _deleteSubscription(sub.id),
                                      ),
                                      const SizedBox(width: 12),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.successGreen.withValues(alpha: 0.15),
                                          foregroundColor: AppColors.successGreen,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                        label: const Text('Renew Cycle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
        onPressed: _addSubscription,
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Subscription', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
