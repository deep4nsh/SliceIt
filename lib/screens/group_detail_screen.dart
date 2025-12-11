import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sliceit/services/debt_simplifier.dart';
import 'package:sliceit/utils/colors.dart';

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

  // Unified function to show the Add/Edit Expense Dialog
  Future<void> _showExpenseDialog({DocumentSnapshot? expenseDoc}) async {
    final groupDoc = await _getGroupStream().first;
    final members = (groupDoc.data() as Map<String, dynamic>?)?['members']?.cast<String>() ?? [];
    final currentUser = _auth.currentUser;

    if (mounted) {
      await showDialog(
        context: context,
        builder: (_) => _AddEditExpenseDialog(
          groupId: widget.groupId,
          groupMemberUids: members,
          expenseDoc: expenseDoc,
          canEdit: expenseDoc == null || (expenseDoc.data() as Map<String, dynamic>)['paidBy'] == currentUser?.uid,
        ),
      );
    }
  }





  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primaryNavy,
          foregroundColor: Colors.white,
          title: StreamBuilder<DocumentSnapshot>(
            stream: _getGroupStream(),
            builder: (context, snapshot) {
              final groupName = (snapshot.data?.data() as Map<String, dynamic>?)?['name'] ?? 'Group Details';
              return Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold));
            },
          ),
          actions: [
            // Removed unused StreamBuilder
          ],
          bottom: const TabBar(
            indicatorColor: AppColors.primaryGold,
            indicatorWeight: 3,
            labelColor: AppColors.primaryGold,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "Expenses"),
              Tab(text: "Balances"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildExpensesTab(),
            _buildBalancesTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showExpenseDialog(),
          backgroundColor: AppColors.secondaryTeal,
          label: const Text("Add Expense"),
          icon: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildExpensesTab() {
    return Column(
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
    );
  }

  Widget _buildBalancesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getGroupExpensesStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Error loading balances"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final expenses = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
        
        // Import DebtSimplifier locally or ensure it's imported at top
        // Assuming I'll add the import in a separate step or it's available.
        // For now, I'll rely on the file being created.
        // Wait, I need to add the import to the file first.
        
        // I will use a placeholder here and fix imports in next step if needed.
        // Actually, I can't easily add import in this replace block if it's far away.
        // I'll assume I can add the import at the top in a separate call.
        
        return FutureBuilder<List<Settlement>>(
          future: _calculateSettlements(expenses),
          builder: (context, settlementSnapshot) {
             if (!settlementSnapshot.hasData) return const Center(child: CircularProgressIndicator());
             final settlements = settlementSnapshot.data!;
             
             if (settlements.isEmpty) {
               return const Center(
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                     SizedBox(height: 16),
                     Text("All settled up!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   ],
                 ),
               );
             }

             return ListView.builder(
               padding: const EdgeInsets.all(16),
               itemCount: settlements.length,
               itemBuilder: (context, index) {
                 final settlement = settlements[index];
                 return Card(
                   elevation: 2,
                   margin: const EdgeInsets.only(bottom: 12),
                   child: Padding(
                     padding: const EdgeInsets.all(16.0),
                     child: Row(
                       children: [
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               UserNameDisplay(
                                 uid: settlement.fromUser,
                                 builder: (name) => Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                               ),
                               const Text("owes", style: TextStyle(color: Colors.grey)),
                               UserNameDisplay(
                                 uid: settlement.toUser,
                                 builder: (name) => Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                               ),
                             ],
                           ),
                         ),
                         Text(
                           "₹${settlement.amount.toStringAsFixed(2)}",
                           style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent),
                         ),
                       ],
                     ),
                   ),
                 );
               },
             );
          },
        );
      },
    );
  }

  Future<List<Settlement>> _calculateSettlements(List<Map<String, dynamic>> expenses) async {
    // This is a bit of a hack to avoid importing DebtSimplifier if I haven't added the import yet.
    // But I should really add the import.
    // I'll assume the import 'package:sliceit/services/debt_simplifier.dart' is added.
    return DebtSimplifier.simplifyDebts(expenses);
  }
}

// Dialog for Adding and Editing Expenses
class _AddEditExpenseDialog extends StatefulWidget {
  final String groupId;
  final List<String> groupMemberUids;
  final DocumentSnapshot? expenseDoc;
  final bool canEdit;

  const _AddEditExpenseDialog({
    required this.groupId,
    required this.groupMemberUids,
    this.expenseDoc,
    this.canEdit = true,
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
                enabled: widget.canEdit,
                validator: (value) => (value?.isEmpty ?? true) ? "Please enter a title" : null,
              ),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: "Amount", prefixText: "₹"),
                keyboardType: TextInputType.number,
                enabled: widget.canEdit,
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
                onChanged: widget.canEdit ? _onSelectAll : null,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(),
              ...widget.groupMemberUids.map((uid) {
                return CheckboxListTile(
                  title: UserNameDisplay(uid: uid, builder: (name) => Text(name)),
                  value: _selectedMembers[uid],
                  onChanged: widget.canEdit ? (bool? value) {
                    setState(() {
                      _selectedMembers[uid] = value!;
                      _checkSelectAll();
                    });
                  } : null,
                   controlAffinity: ListTileControlAffinity.leading,
                );
              }).toList(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        if (widget.canEdit)
          ElevatedButton(onPressed: _saveExpense, child: const Text("Save")),
        if (widget.expenseDoc != null)
           _SettleButton(
             expenseDoc: widget.expenseDoc!,
             currentUserUid: FirebaseAuth.instance.currentUser?.uid,
             groupId: widget.groupId,
           ),
      ],
    );
  }
}

