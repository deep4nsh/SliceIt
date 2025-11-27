import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sliceit/services/upi_payment_service.dart';

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

    if (isPaid && userEmail == _auth.currentUser?.email) {
      await _addExpenseToPersonalLog(data, userEmail);
    }
  }

  Future<void> _addExpenseToPersonalLog(Map<String, dynamic> data, String userEmail) async {
    final totalAmount = (data['totalAmount'] as num).toDouble();
    final participants = (data['participants'] as List);
    final splitType = data['splitType'] ?? 'equal';
    double expenseAmount = 0;

    if (splitType == 'unequal') {
      final amounts = (data['amounts'] as Map).cast<String, num>();
      expenseAmount = (amounts[userEmail] ?? 0).toDouble();
    } else {
      expenseAmount = participants.isNotEmpty ? totalAmount / participants.length : 0;
    }

    if (expenseAmount > 0) {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('expenses')
          .add({
        'title': "Split: ${data['title']}",
        'amount': expenseAmount,
        'category': 'Bill Split',
        'date': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _settleUpWithUpi({
    required double amount,
    required String description,
    required String createdByEmail,
    required String payerEmail,
  }) async {
    // 1. Find the creator's user document to get their UPI ID
    final querySnapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: createdByEmail)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find the bill creator.')),
        );
      }
      return;
    }

    final creatorData = querySnapshot.docs.first.data();
    final upiId = creatorData['upiId'] as String?;

    if (upiId == null || upiId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The bill creator has not set their UPI ID.')),
        );
      }
      return;
    }

    // 2. Try paying via UPI (Android returns actual status via platform channel)
    final upi = UpiPaymentService();
    final status = await upi.pay(
      upiId: upiId,
      amount: amount,
      payeeName: 'SliceIt Lender',
      note: description,
    );

    // 3. Handle result
    if (!mounted) return;
    if (status == 'success') {
      await _markAsPaid(payerEmail, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment successful. Marked as paid.')),
      );
    } else if (status == 'submitted') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment submitted. It may take a moment to reflect.')),
      );
    } else if (status == 'failure' || status == 'cancelled') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment not completed.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not confirm payment status.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Split Details"),
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
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Delete Split Bill?"),
                        content: const Text("This will delete this split bill for ALL participants. This action cannot be undone."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text("Delete"),
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
          if (snapshot.hasError) return const Center(child: Text("Error loading details"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data?.data() as Map<String, dynamic>?;
          if (data == null) return const Center(child: Text("Split not found"));

          final title = data['title'] ?? 'No Title';
          final totalAmount = (data['totalAmount'] as num).toDouble();
          final participants = (data['participants'] as List).cast<String>();
          final paidStatus = (data['paidStatus'] as Map).cast<String, bool>();
          final createdBy = data['createdBy'] as String?;
          final currentUserEmail = _auth.currentUser?.email;
          final splitType = data['splitType'] as String? ?? 'equal';
          final amounts = (data['amounts'] as Map?)?.cast<String, num>() ?? {};

          final currentUserIsParticipant = participants.contains(currentUserEmail);
          final currentUserHasPaid = paidStatus[currentUserEmail] ?? false; // Default to false if not found

          double amountOwedByCurrentUser = 0;
          if (currentUserIsParticipant) {
            if (splitType == 'unequal') {
              amountOwedByCurrentUser = (amounts[currentUserEmail] ?? 0).toDouble();
            } else {
              amountOwedByCurrentUser = participants.isNotEmpty ? totalAmount / participants.length : 0;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 10),
                Text("Total: ₹${totalAmount.toStringAsFixed(2)}", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),
                const Divider(),
                Text("Participants", style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 10),
                  ...participants.where((email) => email != createdBy).map((email) {
                  final isPaid = paidStatus[email] ?? false;
                  final canToggle = createdBy == currentUserEmail || email == currentUserEmail;
                  final amountOwed = splitType == 'unequal'
                      ? (amounts[email] ?? 0).toDouble()
                      : (participants.isNotEmpty ? totalAmount / participants.length : 0);

                  return Card(
                    elevation: 2,
                    child: ListTile(
                      title: Text(email),
                      subtitle: Text('Owes: ₹${amountOwed.toStringAsFixed(2)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(isPaid ? "Paid" : "Unpaid", style: TextStyle(color: isPaid ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                          if (canToggle) Switch(value: isPaid, onChanged: (value) => _markAsPaid(email, value)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                if (currentUserIsParticipant && !currentUserHasPaid && createdBy != currentUserEmail)
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('users')
                          .where('email', isEqualTo: createdBy)
                          .limit(1)
                          .snapshots(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData || userSnapshot.data!.docs.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        
                        final creatorData = userSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                        final upiId = creatorData['upiId'] as String?;
                        final hasUpi = upiId != null && upiId.isNotEmpty;

                        if (!hasUpi) {
                           return Container(
                             padding: const EdgeInsets.all(12),
                             decoration: BoxDecoration(
                               color: Colors.orange.withOpacity(0.1),
                               borderRadius: BorderRadius.circular(8),
                               border: Border.all(color: Colors.orange.withOpacity(0.3)),
                             ),
                             child: Row(
                               children: [
                                 const Icon(Icons.info_outline, color: Colors.orange),
                                 const SizedBox(width: 12),
                                 Expanded(
                                   child: Text(
                                     "Waiting for bill creator to add UPI ID for settlement.",
                                     style: TextStyle(color: Colors.orange[800]),
                                   ),
                                 ),
                               ],
                             ),
                           );
                        }

                        return ElevatedButton(
                          onPressed: () => _settleUpWithUpi(
                            amount: amountOwedByCurrentUser,
                            description: title,
                            createdByEmail: createdBy!,
                            payerEmail: currentUserEmail!,
                          ),
                          child: const Text('Settle with UPI'),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        );
                      },
                    ),
                  )
              ],
            ),
          );
        },
      ),
    );
  }
}
