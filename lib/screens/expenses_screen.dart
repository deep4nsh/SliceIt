import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/colors.dart';
import '../utils/text_styles.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> expenses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
  }

  Future<void> _fetchExpenses() async {
    setState(() => isLoading = true);
    final uid = _auth.currentUser!.uid;
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .orderBy('date', descending: true)
          .get();

      expenses = snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    } catch (e) {
      debugPrint("Error fetching expenses: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error fetching expenses")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _addOrEditExpense({Map<String, dynamic>? expense}) async {
    final titleController = TextEditingController(text: expense?['title']);
    final amountController = TextEditingController(
        text: expense != null ? expense['amount'].toString() : '');
    final categoryController = TextEditingController(text: expense?['category']);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(expense == null ? "Add Expense" : "Edit Expense"),
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
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: "Category"),
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
              if (titleController.text.isEmpty ||
                  amountController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Title and Amount are required")));
                return;
              }

              final uid = _auth.currentUser!.uid;
              final data = {
                'title': titleController.text,
                'amount': double.tryParse(amountController.text) ?? 0,
                'category': categoryController.text,
                'date': FieldValue.serverTimestamp(),
              };

              if (expense == null) {
                await _firestore
                    .collection('users')
                    .doc(uid)
                    .collection('expenses')
                    .add(data);
              } else {
                await _firestore
                    .collection('users')
                    .doc(uid)
                    .collection('expenses')
                    .doc(expense['id'])
                    .update(data);
              }
              Navigator.pop(context);
              _fetchExpenses();
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  Future<void> _deleteExpense(String expenseId) async {
    final uid = _auth.currentUser!.uid;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .doc(expenseId)
        .delete();
    _fetchExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text("Expenses"),
        backgroundColor: AppColors.oliveGreen,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.oliveGreen))
          : expenses.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/images/empty.png", height: 150),
            const SizedBox(height: 20),
            const Text("No expenses yet.\nTap + to add.",
                textAlign: TextAlign.center),
          ],
        ),
      )
          : ListView.builder(
        itemCount: expenses.length,
        itemBuilder: (_, index) {
          final expense = expenses[index];
          final date = expense['date'] != null
              ? (expense['date'] as Timestamp).toDate()
              : DateTime.now();
          final formattedDate = DateFormat('dd MMM yyyy').format(date);

          return Dismissible(
            key: Key(expense['id']),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) => _deleteExpense(expense['id']),
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(expense['title']),
                subtitle: Text("${expense['category']} • $formattedDate"),
                trailing: Text(
                  "₹ ${expense['amount'].toStringAsFixed(0)}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.oliveGreen),
                ),
                onTap: () => _addOrEditExpense(expense: expense),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.oliveGreen,
        icon: const Icon(Icons.add),
        label: const Text("Add Expense"),
        onPressed: () => _addOrEditExpense(),
      ),
    );
  }
}