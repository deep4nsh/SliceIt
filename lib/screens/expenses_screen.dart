import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/colors.dart';
import '../widgets/modern_card.dart';
import '../widgets/animated_list_item.dart';

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

      _allExpenses = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return null;
        return {...data, 'id': doc.id};
      }).whereType<Map<String, dynamic>>().toList();
      
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryOrange,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
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
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: "Amount"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
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
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
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
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by title or category...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    "No expenses found",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 18),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredExpenses.length,
              itemBuilder: (_, index) {
                final expense = _filteredExpenses[index];
                final date = expense['date'] != null
                    ? (expense['date'] as Timestamp).toDate()
                    : DateTime.now();
                final formattedDate =
                DateFormat('dd MMM yyyy').format(date);

                return AnimatedListItem(
                  index: index,
                  child: Dismissible(
                    key: Key(expense['id']),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => _deleteExpense(expense['id']),
                    child: ModernCard(
                      onTap: () => _addOrEditExpense(expense: expense),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryTeal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.receipt, color: AppColors.secondaryTeal),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  expense['title'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${expense['category'] ?? ''} • $formattedDate",
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "₹${expense['amount']?.toStringAsFixed(0) ?? '0'}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primaryOrange,
                            ),
                          ),
                        ],
                      ),
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
        backgroundColor: AppColors.primaryOrange,
        onPressed: () => _addOrEditExpense(),
      ),
    );
  }
}
