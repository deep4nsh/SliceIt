import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    // Get the split document first to access its data
    final splitDoc = await _firestore.collection('split_bills').doc(widget.splitId).get();
    final data = splitDoc.data();
    if (data == null) return;

    // Update the paid status in Firestore
    await _firestore.collection('split_bills').doc(widget.splitId).update({
      'paidStatus.$userEmail': isPaid,
    });

    // If this user is settling their own debt, add it to their expenses
    if (isPaid && userEmail == _auth.currentUser?.email) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Split Details"),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('split_bills').doc(widget.splitId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading details"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() as Map<String, dynamic>?;
          if (data == null) {
            return const Center(child: Text("Split not found"));
          }

          final title = data['title'] ?? 'No Title';
          final totalAmount = (data['totalAmount'] as num).toDouble();
          final participants = (data['participants'] as List).cast<String>();
          final paidStatus = (data['paidStatus'] as Map).cast<String, bool>();
          final createdBy = data['createdBy'] as String?;
          final currentUserEmail = _auth.currentUser?.email;
          final splitType = data['splitType'] as String? ?? 'equal';
          final amounts = (data['amounts'] as Map?)?.cast<String, num>() ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 10),
                Text("Total: ₹${totalAmount.toStringAsFixed(2)}", style: Theme.of(context).textTheme.titleLarge),
                if (splitType == 'equal')
                  Text("Each: ₹${(participants.isNotEmpty ? totalAmount / participants.length : 0).toStringAsFixed(2)}", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),
                const Divider(),
                Text("Participants", style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 10),
                ...participants.map((email) {
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
                          if(canToggle)
                          Switch(
                            value: isPaid,
                            onChanged: (value) => _markAsPaid(email, value),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }
}
