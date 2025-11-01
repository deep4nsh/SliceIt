import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'split_bill_detail_screen.dart'; // We will create this next

class SplitBillsScreen extends StatefulWidget {
  const SplitBillsScreen({super.key});

  @override
  State<SplitBillsScreen> createState() => _SplitBillsScreenState();
}

class _SplitBillsScreenState extends State<SplitBillsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot> _getSplitsStream() {
    final userEmail = _auth.currentUser?.email;
    if (userEmail == null) return const Stream.empty();

    return _firestore
        .collection('split_bills')
        .where('participants', arrayContains: userEmail)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _addSplitBill() async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final participantsController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Create New Split"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Title"),
              ),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: "Total Amount"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: participantsController,
                decoration: const InputDecoration(
                    labelText: "Participant Emails (comma-separated)"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty ||
                  amountController.text.isEmpty ||
                  participantsController.text.isEmpty) {
                return;
              }

              final userEmail = _auth.currentUser!.email!;
              final participants = participantsController.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toSet()
                  .toList(); // Use Set to avoid duplicates
              
              if (!participants.contains(userEmail)) {
                  participants.add(userEmail);
              }

              // Initialize paid status. Creator is marked as paid.
              final paidStatus = {for (var p in participants) p: p == userEmail};

              await _firestore.collection('split_bills').add({
                'title': titleController.text,
                'totalAmount': double.tryParse(amountController.text) ?? 0,
                'participants': participants,
                'createdBy': userEmail,
                'createdAt': FieldValue.serverTimestamp(),
                'paidStatus': paidStatus,
              });

              if (mounted) Navigator.pop(context);
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Bills'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getSplitsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading splits"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final splits = snapshot.data?.docs ?? [];

          if (splits.isEmpty) {
            return const Center(child: Text("No bill splits yet."));
          }

          return ListView.builder(
            itemCount: splits.length,
            itemBuilder: (context, index) {
              final split = splits[index];
              final data = split.data() as Map<String, dynamic>;
              final amount = (data['totalAmount'] as num).toDouble();
              final participantsCount = (data['participants'] as List).length;
              final amountPerPerson = participantsCount > 0 ? amount / participantsCount : 0;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SplitBillDetailScreen(splitId: split.id),
                      ),
                    );
                  },
                  title: Text(data['title'] ?? 'No Title'),
                  subtitle: Text("Created by: ${data['createdBy']}"),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "₹${amount.toStringAsFixed(2)}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text("₹${amountPerPerson.toStringAsFixed(2)} each"),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSplitBill,
        label: const Text("New Split"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
