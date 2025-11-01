import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/colors.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allExpenses = [];
  List<Map<String, dynamic>> _filteredExpenses = [];
  bool _isLoading = true;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
    _searchController.addListener(_filterExpenses);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterExpenses);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchExpenses() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final uid = _auth.currentUser!.uid;

    try {
      Query query = _firestore
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .orderBy('date', descending: true);

      if (_selectedDateRange != null) {
        query = query.where('date', isGreaterThanOrEqualTo: _selectedDateRange!.start);
        query = query.where('date', isLessThanOrEqualTo: _selectedDateRange!.end.add(const Duration(days: 1)));
      }

      final snapshot = await query.get();

      _allExpenses = snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
      _filterExpenses();
    } catch (e) {
      debugPrint("Error fetching expenses: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error fetching expenses")));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterExpenses() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredExpenses = _allExpenses.where((expense) {
        final title = (expense['title'] as String? ?? '').toLowerCase();
        final category = (expense['category'] as String? ?? '').toLowerCase();
        return title.contains(query) || category.contains(query);
      }).toList();
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      _fetchExpenses();
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
                if (!mounted) return;
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
              if (!mounted) return;
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
      appBar: AppBar(
        title: const Text("Expenses"),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _selectDateRange,
          ),
          if (_selectedDateRange != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _selectedDateRange = null;
                });
                _fetchExpenses();
              },
            )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by title or category...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredExpenses.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset("assets/images/empty.png", height: 150),
                  const SizedBox(height: 20),
                  const Text("No expenses found.",
                      textAlign: TextAlign.center),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _filteredExpenses.length,
              itemBuilder: (_, index) {
                final expense = _filteredExpenses[index];
                final date = expense['date'] != null
                    ? (expense['date'] as Timestamp).toDate()
                    : DateTime.now();
                final formattedDate =
                DateFormat('dd MMM yyyy').format(date);

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
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(expense['title']),
                      subtitle:
                      Text("${expense['category']} • $formattedDate"),
                      trailing: Text(
                        "₹ ${expense['amount'].toStringAsFixed(0)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.oliveGreen),
                      ),
                      onTap: () => _addOrEditExpense(expense: expense),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text("Add Expense"),
        onPressed: () => _addOrEditExpense(),
      ),
    );
  }
}
