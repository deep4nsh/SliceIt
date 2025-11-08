import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sliceit/utils/deep_link_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sliceit/services/invite_service.dart';

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

  Future<void> _launchEmailComposer(List<String> emails, {required String subject, required String body}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: emails.join(','),
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await Share.share(body, subject: subject);
      }
    } catch (_) {
      await Share.share(body, subject: subject);
    }
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
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Invite by Email'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Email addresses',
              hintText: 'Enter comma or newline separated emails',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final emails = _parseEmails(value ?? '');
              if (emails.isEmpty) return 'Enter at least one email';
              final invalid = emails.where((e) => !_isValidEmail(e)).toList();
              if (invalid.isNotEmpty) return 'Invalid: ${invalid.join(', ')}';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final emails = _parseEmails(controller.text);

              // Persist invites (optional tracking)
              final batch = _firestore.batch();
              for (final email in emails) {
                final doc = _firestore
                    .collection('groups')
                    .doc(widget.groupId)
                    .collection('invites')
                    .doc(email);
                batch.set(doc, {
                  'email': email,
                  'inviterUid': currentUser.uid,
                  'sentAt': FieldValue.serverTimestamp(),
                  'status': 'pending',
                }, SetOptions(merge: true));
              }
              await batch.commit();

              // Send real emails via Cloud Function
              try {
                await InviteService.sendGroupInvites(
                  groupId: widget.groupId,
                  inviterUid: currentUser.uid,
                  emails: emails,
                  subject: 'Join my SliceIt group',
                  body: _composeInviteBody(widget.groupId, currentUser.uid),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Invites sent to ${emails.length} recipient(s)')),
                  );
                }
              } catch (_) {
                // Fallback to email composer/share if cloud send fails
                await _launchEmailComposer(
                  emails,
                  subject: 'Join my SliceIt group',
                  body: _composeInviteBody(widget.groupId, currentUser.uid),
                );
              }

              if (mounted) Navigator.pop(context);
            },
            child: const Text('Send Invites'),
          ),
        ],
      ),
    );
  }

  List<String> _parseEmails(String raw) {
    return raw
        .split(RegExp(r'[\n,; ]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email);
  }

  String _composeInviteBody(String groupId, String inviterUid) {
    final httpLink = DeepLinkConfig.groupHttp(groupId, inviterUid);
    final schemeLink = DeepLinkConfig.groupScheme(groupId, inviterUid);
    return 'Hi,\n\nI\'d like you to join my SliceIt group.\n\nJoin link (opens app if installed):\n$httpLink\n\nIf the above does not open the app, tap this:\n$schemeLink\n\nThanks!';
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
            icon: const Icon(Icons.person_add_alt),
            tooltip: 'Invite by email',
            onPressed: _shareGroup,
          ),
        ],
      ),
      body: Column(
        children: [
          // Member List
          SizedBox(
            height: 100,
            child: StreamBuilder<DocumentSnapshot>(
              stream: _getGroupStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                final members = (data?['members'] as List?)?.cast<String>() ?? [];
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Chip(label: Text(members[index])),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(),
          // Group Expenses
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
