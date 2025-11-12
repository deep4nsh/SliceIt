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
    // ... (rest of the function is unchanged)
  }

  Stream<QuerySnapshot> _getGroupExpensesStream() {
    return _firestore
        .collection('groups')
        .doc(widget.groupId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots();
  }

  // Unified function to show the Add/Edit Expense Dialog
  Future<void> _showExpenseDialog({DocumentSnapshot? expenseDoc}) async {
    final groupDoc = await _getGroupStream().first;
    final members = (groupDoc.data() as Map<String, dynamic>?)?['members']?.cast<String>() ?? [];

    if (mounted) {
      await showDialog(
        context: context,
        builder: (_) => _AddEditExpenseDialog(
          groupId: widget.groupId,
          groupMemberUids: members,
          expenseDoc: expenseDoc,
        ),
      );
    }
  }

  Future<void> _shareGroup(String groupName) async {
    // ... (rest of the function is unchanged)
  }

  List<String> _parseEmails(String raw) {
    // ... (rest of the function is unchanged)
    return [];
  }

  bool _isValidEmail(String email) {
    // ... (rest of the function is unchanged)
    return true;
  }

  String _composeInviteBody(String groupId, String inviterUid) {
    // ... (rest of the function is unchanged)
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: _getGroupStream(),
          builder: (context, snapshot) {
            final groupName = (snapshot.data?.data() as Map<String, dynamic>?)?['name'] ?? 'Group Details';
            return Text(groupName);
          },
        ),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: _getGroupStream(),
            builder: (context, snapshot) {
              final groupName = (snapshot.data?.data() as Map<String, dynamic>?)?['name'] ?? '';
              return IconButton(
                icon: const Icon(Icons.person_add_alt),
                tooltip: 'Invite by email',
                onPressed: () => _shareGroup(groupName),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Members", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            height: 60,
            child: StreamBuilder<DocumentSnapshot>(
              stream: _getGroupStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final members = (snapshot.data!.data() as Map<String, dynamic>?)?['members']?.cast<String>() ?? [];
                if (members.isEmpty) return const Center(child: Text("No members yet."));
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    return MemberChip(uid: members[index]);
                  },
                );
              },
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Expenses", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getGroupExpensesStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Error loading expenses"));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No expenses yet. Add one!"));

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final expenseDoc = snapshot.data!.docs[index];
                    final data = expenseDoc.data() as Map<String, dynamic>;
                    final participants = (data['participants'] as List?)?.cast<String>() ?? [];
                    return ListTile(
                      title: Text(data['title'] ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: UserNameDisplay(
                        uid: data['paidBy'],
                        builder: (name) => Text('Paid by $name • Split with ${participants.length}'),
                      ),
                      trailing: Text("₹${(data['amount'] as num).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      onTap: () => _showExpenseDialog(expenseDoc: expenseDoc),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExpenseDialog(),
        label: const Text("Add Expense"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

// Dialog for Adding and Editing Expenses
class _AddEditExpenseDialog extends StatefulWidget {
  final String groupId;
  final List<String> groupMemberUids;
  final DocumentSnapshot? expenseDoc;

  const _AddEditExpenseDialog({
    required this.groupId,
    required this.groupMemberUids,
    this.expenseDoc,
  });

  @override
  State<_AddEditExpenseDialog> createState() => _AddEditExpenseDialogState();
}

class _AddEditExpenseDialogState extends State<_AddEditExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late Map<String, bool> _selectedMembers;
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    final existingData = widget.expenseDoc?.data() as Map<String, dynamic>?;
    _titleController = TextEditingController(text: existingData?['title']);
    _amountController = TextEditingController(text: existingData?['amount']?.toString());

    _selectedMembers = {
      for (var uid in widget.groupMemberUids)
        uid: (existingData?['participants'] as List?)?.contains(uid) ?? true,
    };
    _checkSelectAll();
  }

  void _checkSelectAll() {
    _selectAll = _selectedMembers.values.every((isSelected) => isSelected);
  }

  void _onSelectAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      _selectedMembers.updateAll((_, __) => _selectAll);
    });
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text;
    final amount = double.tryParse(_amountController.text);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (amount == null || currentUser == null) return;

    final participants = _selectedMembers.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one participant.")));
      return;
    }

    final expenseData = {
      'title': title,
      'amount': amount,
      'paidBy': currentUser.uid,
      'participants': participants,
      'date': FieldValue.serverTimestamp(),
    };

    final collection = FirebaseFirestore.instance.collection('groups').doc(widget.groupId).collection('expenses');
    
    if (widget.expenseDoc == null) {
      await collection.add(expenseData);
    } else {
      await collection.doc(widget.expenseDoc!.id).update(expenseData);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.expenseDoc == null ? "Add Expense" : "Edit Expense"),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Title"),
                validator: (value) => (value?.isEmpty ?? true) ? "Please enter a title" : null,
              ),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: "Amount", prefixText: "₹"),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return "Please enter an amount";
                  if (double.tryParse(value) == null) return "Please enter a valid number";
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Text("Split with:", style: TextStyle(fontWeight: FontWeight.bold)),
              CheckboxListTile(
                title: const Text("Select All"),
                value: _selectAll,
                onChanged: _onSelectAll,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(),
              ...widget.groupMemberUids.map((uid) {
                return CheckboxListTile(
                  title: UserNameDisplay(uid: uid, builder: (name) => Text(name)),
                  value: _selectedMembers[uid],
                  onChanged: (bool? value) {
                    setState(() {
                      _selectedMembers[uid] = value!;
                      _checkSelectAll();
                    });
                  },
                   controlAffinity: ListTileControlAffinity.leading,
                );
              }).toList(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(onPressed: _saveExpense, child: const Text("Save")),
      ],
    );
  }
}

// Helper widget to fetch and display a user's name from their UID
class UserNameDisplay extends StatelessWidget {
  final String uid;
  final Widget Function(String name) builder;

  const UserNameDisplay({super.key, required this.uid, required this.builder});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text("Loading...");
        }
        final name = (snapshot.data?.data() as Map<String, dynamic>?)?['name'] ?? 'Unknown User';
        return builder(name);
      },
    );
  }
}

// A new widget to fetch and display member info
class MemberChip extends StatefulWidget {
  final String uid;
  const MemberChip({super.key, required this.uid});

  @override
  State<MemberChip> createState() => _MemberChipState();
}

class _MemberChipState extends State<MemberChip> {
  String _name = '...';
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  Future<void> _fetchUserInfo() async {
    if (!mounted) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      if (mounted && doc.exists) {
        setState(() {
          _name = doc.data()?['name'] ?? '...';
          _imageUrl = doc.data()?['photoUrl'];
        });
      } else {
         setState(() => _name = 'Unknown');
      }
    } catch (e) {
      if (mounted) setState(() => _name = 'Error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Chip(
        avatar: CircleAvatar(
          backgroundImage: _imageUrl != null ? NetworkImage(_imageUrl!) : null,
          child: _imageUrl == null ? Text(_name.substring(0, 1)) : null,
        ),
        label: Text(_name),
      ),
    );
  }
}
