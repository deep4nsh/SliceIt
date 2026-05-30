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

  int _limit = 20;
  bool _hasMore = true;
  int _loadedCount = 0;
  late ScrollController _scrollController;
  String? _activeGroupId;

  @override
  void initState() {
    super.initState();
    _activeGroupId = widget.groupId.isEmpty ? null : widget.groupId;
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && _loadedCount == _limit) {
        setState(() {
          _limit += 20;
        });
      }
    }
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

  Future<void> _addProofToSettlement(Settlement settlement) async {
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    if (!mounted) return;

    try {
      // Show loading dialog with progress
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkSurface2
                : AppColors.lightSurface1,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primaryGold),
                const SizedBox(height: 16),
                Text('Uploading proof...', style: AppTextStyles.bodyM),
              ],
            ),
          ),
        );
      }

      await _settlementService.addProofToSettlement(
        groupId: _activeGroupId!,
        settlementId: settlement.id,
        proofImage: File(pickedFile.path),
        onProgress: (progress) {
          debugPrint('Upload progress: ${(progress * 100).toStringAsFixed(0)}%');
        },
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
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
        Navigator.pop(context); // Close loading dialog
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
        body: _activeGroupId == null
            ? _buildGroupSelector(isDark)
            : _buildSettlementsList(isDark),
      ),
    );
  }

  Widget _buildGroupSelector(bool isDark) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(
        child: Text(
          'Please log in to view settlements',
          style: AppTextStyles.bodyL.copyWith(
            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('groups')
          .where('members', arrayContains: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading groups',
              style: AppTextStyles.bodyL.copyWith(color: AppColors.error),
            ),
          );
        }

        final groups = snapshot.data?.docs ?? [];

        if (groups.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.group_off_rounded,
                    size: 64,
                    color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                        .withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No groups found',
                    style: AppTextStyles.bodyL.copyWith(
                      color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join or create a group to view settlements.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyM.copyWith(
                      color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
            vertical: 16,
          ),
          itemCount: groups.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final groupDoc = groups[index];
            final groupData = groupDoc.data() as Map<String, dynamic>;
            final groupName = groupData['name'] ?? 'Unnamed Group';
            final membersCount = (groupData['members'] as List?)?.length ?? 0;

            return ModernCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(16),
              color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
              onTap: () {
                setState(() {
                  _activeGroupId = groupDoc.id;
                });
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          groupName,
                          style: AppTextStyles.bodyL.copyWith(
                            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$membersCount member${membersCount != 1 ? 's' : ''}',
                          style: AppTextStyles.label.copyWith(
                            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettlementsList(bool isDark) {
    return StreamBuilder<List<Settlement>>(
      stream: _settlementService.getGroupSettlements(_activeGroupId!, limit: _limit),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading settlements',
              style: AppTextStyles.bodyL.copyWith(color: AppColors.error),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting && _loadedCount == 0) {
          return Center(
            child: CircularProgressIndicator(
              color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
            ),
          );
        }

        final settlements = snapshot.data ?? [];
        _loadedCount = settlements.length;
        _hasMore = _loadedCount >= _limit;

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
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
            vertical: 16,
          ),
          itemCount: settlements.length + (_hasMore ? 1 : 0),
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == settlements.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: CircularProgressIndicator(
                    color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                  ),
                ),
              );
            }
            final settlement = settlements[index];
            return AnimatedListItem(
              index: index,
              child: FutureBuilder<List<String>>(
                future: Future.wait([
                  _getCachedName(settlement.fromUserUid),
                  _getCachedName(settlement.toUserUid),
                ]),
                builder: (context, snapshot) {
                  final fromName = snapshot.data?[0] ?? 'User';
                  final toName = snapshot.data?[1] ?? 'User';

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
              ),
            );
          },
        );
      },
    );
  }
}
