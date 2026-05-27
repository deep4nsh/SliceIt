import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/settlement_model.dart';
import '../services/settlement_service.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import '../widgets/modern_card.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/mesh_background.dart';

class SettlementHistoryScreen extends StatefulWidget {
  final String groupId;

  const SettlementHistoryScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<SettlementHistoryScreen> createState() => _SettlementHistoryScreenState();
}

class _SettlementHistoryScreenState extends State<SettlementHistoryScreen> {
  final SettlementService _settlementService = SettlementService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final Map<String, String> _nameCache = {};

  Future<String> _getCachedName(String uid) async {
    if (_nameCache.containsKey(uid)) {
      return _nameCache[uid]!;
    }
    final doc = await _firestore.collection('users').doc(uid).get();
    final name = doc.data()?['name'] ?? 'User';
    _nameCache[uid] = name;
    return name;
  }

  Future<void> _addProofToSettlement(Settlement settlement) async {
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    if (!mounted) return;

    try {
      await _settlementService.addProofToSettlement(
        groupId: widget.groupId,
        settlementId: settlement.id,
        proofImage: File(pickedFile.path),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Proof uploaded successfully', style: AppTextStyles.bodyM),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading proof: $e', style: AppTextStyles.bodyM),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
            'Settlement History',
            style: AppTextStyles.h2.copyWith(
              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: StreamBuilder<List<Settlement>>(
          stream: _settlementService.getGroupSettlements(widget.groupId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading settlements',
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

            final settlements = snapshot.data ?? [];

            if (settlements.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 64,
                      color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                          .withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No settlements yet',
                      style: AppTextStyles.bodyL.copyWith(
                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
                vertical: 16,
              ),
              itemCount: settlements.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final settlement = settlements[index];
                return AnimatedListItem(
                  index: index,
                  child: FutureBuilder<String>(
                    future: _getCachedName(settlement.fromUserUid),
                    builder: (context, fromNameSnapshot) {
                      return FutureBuilder<String>(
                        future: _getCachedName(settlement.toUserUid),
                        builder: (context, toNameSnapshot) {
                          final fromName = fromNameSnapshot.data ?? 'User';
                          final toName = toNameSnapshot.data ?? 'User';

                          return ModernCard(
                            margin: EdgeInsets.zero,
                            padding: const EdgeInsets.all(16),
                            color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '$fromName → $toName',
                                        style: AppTextStyles.bodyL.copyWith(
                                          color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                                      ),
                                      child: Text(
                                        '₹${settlement.amount.toStringAsFixed(2)}',
                                        style: AppTextStyles.label.copyWith(
                                          color: AppColors.success,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  DateFormat('dd MMM yyyy, HH:mm').format(settlement.settledAt),
                                  style: AppTextStyles.label.copyWith(
                                    color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                if (settlement.note != null && settlement.note!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    settlement.note!,
                                    style: AppTextStyles.bodyM.copyWith(
                                      color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (settlement.proofUrl == null) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      icon: Icon(
                                        Icons.add_photo_alternate_rounded,
                                        size: 18,
                                        color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                                      ),
                                      label: Text(
                                        'Add Proof',
                                        style: AppTextStyles.label.copyWith(
                                          color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent)
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      onPressed: () => _addProofToSettlement(settlement),
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 16,
                                        color: AppColors.success,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Proof attached',
                                        style: AppTextStyles.label.copyWith(
                                          color: AppColors.success,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
