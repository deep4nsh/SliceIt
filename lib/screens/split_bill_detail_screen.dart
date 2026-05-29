import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';


import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import '../widgets/modern_card.dart';
import '../widgets/mesh_background.dart';
import '../widgets/custom_button.dart';

class SplitBillDetailScreen extends StatefulWidget {
  final String splitId;

  const SplitBillDetailScreen({super.key, required this.splitId});

  @override
  State<SplitBillDetailScreen> createState() => _SplitBillDetailScreenState();
}

class _SplitBillDetailScreenState extends State<SplitBillDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _markAsPaid(String userEmail, bool isPaid) async {
    final splitDoc = await _firestore.collection('split_bills').doc(widget.splitId).get();
    final data = splitDoc.data();
    if (data == null) return;

    await _firestore.collection('split_bills').doc(widget.splitId).update({
      'paidStatus.$userEmail': isPaid,
    });

    if (userEmail == _auth.currentUser?.email) {
      await _updatePersonalLog(data, isPaid);
    }
  }

  Future<void> _updatePersonalLog(Map<String, dynamic> data, bool isPaid) async {
    final userUid = _auth.currentUser!.uid;
    final logDocRef = _firestore
        .collection('users')
        .doc(userUid)
        .collection('expenses')
        .doc('split_${widget.splitId}');

    if (!isPaid) {
      // Remove from log if marked as unpaid
      await logDocRef.delete();
      return;
    }

    final totalAmount = (data['totalAmount'] as num).toDouble();
    final participants = (data['participants'] as List?)?.cast<String>() ?? [];
    final splitType = data['splitType'] ?? 'equal';
    final userEmail = _auth.currentUser?.email;
    double expenseAmount = 0;

    if (splitType.toString().contains('unequal') && userEmail != null) {
      final amounts = (data['amounts'] as Map?)?.cast<String, num>() ?? {};
      expenseAmount = (amounts[userEmail] ?? 0).toDouble();
    } else {
      expenseAmount = participants.isNotEmpty ? totalAmount / participants.length : 0;
    }

    if (expenseAmount > 0) {
      await logDocRef.set({
        'title': "Split: ${data['title']}",
        'amount': expenseAmount,
        'category': 'Bill Split',
        'date': FieldValue.serverTimestamp(),
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            "Split Details",
            style: AppTextStyles.h2.copyWith(
              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: IconThemeData(
            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
          ),
          actions: [
            StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('split_bills').doc(widget.splitId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                if (data == null) return const SizedBox.shrink();

                final createdBy = data['createdBy'] as String?;
                final currentUserEmail = _auth.currentUser?.email;

                if (createdBy == currentUserEmail) {
                  return IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                            side: BorderSide(
                              color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
                            ),
                          ),
                          title: Text(
                            "Delete Split Bill?",
                            style: AppTextStyles.h3.copyWith(
                              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          content: Text(
                            "This will delete this split bill for ALL participants. This action cannot be undone.",
                            style: AppTextStyles.bodyM.copyWith(
                              color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(
                                "Cancel",
                                style: AppTextStyles.button.copyWith(
                                  color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(
                                "Delete",
                                style: AppTextStyles.button.copyWith(color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await _firestore.collection('split_bills').doc(widget.splitId).delete();
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('split_bills').doc(widget.splitId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "Error loading details",
                  style: AppTextStyles.bodyL.copyWith(color: AppColors.error),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                ),
              );
            }

            final data = snapshot.data?.data() as Map<String, dynamic>?;
            if (data == null) {
              return Center(
                child: Text(
                  "Split not found",
                  style: AppTextStyles.bodyL.copyWith(
                    color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                  ),
                ),
              );
            }

            final title = data['title'] ?? 'No Title';
            final totalAmount = (data['totalAmount'] as num).toDouble();
            final participants = (data['participants'] as List?)?.cast<String>() ?? [];
            final paidStatus = (data['paidStatus'] as Map?)?.cast<String, bool>() ?? {};
            final createdBy = data['createdBy'] as String?;
            final currentUserEmail = _auth.currentUser?.email;
            final splitType = data['splitType'] as String? ?? 'equal';
            final amounts = (data['amounts'] as Map?)?.cast<String, num>() ?? {};



            final receiptUrl = data['receiptUrl'] as String?;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Summary Bento Card
                  ModernCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                          ),
                          child: Text(
                            splitType.toUpperCase(),
                            style: AppTextStyles.label.copyWith(
                              color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          title,
                          style: AppTextStyles.h1.copyWith(
                            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Total Bill Amount",
                          style: AppTextStyles.label.copyWith(
                            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "₹${totalAmount.toStringAsFixed(2)}",
                          style: AppTextStyles.h1.copyWith(
                            color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                            fontSize: 36,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fade(duration: 400.ms).scaleXY(begin: 0.95, end: 1.0),

                  if (receiptUrl != null) ...[
                    const SizedBox(height: 8),
                    CustomButton(
                      text: "View Attached Receipt",
                      icon: Icons.receipt_long_rounded,
                      variant: ButtonVariant.secondary,
                      height: 48,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: const EdgeInsets.all(16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                              child: Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  InteractiveViewer(
                                    child: Container(
                                      color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                                      width: double.infinity,
                                      height: MediaQuery.of(context).size.height * 0.7,
                                      child: Image.network(
                                        receiptUrl,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: IconButton(
                                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.black.withValues(alpha: 0.6),
                                      ),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ).animate().fade(delay: 100.ms),
                  ],

                  const SizedBox(height: 24),
                  Text(
                    "Participants",
                    style: AppTextStyles.h3.copyWith(
                      color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fade(delay: 200.ms),
                  const SizedBox(height: 12),

                  // List of non-creator participants
                  ...participants.where((email) => email != createdBy).toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final email = entry.value;
                    final isPaid = paidStatus[email] ?? false;
                    final canToggle = createdBy == currentUserEmail || email == currentUserEmail;
                    final amountOwed = splitType.contains('unequal')
                        ? (amounts[email] ?? 0).toDouble()
                        : (participants.isNotEmpty ? totalAmount / participants.length : 0);

                    return ModernCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: (isDark ? AppColors.primaryAccent : AppColors.secondaryAccent)
                                .withValues(alpha: 0.2),
                            child: Text(
                              email[0].toUpperCase(),
                              style: AppTextStyles.h3.copyWith(
                                color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  email,
                                  style: AppTextStyles.bodyL.copyWith(
                                    color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Owes: ₹${amountOwed.toStringAsFixed(2)}",
                                  style: AppTextStyles.label.copyWith(
                                    color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isPaid ? AppColors.success : AppColors.error)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                ),
                                child: Text(
                                  isPaid ? "PAID" : "UNPAID",
                                  style: AppTextStyles.label.copyWith(
                                    color: isPaid ? AppColors.success : AppColors.error,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              if (canToggle) ...[
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: 24,
                                  child: Switch(
                                    value: isPaid,
                                    activeColor: AppColors.success,
                                    onChanged: (value) => _markAsPaid(email, value),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ).animate().fade(delay: Duration(milliseconds: 250 + (index * 50))).slideX(begin: 0.05);
                  }),

                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
