import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import '../widgets/app_card.dart';
import '../widgets/app_button.dart' show AppButton, ButtonVariant, ButtonSize;
import 'create_split_bill_screen.dart';
import 'split_bill_detail_screen.dart';

class SplitBillsScreen extends StatefulWidget {
  const SplitBillsScreen({super.key});

  @override
  State<SplitBillsScreen> createState() => _SplitBillsScreenState();
}

class _SplitBillsScreenState extends State<SplitBillsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> _getSplitBillsStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.empty();

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('splitBills')
        .orderBy('date', descending: true)
        .limit(50)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
                vertical: AppSpacing.base,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Split Bills',
                    style: AppTextStyles.h1,
                  ),
                  AppButton(
                    label: 'New',
                    icon: Icons.add_rounded,
                    size: ButtonSize.small,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const CreateSplitBillScreen(lines: []),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.gapMd),
            // Split Bills List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getSplitBillsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.call_split_rounded,
                            size: 64,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: AppSpacing.gapMd),
                          Text(
                            'No split bills yet',
                            style: AppTextStyles.h3.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.gapSm),
                          Text(
                            'Create a new split bill to get started',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding,
                    ),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final billDoc = snapshot.data!.docs[index];
                      final billData = billDoc.data() as Map<String, dynamic>;
                      final billName = billData['billName'] ?? 'Unnamed Bill';
                      final total = billData['totalAmount'] ?? 0.0;
                      final participants =
                          (billData['participants'] as List<dynamic>?)?.length ?? 0;

                      return AppCard(
                        margin: const EdgeInsets.only(bottom: AppSpacing.gapMd),
                        interactive: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  SplitBillDetailScreen(splitId: billDoc.id),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        billName,
                                        style: AppTextStyles.h3.copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: AppSpacing.gapXs),
                                      Text(
                                        '$participants participant${participants != 1 ? 's' : ''}',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹ ${(total as num).toStringAsFixed(2)}',
                                  style: AppTextStyles.h3.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
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
            ),
          ],
        ),
      ),
    );
  }
}
