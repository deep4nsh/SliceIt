import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<Map<String, double>> getHomeStats() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value({'spent': 0.0, 'owe': 0.0, 'owed': 0.0});
    }

    late StreamController<Map<String, double>> controller;
    StreamSubscription? groupsSub;
    StreamSubscription? splitBillsSub;
    final Map<String, StreamSubscription> expensesSubs = {};
    final Map<String, List<QueryDocumentSnapshot>> groupExpensesDocs = {};

    List<QueryDocumentSnapshot>? latestSplitBills;
    bool isGroupsLoaded = false;

    void updateStats() {
      if (!isGroupsLoaded || latestSplitBills == null) return;

      double totalSpent = 0.0;
      double youOwe = 0.0;
      double owedToYou = 0.0;

      // 1. Group Expenses (Net Balance per Group)
      groupExpensesDocs.forEach((groupId, docs) {
        double groupNetBalance = 0.0;

        for (var expenseDoc in docs) {
          final data = expenseDoc.data() as Map<String, dynamic>?;
          if (data == null) continue;

          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          final paidBy = data['paidBy'] as String?;
          final participants = (data['participants'] as List?)?.cast<String>() ?? [];
          final isSettlement = data['isSettlement'] == true;

          if (participants.isEmpty || paidBy == null) continue;
          final splitAmount = amount / participants.length;

          if (!isSettlement) {
            // Only regular expenses add to personal total spent
            if (participants.contains(user.uid)) {
              totalSpent += splitAmount;
            }
          }

          // Net balance contribution for this expense
          if (paidBy == user.uid) {
            groupNetBalance += amount;
          }
          if (participants.contains(user.uid)) {
            groupNetBalance -= splitAmount;
          }
        }

        // Aggregate net group balance into global statistics
        if (groupNetBalance > 0.01) {
          owedToYou += groupNetBalance;
        } else if (groupNetBalance < -0.01) {
          youOwe += groupNetBalance.abs();
        }
      });

      // 2. Split Bills (Direct splits)
      final userEmail = user.email;
      if (userEmail != null) {
        for (var doc in latestSplitBills!) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;

          final createdBy = data['createdBy'] as String?;
          final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
          final participants = (data['participants'] as List?)?.cast<String>() ?? [];
          final paidStatus = (data['paidStatus'] as Map?)?.cast<String, bool>() ?? {};
          final splitType = data['splitType'] as String? ?? 'equal';
          final amounts = (data['amounts'] as Map?)?.cast<String, num>() ?? {};

          // Personal spent calculation
          if (participants.contains(userEmail)) {
            double myShare = 0;
            if (splitType.contains('unequal')) {
              myShare = (amounts[userEmail] ?? 0).toDouble();
            } else {
              myShare = participants.isNotEmpty ? totalAmount / participants.length : 0;
            }
            totalSpent += myShare;
          }

          // Outstanding debts and credits calculation
          if (createdBy == userEmail) {
            // Current user created the bill; others owe them if unpaid
            for (var participant in participants) {
              if (participant != userEmail) {
                final isPaid = paidStatus[participant] ?? false;
                if (!isPaid) {
                  double amountOwed = 0;
                  if (splitType.contains('unequal')) {
                    amountOwed = (amounts[participant] ?? 0).toDouble();
                  } else {
                    amountOwed = participants.isNotEmpty ? totalAmount / participants.length : 0;
                  }
                  owedToYou += amountOwed;
                }
              }
            }
          } else {
            // Current user is a participant who owes the creator if unpaid
            final isPaid = paidStatus[userEmail] ?? false;
            if (!isPaid) {
              double amountOwed = 0;
              if (splitType.contains('unequal')) {
                amountOwed = (amounts[userEmail] ?? 0).toDouble();
              } else {
                amountOwed = participants.isNotEmpty ? totalAmount / participants.length : 0;
              }
              youOwe += amountOwed;
            }
          }
        }
      }

      if (!controller.isClosed) {
        controller.add({
          'spent': totalSpent,
          'owe': youOwe,
          'owed': owedToYou,
        });
      }
    }

    controller = StreamController<Map<String, double>>.broadcast(
      onListen: () {
        // Subscribe to groups collection
        groupsSub = _firestore
            .collection('groups')
            .where('members', arrayContains: user.uid)
            .snapshots()
            .listen((snapshot) {
          isGroupsLoaded = true;
          final currentGroupIds = snapshot.docs.map((doc) => doc.id).toSet();

          // Cancel subscriptions for groups left
          final removedGroupIds = expensesSubs.keys.toSet().difference(currentGroupIds);
          for (var groupId in removedGroupIds) {
            expensesSubs[groupId]?.cancel();
            expensesSubs.remove(groupId);
            groupExpensesDocs.remove(groupId);
          }

          // Subscribe to expenses subcollection for new groups
          for (var doc in snapshot.docs) {
            final groupId = doc.id;
            if (!expensesSubs.containsKey(groupId)) {
              expensesSubs[groupId] = doc.reference
                  .collection('expenses')
                  .snapshots()
                  .listen((expensesSnapshot) {
                groupExpensesDocs[groupId] = expensesSnapshot.docs;
                updateStats();
              });
            }
          }

          updateStats();
        });

        // Subscribe to split bills collection
        final userEmail = user.email;
        if (userEmail != null) {
          splitBillsSub = _firestore
              .collection('split_bills')
              .where('participants', arrayContains: userEmail)
              .limit(50)
              .snapshots()
              .listen((snapshot) {
            latestSplitBills = snapshot.docs;
            updateStats();
          });
        } else {
          latestSplitBills = [];
          updateStats();
        }
      },
      onCancel: () {
        groupsSub?.cancel();
        splitBillsSub?.cancel();
        for (var sub in expensesSubs.values) {
          sub.cancel();
        }
        expensesSubs.clear();
      },
    );

    return controller.stream;
  }
}