class UserNameDisplay extends StatelessWidget {
  final String uid;
  final Widget Function(String name) builder;

  const UserNameDisplay({super.key, required this.uid, required this.builder});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return builder('...');
        if (snapshot.hasError || !snapshot.hasData) return builder('Unknown');
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final name = data?['name'] ?? 'User';
        return builder(name);
      },
    );
  }
}

class MemberChip extends StatelessWidget {
  final String uid;
  const MemberChip({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Chip(label: Text('...'));
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final name = data?['name'] ?? 'Unknown';
          final photoUrl = data?['photoUrl'];
          
          return Chip(
            avatar: CircleAvatar(
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null ? Text(name.isNotEmpty ? name[0] : '?') : null,
            ),
            label: Text(name),
            backgroundColor: AppColors.backgroundLight,
          );
        },
      ),
    );
  }
}

class _SettleButton extends StatefulWidget {
  final DocumentSnapshot expenseDoc;
  final String? currentUserUid;
  final String groupId;

  const _SettleButton({
    required this.expenseDoc,
    required this.currentUserUid,
    required this.groupId,
  });

  @override
  State<_SettleButton> createState() => _SettleButtonState();
}

class _SettleButtonState extends State<_SettleButton> {
  bool _isLoading = false;
  String? _txnId;

  Future<void> _settleWithUpi() async {
    setState(() => _isLoading = true);
    try {
      final data = widget.expenseDoc.data() as Map<String, dynamic>;
      final paidByUid = data['paidBy'];
      final amount = (data['amount'] as num).toDouble();
      final participants = (data['participants'] as List).cast<String>();

      if (!participants.contains(widget.currentUserUid)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are not a participant in this expense.')),
          );
        }
        return;
      }

      // Calculate split amount
      final splitAmount = participants.isNotEmpty ? amount / participants.length : 0.0;

      // 1. Call Cloud Function to Initiate Pay
      final result = await FirebaseFunctions.instance.httpsCallable('initiatePay').call({
        'expenseId': widget.expenseDoc.id,
        'amount': splitAmount,
        'receiverUid': paidByUid,
      });

      final resp = result.data as Map<dynamic, dynamic>;
      final txnId = resp['txnId'];
      final vpa = resp['vpa'];
      final name = resp['name'];
      final note = resp['note'];

      _txnId = txnId;

      // 2. Construct UPI URI
      final uriString = 'upi://pay?pa=$vpa&pn=$name&tr=$txnId&tn=$note&am=$splitAmount&cu=INR';
      final uri = Uri.parse(uriString);

      // 3. Launch Intent
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);

        // 4. Start Polling
        _pollTransactionStatus(txnId, splitAmount, paidByUid);
      } else {
        throw "Could not launch UPI app";
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _pollTransactionStatus(String txnId, double amount, String receiverUid) async {
    if (!mounted) return;

    // Show processing dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Verifying Payment..."),
          ],
        ),
      ),
    );

    int attempts = 0;
    bool success = false;

    while (attempts < 10) { // Poll for ~30 seconds
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;

      final doc = await FirebaseFirestore.instance.collection('transactions').doc(txnId).get();
      if (doc.exists && doc.data()?['status'] == 'SUCCESS') {
        success = true;
        break;
      }
      attempts++;
    }

    if (!mounted) return;
    Navigator.pop(context); // Close dialog

    if (success) {
      await _recordSettlement(amount, receiverUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment Successful! Bill Settled.')),
      );
      Navigator.pop(context); // Close Expense Dialog
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment processing or failed. Check status later.')),
      );
    }
  }

  Future<void> _recordSettlement(double amount, String receiverUid) async {
    // Current user paid 'amount' to 'receiverUid'
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('expenses')
        .add({
      'title': "Settlement Payment",
      'amount': amount,
      'paidBy': widget.currentUserUid,
      'participants': [receiverUid], // The person who received money
      'date': FieldValue.serverTimestamp(),
      'isSettlement': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.expenseDoc.data() as Map<String, dynamic>;
    final paidBy = data['paidBy'];
    final isPayer = paidBy == widget.currentUserUid;

    if (isPayer) {
      return const ElevatedButton(
        onPressed: null, // Disabled
        child: Text("You Paid"),
      );
    }

    return ElevatedButton(
      onPressed: _isLoading ? null : _settleWithUpi,
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.successGreen),
      child: _isLoading
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Text("Settle with UPI"),
    );
  }
}
