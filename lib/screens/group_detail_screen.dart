import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/services.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<DocumentSnapshot> _getGroupStream() {
    return _firestore.collection('groups').doc(widget.groupId).snapshots();
  }

  Stream<QuerySnapshot> _getGroupExpensesStream() {
    return _firestore
        .collection('groups')
        .doc(widget.groupId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> _addExpense() async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Group Expense"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Title"),
            ),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: "Amount"),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty || amountController.text.isEmpty) return;

              await _firestore
                  .collection('groups')
                  .doc(widget.groupId)
                  .collection('expenses')
                  .add({
                'title': titleController.text,
                'amount': double.tryParse(amountController.text) ?? 0,
                'paidBy': _auth.currentUser?.email,
                'date': FieldValue.serverTimestamp(),
              });

              if (mounted) Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  Future<void> _shareGroup() async {
    final parameters = DynamicLinkParameters(
      uriPrefix: 'https://sliceit.page.link', // Replace with your domain
      link: Uri.parse('https://sliceit.page.link/group?id=${widget.groupId}'),
      androidParameters: const AndroidParameters(
        packageName: 'com.example.sliceit', // Replace with your package name
        minimumVersion: 1,
      ),
      iosParameters: const IosParameters(
        bundleId: 'com.example.sliceit', // Replace with your bundle id
        minimumVersion: '1',
      ),
    );

    final shortLink = await FirebaseDynamicLinks.instance.buildShortLink(parameters);
    await Clipboard.setData(ClipboardData(text: shortLink.shortUrl.toString()));
    
    if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Group invite link copied to clipboard!")),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: _getGroupStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Text('Group');
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            return Text(data?['name'] ?? 'Group Details');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareGroup,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getGroupExpensesStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Error loading expenses"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final expenses = snapshot.data?.docs ?? [];

                if (expenses.isEmpty) {
                  return const Center(child: Text("No expenses in this group yet."));
                }

                return ListView.builder(
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    final data = expense.data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['title'] ?? 'No Title'),
                      subtitle: Text("Paid by: ${data['paidBy']}"),
                      trailing: Text("₹${(data['amount'] as num).toStringAsFixed(2)}"),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpense,
        label: const Text("Add Expense"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
