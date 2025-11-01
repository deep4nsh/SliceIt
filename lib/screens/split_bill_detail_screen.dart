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
    await _firestore.collection('split_bills').doc(widget.splitId).update({
      'paidStatus.$userEmail': isPaid,
    });

    // If this user is settling their own debt, add it to their expenses
    if (isPaid && userEmail == _auth.currentUser?.email) {
      final splitDoc = await _firestore.collection('split_bills').doc(widget.splitId).get();
      final data = splitDoc.data();
      if (data == null) return;

      final totalAmount = (data['totalAmount'] as num).toDouble();
      final participantsCount = (data['participants'] as List).length;
      final amountPerPerson = participantsCount > 0 ? totalAmount / participantsCount : 0;

      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('expenses')
          .add({
        'title': "Split: ${data['title']}",
        'amount': amountPerPerson,
        'category': 'Bill Split',
        'date': FieldValue.serverTimestamp(),
      });
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
          final amountPerPerson = participants.isNotEmpty ? totalAmount / participants.length : 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Total: ₹${totalAmount.toStringAsFixed(2)}", style: Theme.of(context).textTheme.titleLarge),
                    Text("Each: ₹${amountPerPerson.toStringAsFixed(2)}", style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                Text("Participants", style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 10),
                ...participants.map((email) {
                  final isPaid = paidStatus[email] ?? false;
                  final canToggle = data['createdBy'] == _auth.currentUser?.email || email == _auth.currentUser?.email;

                  return Card(
                    elevation: 2,
                    child: ListTile(
                      title: Text(email),
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
