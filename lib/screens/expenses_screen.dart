import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import '../widgets/modern_card.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/mesh_background.dart';

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
  Timer? _debounce;
  static final DateFormat _dateFormatter = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _filterExpenses);
  }

  Future<void> _fetchExpenses() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final uid = currentUser.uid;

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
          SnackBar(
            content: Text("Error fetching expenses", style: AppTextStyles.bodyM),
            backgroundColor: AppColors.error,
          ),
        );
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

  double get _totalFilteredAmount {
    return _filteredExpenses.fold(0.0, (sum, exp) => sum + (exp['amount'] as num? ?? 0.0));
  }

  Future<void> _selectDateRange() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppColors.secondaryAccent,
                    onPrimary: Colors.black,
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: AppColors.primaryAccent,
                    onPrimary: Colors.white,
                    onSurface: Colors.black,
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
    final categoryController = TextEditingController(text: expense?['category'] ?? 'General');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(
            color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
          ),
        ),
        title: Text(
          expense == null ? "Add Expense" : "Edit Expense",
          style: AppTextStyles.h2.copyWith(
            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: "Title",
                labelStyle: AppTextStyles.bodyM.copyWith(
                  color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: const BorderSide(color: AppColors.primaryAccent),
                ),
              ),
              style: AppTextStyles.bodyL.copyWith(
                color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: "Amount",
                labelStyle: AppTextStyles.bodyM.copyWith(
                  color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                ),
                prefixText: '₹ ',
                prefixStyle: AppTextStyles.bodyL.copyWith(
                  color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                  fontWeight: FontWeight.bold,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: const BorderSide(color: AppColors.primaryAccent),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppTextStyles.bodyL.copyWith(
                color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: categoryController,
              decoration: InputDecoration(
                labelText: "Category",
                labelStyle: AppTextStyles.bodyM.copyWith(
                  color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: const BorderSide(color: AppColors.primaryAccent),
                ),
              ),
              style: AppTextStyles.bodyL.copyWith(
                color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: AppTextStyles.button.copyWith(
                color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
            ),
            onPressed: () async {
              if (titleController.text.trim().isEmpty || amountController.text.trim().isEmpty) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Title and Amount are required", style: AppTextStyles.bodyM),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }

              final uid = _auth.currentUser?.uid;
              if (uid == null) return;

              final data = {
                'title': titleController.text.trim(),
                'amount': double.tryParse(amountController.text.trim()) ?? 0.0,
                'category': categoryController.text.trim().isEmpty ? 'General' : categoryController.text.trim(),
                'date': expense?['date'] ?? FieldValue.serverTimestamp(),
              };

              if (expense == null) {
                await _firestore.collection('users').doc(uid).collection('expenses').add(data);
              } else {
                await _firestore.collection('users').doc(uid).collection('expenses').doc(expense['id']).update(data);
              }

              if (!mounted) return;
              Navigator.pop(context);
              _fetchExpenses();
            },
            child: Text("Save", style: AppTextStyles.button.copyWith(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExpense(String expenseId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .doc(expenseId)
          .delete();
      _fetchExpenses();
    } catch (e) {
      debugPrint("Error deleting expense: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            "Expenses",
            style: AppTextStyles.h2.copyWith(
              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                Icons.filter_list_rounded,
                color: _selectedDateRange != null
                    ? (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent)
                    : (isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary),
              ),
              onPressed: _selectDateRange,
              tooltip: 'Filter by date range',
            ),
            if (_selectedDateRange != null)
              IconButton(
                icon: Icon(
                  Icons.clear_rounded,
                  color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                ),
                onPressed: () {
                  setState(() {
                    _selectedDateRange = null;
                  });
                  _fetchExpenses();
                },
                tooltip: 'Clear filter',
              ),
          ],
        ),
        body: Column(
          children: [
            // Total Aggregated Metrics Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: 8),
              child: ModernCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedDateRange != null ? 'Filtered Total' : 'Total Expenses',
                          style: AppTextStyles.label.copyWith(
                            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${_totalFilteredAmount.toStringAsFixed(2)}',
                          style: AppTextStyles.h1.copyWith(
                            color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                            fontSize: 28,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkSurface2 : AppColors.lightSurface2).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 28,
                        color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                      ),
                    ),
                  ],
                ),
              ).animate().fade().scaleXY(begin: 0.95, end: 1.0),
            ),

            // Search input field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: 8),
              child: TextField(
                controller: _searchController,
                style: AppTextStyles.bodyL.copyWith(
                  color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search by title or category...',
                  hintStyle: AppTextStyles.bodyM.copyWith(
                    color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ),

            // Main List Area
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredExpenses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_rounded,
                                size: 80,
                                color: (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)
                                    .withValues(alpha: 0.2),
                              ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 0.95, end: 1.05),
                              const SizedBox(height: 16),
                              Text(
                                "No expenses recorded",
                                style: AppTextStyles.h3.copyWith(
                                  color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Track your personal outlays beautifully.",
                                style: AppTextStyles.bodyM.copyWith(
                                  color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: 8),
                          itemCount: _filteredExpenses.length,
                          itemBuilder: (_, index) {
                            final expense = _filteredExpenses[index];
                            final date = expense['date'] != null
                                ? (expense['date'] as Timestamp).toDate()
                                : DateTime.now();
                            final formattedDate = _dateFormatter.format(date);

                            return AnimatedListItem(
                              index: index,
                              child: Dismissible(
                                key: Key(expense['id']),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                                  ),
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                                ),
                                onDismissed: (_) => _deleteExpense(expense['id']),
                                child: ModernCard(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                                  onTap: () => _addOrEditExpense(expense: expense),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: (isDark ? AppColors.secondaryAccent : AppColors.primaryAccent)
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                        ),
                                        child: Icon(
                                          Icons.receipt_rounded,
                                          color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              expense['title'] ?? '',
                                              style: AppTextStyles.bodyL.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "${expense['category'] ?? 'General'} • $formattedDate",
                                              style: AppTextStyles.label.copyWith(
                                                color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        "₹${(expense['amount'] as num? ?? 0).toStringAsFixed(0)}",
                                        style: AppTextStyles.h3.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
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
          heroTag: 'add_expense_fab',
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            "Add Expense",
            style: AppTextStyles.button.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppColors.primaryAccent,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
          onPressed: () => _addOrEditExpense(),
        ),
      ),
    );
  }
}
