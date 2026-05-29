import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/friend_service.dart';
import '../models/friend_model.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import '../utils/deep_link_config.dart';
import '../widgets/modern_card.dart';
import '../widgets/mesh_background.dart';
import '../widgets/animated_list_item.dart';

class GroupSettingsScreen extends StatefulWidget {
  final String groupId;

  const GroupSettingsScreen({super.key, required this.groupId});

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FriendService _friendService = FriendService();

  final Map<String, Map<String, dynamic>> _userCache = {};
  bool _isProcessing = false;

  static const List<Map<String, dynamic>> _groupThemes = [
    {
      'name': 'Slate',
      'color': Color(0xFF5B6F82),
      'gradient': [Color(0xFF5B6F82), Color(0xFF7A8B9E)],
    },
    {
      'name': 'Teal',
      'color': Color(0xFF6B9EAA),
      'gradient': [Color(0xFF6B9EAA), Color(0xFF8BB5BD)],
    },
    {
      'name': 'Purple',
      'color': Color(0xFF8F7EAA),
      'gradient': [Color(0xFF8F7EAA), Color(0xFFA597BE)],
    },
    {
      'name': 'Orange',
      'color': Color(0xFFD68A65),
      'gradient': [Color(0xFFD68A65), Color(0xFFE2A385)],
    },
    {
      'name': 'Emerald',
      'color': Color(0xFF5CA387),
      'gradient': [Color(0xFF5CA387), Color(0xFF7CB8A0)],
    },
  ];

  static const List<Map<String, String>> _categoriesList = [
    {'emoji': '✈️', 'name': 'Trip'},
    {'emoji': '🏠', 'name': 'Home'},
    {'emoji': '🍔', 'name': 'Food'},
    {'emoji': '🍿', 'name': 'Entertainment'},
    {'emoji': '🚗', 'name': 'Road Trip'},
    {'emoji': '🛒', 'name': 'Groceries'},
    {'emoji': '👥', 'name': 'Friends'},
    {'emoji': '💼', 'name': 'Work'},
    {'emoji': '🎁', 'name': 'Gifts'},
    {'emoji': '💡', 'name': 'Bills'},
    {'emoji': '🎳', 'name': 'Sports'},
    {'emoji': '❤️', 'name': 'Couple'},
  ];

  Stream<DocumentSnapshot> _getGroupStream() {
    return _firestore.collection('groups').doc(widget.groupId).snapshots();
  }

  Future<Map<String, dynamic>> _getCachedUserDetails(String uid) async {
    if (_userCache.containsKey(uid)) {
      return _userCache[uid]!;
    }
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        _userCache[uid] = data;
        return data;
      }
    } catch (e) {
      debugPrint('Error fetching user info for $uid: $e');
    }
    return {'name': 'User', 'email': 'No email'};
  }

  // Calculate net balances for all members in the group to verify settlement status
  Future<Map<String, double>> _calculateGroupBalances(List<String> members) async {
    final expensesSnapshot = await _firestore
        .collection('groups')
        .doc(widget.groupId)
        .collection('expenses')
        .get();

    final balances = <String, double>{};
    for (final m in members) {
      balances[m] = 0.0;
    }

    for (var doc in expensesSnapshot.docs) {
      final data = doc.data();
      final double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final String paidBy = data['paidBy'] as String? ?? '';
      final List<String> participants = (data['participants'] as List?)?.cast<String>() ?? [];

      if (paidBy.isEmpty || participants.isEmpty || amount <= 0) continue;

      balances.update(paidBy, (value) => value + amount, ifAbsent: () => amount);

      final double splitAmount = amount / participants.length;
      for (var participant in participants) {
        balances.update(participant, (value) => value - splitAmount, ifAbsent: () => -splitAmount);
      }
    }

    return balances;
  }

  Future<Map<String, dynamic>> _getSimplificationStats(List<String> members) async {
    final expensesSnapshot = await _firestore
        .collection('groups')
        .doc(widget.groupId)
        .collection('expenses')
        .get();

    final expenses = expensesSnapshot.docs.map((doc) => doc.data()).toList();
    
    // Group Balances calculated
    final balances = <String, double>{};
    for (final m in members) {
      balances[m] = 0.0;
    }

    int rawCount = 0;
    for (var data in expenses) {
      final double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final String paidBy = data['paidBy'] as String? ?? '';
      final List<String> participants = (data['participants'] as List?)?.cast<String>() ?? [];

      if (paidBy.isEmpty || participants.isEmpty || amount <= 0) continue;

      balances.update(paidBy, (value) => value + amount, ifAbsent: () => amount);

      final double splitAmount = amount / participants.length;
      for (var participant in participants) {
        balances.update(participant, (value) => value - splitAmount, ifAbsent: () => -splitAmount);
        if (participant != paidBy) {
          rawCount++;
        }
      }
    }

    // Simplified transaction count
    final simplifiedSettlements = _simplifyDebtsLocal(expenses, members);
    final simplifiedCount = simplifiedSettlements.length;

    int saved = (rawCount - simplifiedCount).clamp(0, 9999);
    double efficiency = rawCount > 0 ? (saved / rawCount) * 100 : 0.0;

    return {
      'rawCount': rawCount,
      'simplifiedCount': simplifiedCount,
      'saved': saved,
      'efficiency': efficiency.toStringAsFixed(0),
    };
  }

  // Local settlement helper reproducing simplification
  List<dynamic> _simplifyDebtsLocal(List<Map<String, dynamic>> expenses, List<String> members) {
    final balances = <String, double>{};
    for (var m in members) {
      balances[m] = 0.0;
    }
    for (var data in expenses) {
      final double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final String paidBy = data['paidBy'] as String? ?? '';
      final List<String> participants = (data['participants'] as List?)?.cast<String>() ?? [];
      if (paidBy.isEmpty || participants.isEmpty || amount <= 0) continue;

      balances.update(paidBy, (v) => v + amount, ifAbsent: () => amount);
      final double split = amount / participants.length;
      for (var p in participants) {
        balances.update(p, (v) => v - split, ifAbsent: () => -split);
      }
    }

    final debtors = <MapEntry<String, double>>[];
    final creditors = <MapEntry<String, double>>[];
    for (var entry in balances.entries) {
      if (entry.value < -0.01) {
        debtors.add(entry);
      } else if (entry.value > 0.01) {
        creditors.add(entry);
      }
    }

    debtors.sort((a, b) => a.value.compareTo(b.value));
    creditors.sort((a, b) => b.value.compareTo(a.value));

    final results = [];
    int i = 0, j = 0;
    
    // Greedy matching
    var debtList = debtors.map((e) => MapEntry(e.key, e.value.abs())).toList();
    var creditList = creditors.map((e) => MapEntry(e.key, e.value)).toList();

    while (i < debtList.length && j < creditList.length) {
      double debt = debtList[i].value;
      double credit = creditList[j].value;
      double minVal = debt < credit ? debt : credit;

      results.add({
        'from': debtList[i].key,
        'to': creditList[j].key,
        'amount': minVal,
      });

      debtList[i] = MapEntry(debtList[i].key, debt - minVal);
      creditList[j] = MapEntry(creditList[j].key, credit - minVal);

      if (debtList[i].value < 0.01) i++;
      if (creditList[j].value < 0.01) j++;
    }

    return results;
  }

  Future<void> _renameGroup(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(
            color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
            width: 1,
          ),
        ),
        title: Text(
          'Rename Group',
          style: AppTextStyles.h2.copyWith(
            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
            fontSize: 20,
          ),
        ),
        content: TextField(
          controller: controller,
          style: AppTextStyles.bodyL.copyWith(
            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
          ),
          decoration: InputDecoration(
            labelText: 'New Group Name',
            labelStyle: AppTextStyles.bodyM.copyWith(
              color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent).withValues(alpha: 0.3)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTextStyles.button.copyWith(
                color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
              foregroundColor: isDark ? AppColors.textDarkPrimary : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
              elevation: 0,
            ),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == currentName) {
                Navigator.pop(context);
                return;
              }
              setState(() => _isProcessing = true);
              try {
                await _firestore.collection('groups').doc(widget.groupId).update({'name': newName});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Group renamed successfully!', style: AppTextStyles.bodyM),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to rename group: $e', style: AppTextStyles.bodyM),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isProcessing = false);
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareInvite() async {
    final groupDoc = await _firestore.collection('groups').doc(widget.groupId).get();
    final groupName = groupDoc.data()?['name'] ?? 'SliceIt Group';

    final currentUser = _auth.currentUser;
    final inviterUid = currentUser?.uid ?? '';
    final httpLink = DeepLinkConfig.groupHttp(widget.groupId, inviterUid);

    await Clipboard.setData(ClipboardData(text: httpLink));

    if (mounted) {
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

    final text = "Hey! Join my group '$groupName' on SliceIt to split bills easily.\n\nTap here to join automatically:\n$httpLink";
    await Share.share(text, subject: "Join my SliceIt group '$groupName'");
  }

  Future<void> _removeMember(String memberUid, String memberName, List<String> currentMembers) async {
    setState(() => _isProcessing = true);
    try {
      final balances = await _calculateGroupBalances(currentMembers);
      final balance = balances[memberUid] ?? 0.0;

      if (balance.abs() > 0.01) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface2 : AppColors.lightSurface1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                side: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
                ),
              ),
              title: Text('Cannot Remove Member', style: AppTextStyles.h2.copyWith(color: AppColors.error, fontSize: 18)),
              content: Text(
                '$memberName has an unsettled balance of ₹${balance.toStringAsFixed(2)} in this group.\n\nAll group balances for this member must be settled before removing them.',
                style: AppTextStyles.bodyL.copyWith(color: Theme.of(context).brightness == Brightness.dark ? AppColors.textLightPrimary : AppColors.textDarkPrimary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: AppTextStyles.button.copyWith(color: AppColors.secondaryAccent)),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Confirm removal
      if (mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface2 : AppColors.lightSurface1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              side: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
              ),
            ),
            title: Text('Remove Member?', style: AppTextStyles.h2.copyWith(fontSize: 18)),
            content: Text(
              'Are you sure you want to remove $memberName from the group? Their details will still remain on expenses they participated in, but they won\'t see the group anymore.',
              style: AppTextStyles.bodyL,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: AppTextStyles.button.copyWith(color: (Theme.of(context).brightness == Brightness.dark ? AppColors.textLightSecondary : AppColors.textDarkSecondary))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await _firestore.collection('groups').doc(widget.groupId).update({
            'members': FieldValue.arrayRemove([memberUid])
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$memberName has been removed.', style: AppTextStyles.bodyM),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove member: $e', style: AppTextStyles.bodyM),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _leaveGroup(List<String> currentMembers) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isProcessing = true);
    try {
      final balances = await _calculateGroupBalances(currentMembers);
      final balance = balances[currentUser.uid] ?? 0.0;

      if (balance.abs() > 0.01) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface2 : AppColors.lightSurface1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                side: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
                ),
              ),
              title: Text('Cannot Leave Group', style: AppTextStyles.h2.copyWith(color: AppColors.error, fontSize: 18)),
              content: Text(
                'You have an unsettled balance of ₹${balance.toStringAsFixed(2)} in this group.\n\nPlease settle all outstanding expenses and debts before leaving the group.',
                style: AppTextStyles.bodyL.copyWith(color: Theme.of(context).brightness == Brightness.dark ? AppColors.textLightPrimary : AppColors.textDarkPrimary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: AppTextStyles.button.copyWith(color: AppColors.secondaryAccent)),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Confirm leaving
      if (mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface2 : AppColors.lightSurface1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              side: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
              ),
            ),
            title: Text('Leave Group?', style: AppTextStyles.h2.copyWith(fontSize: 18)),
            content: const Text(
              'Are you sure you want to leave this group? You will no longer be able to see the expenses list or balances.',
              style: AppTextStyles.bodyL,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: AppTextStyles.button.copyWith(color: (Theme.of(context).brightness == Brightness.dark ? AppColors.textLightSecondary : AppColors.textDarkSecondary))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Leave', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await _firestore.collection('groups').doc(widget.groupId).update({
            'members': FieldValue.arrayRemove([currentUser.uid])
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('You have left the group.', style: AppTextStyles.bodyM),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave group: $e', style: AppTextStyles.bodyM),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteGroup(List<String> currentMembers) async {
    setState(() => _isProcessing = true);
    try {
      final balances = await _calculateGroupBalances(currentMembers);
      bool hasUnsettled = false;
      String unsettledDetail = '';

      for (var entry in balances.entries) {
        if (entry.value.abs() > 0.01) {
          hasUnsettled = true;
          final userDetails = await _getCachedUserDetails(entry.key);
          final name = userDetails['name'] ?? 'User';
          unsettledDetail += '• $name: ₹${entry.value.toStringAsFixed(2)}\n';
        }
      }

      if (mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface2 : AppColors.lightSurface1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              side: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
              ),
            ),
            title: Text(hasUnsettled ? 'Delete Group Warning' : 'Delete Group?', style: AppTextStyles.h2.copyWith(color: hasUnsettled ? AppColors.warning : AppColors.error, fontSize: 18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasUnsettled) ...[
                  const Text(
                    'Warning: The following members still have unsettled balances in this group:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(unsettledDetail, style: AppTextStyles.bodyM),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'Are you sure you want to permanently delete this group? This action will erase all expenses, settlements, and member records. This cannot be undone.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: AppTextStyles.button.copyWith(color: (Theme.of(context).brightness == Brightness.dark ? AppColors.textLightSecondary : AppColors.textDarkSecondary))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (confirm == true) {
          final batch = _firestore.batch();

          final expensesSnapshot = await _firestore
              .collection('groups')
              .doc(widget.groupId)
              .collection('expenses')
              .get();
          for (var doc in expensesSnapshot.docs) {
            batch.delete(doc.reference);
          }

          final settlementsSnapshot = await _firestore
              .collection('groups')
              .doc(widget.groupId)
              .collection('settlements')
              .get();
          for (var doc in settlementsSnapshot.docs) {
            batch.delete(doc.reference);
          }

          batch.delete(_firestore.collection('groups').doc(widget.groupId));
          await batch.commit();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Group deleted successfully.', style: AppTextStyles.bodyM),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete group: $e', style: AppTextStyles.bodyM),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showAddMemberBottomSheet(List<String> currentMembers) {
    final searchController = TextEditingController();
    List<Friend> searchResults = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> performSearch() async {
              final query = searchController.text.trim();
              if (query.isEmpty) return;

              setModalState(() => isSearching = true);
              try {
                final results = await _friendService.searchUsers(query);
                setModalState(() => searchResults = results);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Search failed: $e'), backgroundColor: AppColors.error),
                  );
                }
              } finally {
                setModalState(() => isSearching = false);
              }
            }

            Future<void> addMemberToGroup(String uid, String email, String? name) async {
              setModalState(() => _isProcessing = true);
              try {
                await _firestore.collection('groups').doc(widget.groupId).update({
                  'members': FieldValue.arrayUnion([uid])
                });

                await _friendService.addFriend(Friend(
                  uid: uid,
                  email: email,
                  name: name,
                ));

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${name ?? email} added to group!', style: AppTextStyles.bodyM),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add member: $e'), backgroundColor: AppColors.error),
                  );
                }
              } finally {
                setModalState(() => _isProcessing = false);
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface1,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
                border: Border.all(color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder),
              ),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                16,
                AppSpacing.screenPadding,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Add Group Member',
                    style: AppTextStyles.h2.copyWith(
                      color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ModernCard(
                    color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface2,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      controller: searchController,
                      style: AppTextStyles.bodyL.copyWith(color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary),
                      decoration: InputDecoration(
                        hintText: "Search user by email...",
                        hintStyle: AppTextStyles.bodyL.copyWith(
                          color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary).withValues(alpha: 0.4),
                        ),
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: Icon(Icons.search_rounded, color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent),
                          onPressed: performSearch,
                        ),
                      ),
                      onSubmitted: (_) => performSearch(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: searchController.text.trim().isNotEmpty
                        ? (isSearching
                            ? const Center(child: CircularProgressIndicator())
                            : (searchResults.isEmpty
                                ? Center(
                                    child: Text('No users found', style: AppTextStyles.bodyM.copyWith(color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)),
                                  )
                                : ListView.separated(
                                    itemCount: searchResults.length,
                                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final friend = searchResults[index];
                                      final isAlreadyInGroup = currentMembers.contains(friend.uid);

                                      return ModernCard(
                                        color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface2,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                                              backgroundImage: friend.photoUrl != null ? NetworkImage(friend.photoUrl!) : null,
                                              child: friend.photoUrl == null
                                                  ? Text(
                                                      (friend.name ?? friend.email)[0].toUpperCase(),
                                                      style: TextStyle(color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent),
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(friend.name ?? 'User', style: AppTextStyles.bodyL.copyWith(fontWeight: FontWeight.bold)),
                                                  Text(friend.email, style: AppTextStyles.label.copyWith(color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)),
                                                ],
                                              ),
                                            ),
                                            if (isAlreadyInGroup)
                                              Text('In Group', style: AppTextStyles.label.copyWith(color: AppColors.success))
                                            else
                                              IconButton(
                                                icon: Icon(Icons.add_circle_outline_rounded, color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent),
                                                onPressed: () => addMemberToGroup(friend.uid, friend.email, friend.name),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  )))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select from Friends',
                                style: AppTextStyles.bodyL.copyWith(fontWeight: FontWeight.bold, color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: StreamBuilder<List<Friend>>(
                                  stream: _friendService.getFriendsStream(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    }
                                    final friends = snapshot.data ?? [];
                                    final eligibleFriends = friends.where((f) => !currentMembers.contains(f.uid)).toList();

                                    if (eligibleFriends.isEmpty) {
                                      return Center(
                                        child: Text(
                                          friends.isEmpty ? 'No friends added yet.' : 'All friends are already members.',
                                          style: AppTextStyles.bodyM.copyWith(color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary),
                                        ),
                                      );
                                    }

                                    return ListView.separated(
                                      itemCount: eligibleFriends.length,
                                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        final friend = eligibleFriends[index];
                                        return ModernCard(
                                          color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface2,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                                                backgroundImage: friend.photoUrl != null ? NetworkImage(friend.photoUrl!) : null,
                                                child: friend.photoUrl == null
                                                    ? Text(
                                                        (friend.name ?? friend.email)[0].toUpperCase(),
                                                        style: TextStyle(color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent),
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(friend.name ?? 'User', style: AppTextStyles.bodyL.copyWith(fontWeight: FontWeight.bold)),
                                                    Text(friend.email, style: AppTextStyles.label.copyWith(color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.add_circle_outline_rounded, color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent),
                                                onPressed: () => addMemberToGroup(friend.uid, friend.email, friend.name),
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCustomizationBottomSheet(String currentEmoji, String currentCategory, int currentThemeIndex) {
    String selectedEmoji = currentEmoji.isEmpty ? '✈️' : currentEmoji;
    String selectedCategory = currentCategory.isEmpty ? 'Trip' : currentCategory;
    int selectedThemeIndex = currentThemeIndex;
    final categoryController = TextEditingController(text: selectedCategory);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface1,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
                border: Border.all(color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder),
              ),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                16,
                AppSpacing.screenPadding,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Group Customization',
                    style: AppTextStyles.h2.copyWith(
                      color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Emoji Grid
                  Text('Choose Emoji Icon', style: AppTextStyles.bodyL.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: _categoriesList.length,
                      itemBuilder: (context, index) {
                        final catObj = _categoriesList[index];
                        final emoji = catObj['emoji']!;
                        final isSelected = selectedEmoji == emoji;

                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedEmoji = emoji;
                              selectedCategory = catObj['name']!;
                              categoryController.text = selectedCategory;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent).withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              border: Border.all(
                                color: isSelected
                                    ? (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent)
                                    : (isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder).withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(emoji, style: const TextStyle(fontSize: 24)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Category Text Field
                  TextFormField(
                    controller: categoryController,
                    style: AppTextStyles.bodyL.copyWith(color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary),
                    decoration: InputDecoration(
                      labelText: "Category Name",
                      labelStyle: AppTextStyles.bodyM.copyWith(color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent).withValues(alpha: 0.3)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Theme Colors Selector
                  Text('Select Color Theme', style: AppTextStyles.bodyL.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_groupThemes.length, (index) {
                      final themeObj = _groupThemes[index];
                      final isSelected = selectedThemeIndex == index;
                      final color = themeObj['color'] as Color;

                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            selectedThemeIndex = index;
                          });
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                            ],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                              : null,
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                        foregroundColor: isDark ? AppColors.textDarkPrimary : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                      ),
                      onPressed: () async {
                        setState(() => _isProcessing = true);
                        try {
                          await _firestore.collection('groups').doc(widget.groupId).update({
                            'emoji': selectedEmoji,
                            'category': categoryController.text.trim(),
                            'themeColorIndex': selectedThemeIndex,
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Group customized successfully!', style: AppTextStyles.bodyM),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to customize: $e'), backgroundColor: AppColors.error),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isProcessing = false);
                        }
                      },
                      child: const Text('Apply Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showQRCodeDialog(String name, String emoji, Color color) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = _auth.currentUser;
    final inviterUid = currentUser?.uid ?? '';
    final httpLink = DeepLinkConfig.groupHttp(widget.groupId, inviterUid);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark 
                  ? [AppColors.darkSurface2, AppColors.darkBackground] 
                  : [Colors.white, AppColors.lightSurface2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              )
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ticket Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji.isNotEmpty ? emoji : '🍕', style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      name,
                      style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'SCAN TO JOIN GROUP',
                style: AppTextStyles.label.copyWith(
                  color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 24),
              // Simulated QR Code Frame
              Container(
                width: 220,
                height: 220,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Stack(
                  children: [
                    QrImageView(
                      data: httpLink,
                      version: QrVersions.auto,
                      size: 196,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: color,
                      ),
                      dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: color,
                      ),
                    ),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          emoji.isNotEmpty ? emoji : '🍕',
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Let a friend scan this code using their phone camera to instantly join the ledger and start splitting bills.',
                style: AppTextStyles.bodyM.copyWith(
                  color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary).withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary),
                    tooltip: 'Close',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: httpLink));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Link copied to clipboard!', style: AppTextStyles.bodyM),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: const Text('Copy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color.withValues(alpha: 0.15),
                        foregroundColor: color,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          side: BorderSide(color: color.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _shareInvite();
                      },
                      icon: const Icon(Icons.share_rounded, size: 14),
                      label: const Text('Share', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSimplificationExplorer(List<String> members) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final stats = await _getSimplificationStats(members);
    
    if (mounted) {
      Navigator.pop(context); // Dismiss Loading
      
      final int rawCount = stats['rawCount'] ?? 0;
      final int simplifiedCount = stats['simplifiedCount'] ?? 0;
      final int saved = stats['saved'] ?? 0;
      final String efficiency = stats['efficiency'] ?? '0';

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface1,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
            border: Border.all(color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Simplification Insights',
                style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'SliceIt uses graph optimization to minimize transaction volume, saving you from back-and-forth bank transfers.',
                style: AppTextStyles.bodyM.copyWith(
                  color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary).withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 24),
              // Efficiency Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.success.withValues(alpha: 0.15),
                      (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent).withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$efficiency% Payments Reduced',
                            style: AppTextStyles.bodyL.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Eliminated $saved unnecessary transfer${saved == 1 ? '' : 's'}!',
                            style: AppTextStyles.label.copyWith(
                              color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Graph Stats
              Row(
                children: [
                  Expanded(
                    child: ModernCard(
                      color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface2,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text('Raw Debts', style: AppTextStyles.label),
                          const SizedBox(height: 8),
                          Text(
                            '$rawCount',
                            style: AppTextStyles.h1.copyWith(
                              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('Individual splits', style: AppTextStyles.label.copyWith(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ModernCard(
                      color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface2,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text('Optimized', style: AppTextStyles.label.copyWith(color: AppColors.success, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                            '$simplifiedCount',
                            style: AppTextStyles.h1.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('Actual payments', style: AppTextStyles.label.copyWith(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Description
              Text(
                'How it works:',
                style: AppTextStyles.bodyL.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Instead of having everyone settle individual splits separately (e.g. A owes B ₹10, B owes C ₹10), SliceIt aggregates all net debt claims across expenses and runs a network simplification solver. It resolves these into the minimum possible transactions (e.g. just A pays C ₹10).',
                style: AppTextStyles.bodyM.copyWith(
                  color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary).withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkSurface1 : AppColors.lightSurface2,
                    foregroundColor: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                    side: BorderSide(color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Awesome!', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = _auth.currentUser;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Group Settings',
            style: AppTextStyles.h2.copyWith(
              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: _isProcessing
            ? Center(child: CircularProgressIndicator(color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent))
            : StreamBuilder<DocumentSnapshot>(
                stream: _getGroupStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent));
                  }
                  if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                    return Center(
                      child: Text('Error loading group settings', style: AppTextStyles.bodyL.copyWith(color: AppColors.error)),
                    );
                  }

                  final groupData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                  final groupName = groupData['name'] ?? 'Unnamed Group';
                  final createdBy = groupData['createdBy'] ?? '';
                  final List<String> members = (groupData['members'] as List?)?.cast<String>() ?? [];
                  final isCreator = createdBy == currentUser?.uid;

                  // Customizations properties
                  final groupEmoji = groupData['emoji'] as String? ?? '';
                  final category = groupData['category'] as String? ?? '';
                  final themeColorIndex = groupData['themeColorIndex'] as int? ?? 0;
                  
                  final activeTheme = _groupThemes[themeColorIndex.clamp(0, _groupThemes.length - 1)];
                  final Color selectedColor = activeTheme['color'] as Color;
                  final List<Color> selectedGradient = activeTheme['gradient'] as List<Color>;
                  final String selectedThemeName = activeTheme['name'] as String;

                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    children: [
                      // Group Name Header Card with Theme Gradient Background
                      ModernCard(
                        color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: selectedGradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: selectedColor.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  )
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  groupEmoji.isNotEmpty ? groupEmoji : (groupName.isNotEmpty ? groupName[0].toUpperCase() : 'G'),
                                  style: AppTextStyles.h1.copyWith(
                                    color: Colors.white,
                                    fontSize: groupEmoji.isNotEmpty ? 36 : 30,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    groupName,
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.h2.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                                    ),
                                  ),
                                ),
                                if (isCreator) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(Icons.edit_rounded, color: selectedColor, size: 20),
                                    tooltip: 'Rename Group',
                                    onPressed: () => _renameGroup(groupName),
                                  ),
                                ],
                              ],
                            ),
                            if (category.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: selectedColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                                  border: Border.all(color: selectedColor.withValues(alpha: 0.2)),
                                ),
                                child: Text(
                                  category,
                                  style: AppTextStyles.label.copyWith(
                                    color: selectedColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            FutureBuilder<Map<String, dynamic>>(
                              future: _getCachedUserDetails(createdBy),
                              builder: (context, creatorSnapshot) {
                                final creatorName = creatorSnapshot.data?['name'] ?? 'Creator';
                                return Text(
                                  'Created by $creatorName',
                                  style: AppTextStyles.label.copyWith(
                                    color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary).withValues(alpha: 0.8),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ).animate().fade(duration: 300.ms),

                      const SizedBox(height: 16),

                      // Premium Action Cards: QR Code & Debt Simplifier
                      Row(
                        children: [
                          Expanded(
                            child: ModernCard(
                              color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                              padding: const EdgeInsets.all(14),
                              onTap: () => _showQRCodeDialog(groupName, groupEmoji, selectedColor),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: selectedColor.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.qr_code_2_rounded, color: selectedColor, size: 22),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Group QR Code',
                                    style: AppTextStyles.bodyM.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Scan to join',
                                    style: AppTextStyles.label.copyWith(fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ModernCard(
                              color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                              padding: const EdgeInsets.all(14),
                              onTap: () => _showSimplificationExplorer(members),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.query_stats_rounded, color: AppColors.success, size: 22),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Simplifier Insights',
                                    style: AppTextStyles.bodyM.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'View efficiency',
                                    style: AppTextStyles.label.copyWith(fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ).animate().fade(duration: 300.ms, delay: 100.ms),

                      const SizedBox(height: 24),

                      // Customization Section
                      if (isCreator) ...[
                        Text(
                          'Customization',
                          style: AppTextStyles.h3.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ModernCard(
                          color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: selectedColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Text(groupEmoji.isNotEmpty ? groupEmoji : '🎨', style: const TextStyle(fontSize: 20)),
                            ),
                            title: Text('Category & Theme Color', style: AppTextStyles.bodyL.copyWith(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              category.isNotEmpty ? '$category • $selectedThemeName' : 'Tap to customize emoji & color',
                              style: AppTextStyles.label.copyWith(color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary).withValues(alpha: 0.7)),
                            ),
                            trailing: Icon(Icons.chevron_right_rounded, color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary),
                            onTap: () => _showCustomizationBottomSheet(groupEmoji, category, themeColorIndex),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Members Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Members (${members.length})',
                            style: AppTextStyles.h3.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                            ),
                          ),
                          if (isCreator)
                            TextButton.icon(
                              icon: Icon(Icons.person_add_rounded, size: 18, color: selectedColor),
                              label: Text(
                                'Add Member',
                                style: TextStyle(color: selectedColor, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => _showAddMemberBottomSheet(members),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Members List
                      ...members.map((uid) {
                        final isMemberCreator = uid == createdBy;
                        final isMe = uid == currentUser?.uid;

                        return FutureBuilder<Map<String, dynamic>>(
                          future: _getCachedUserDetails(uid),
                          builder: (context, memberDetailsSnapshot) {
                            if (!memberDetailsSnapshot.hasData) {
                              return Container(
                                height: 60,
                                margin: const EdgeInsets.only(bottom: 10),
                                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: selectedColor))),
                              );
                            }

                            final data = memberDetailsSnapshot.data!;
                            final name = data['name'] ?? 'User';
                            final email = data['email'] ?? 'No Email';
                            final photoUrl = data['photoUrl'];

                            return AnimatedListItem(
                              index: members.indexOf(uid),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                  border: Border.all(color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                                      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                                      child: photoUrl == null
                                          ? Text(
                                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                                              style: TextStyle(color: selectedColor, fontWeight: FontWeight.bold),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  name + (isMe ? ' (You)' : ''),
                                                  style: AppTextStyles.bodyL.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isMemberCreator) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: selectedColor.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: selectedColor.withValues(alpha: 0.3)),
                                                  ),
                                                  child: Text(
                                                    'Creator',
                                                    style: AppTextStyles.label.copyWith(
                                                      color: selectedColor,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            email,
                                            style: AppTextStyles.label.copyWith(
                                              color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary).withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isCreator && !isMemberCreator && !isMe)
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.error),
                                        tooltip: 'Remove Member',
                                        onPressed: () => _removeMember(uid, name, members),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }),

                      const SizedBox(height: 32),

                      // Danger Zone / Actions Card
                      Text(
                        'Danger Zone',
                        style: AppTextStyles.h3.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ModernCard(
                        color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!isCreator)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                                  foregroundColor: AppColors.error,
                                  shadowColor: Colors.transparent,
                                  side: const BorderSide(color: AppColors.error, width: 1),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.exit_to_app_rounded, size: 20),
                                label: const Text('Leave Group', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () => _leaveGroup(members),
                              )
                            else
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                                  foregroundColor: AppColors.error,
                                  shadowColor: Colors.transparent,
                                  side: const BorderSide(color: AppColors.error, width: 1),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.delete_forever_rounded, size: 20),
                                label: const Text('Delete Group', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () => _deleteGroup(members),
                              ),
                          ],
                        ),
                      ).animate().fade(duration: 300.ms, delay: 200.ms),

                      const SizedBox(height: 48),
                    ],
                  );
                },
              ),
      ),
    );
  }
}


