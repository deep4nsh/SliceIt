import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../utils/colors.dart';

enum AnalyticsRange { week, month, all }

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AnalyticsRange _selectedRange = AnalyticsRange.month;
  Map<String, double> _categoryData = {};
  List<Map<String, dynamic>> _dailySpending = [];
  double _totalSpending = 0.0;
  double _monthlyBudget = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final uid = _auth.currentUser!.uid;
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedRange) {
      case AnalyticsRange.week:
        startDate = now.subtract(Duration(days: now.weekday - 1));
        break;
      case AnalyticsRange.month:
        startDate = DateTime(now.year, now.month, 1);
        break;
      case AnalyticsRange.all:
        startDate = DateTime(2000);
        break;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      _monthlyBudget = (userDoc.data()?['monthlyBudget'] ?? 0.0).toDouble();

      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      final categoryData = <String, double>{};
      final dailySpending = <String, double>{};
      double totalSpending = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final category = data['category'] as String;
        final amount = (data['amount'] as num).toDouble();
        final date = (data['date'] as Timestamp).toDate();
        final dayKey = DateFormat('yyyy-MM-dd').format(date);

        categoryData.update(category, (value) => value + amount, ifAbsent: () => amount);
        dailySpending.update(dayKey, (value) => value + amount, ifAbsent: () => amount);
        totalSpending += amount;
      }

      if (mounted) {
        setState(() {
          _categoryData = categoryData;
          _dailySpending = dailySpending.entries
              .map((e) => {'day': e.key, 'amount': e.value})
              .toList()
            ..sort((a, b) {
              final dayA = a['day'] as String;
              final dayB = b['day'] as String;
              return dayA.compareTo(dayB);
            });
          _totalSpending = totalSpending;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching analytics data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getRandomColor(String key) {
    return Colors.primaries[key.hashCode % Colors.primaries.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRangeSelector(),
            const SizedBox(height: 20),
            _buildBudgetSummary(),
            const SizedBox(height: 20),
            _buildPieChart(),
            const SizedBox(height: 20),
            _buildBarChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeSelector() {
    return SegmentedButton<AnalyticsRange>(
      segments: const [
        ButtonSegment(value: AnalyticsRange.week, label: Text('Week')),
        ButtonSegment(value: AnalyticsRange.month, label: Text('Month')),
        ButtonSegment(value: AnalyticsRange.all, label: Text('All')),
      ],
      selected: {_selectedRange},
      onSelectionChanged: (newSelection) {
        setState(() {
          _selectedRange = newSelection.first;
          _fetchData();
        });
      },
    );
  }

  Widget _buildBudgetSummary() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("Spending Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text("Total Spending", style: TextStyle(color: Colors.grey)),
                    Text("₹${_totalSpending.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.oliveGreen)),
                  ],
                ),
                if (_selectedRange == AnalyticsRange.month)
                  Column(
                    children: [
                      const Text("Monthly Budget", style: TextStyle(color: Colors.grey)),
                      Text("₹${_monthlyBudget.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
              ],
            ),
            if (_selectedRange == AnalyticsRange.month && _monthlyBudget > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: LinearProgressIndicator(
                  value: _totalSpending / _monthlyBudget,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    if (_categoryData.isEmpty) return const Center(child: Text("No data for pie chart"));

    final pieChartSections = _categoryData.entries.map((entry) {
      return PieChartSectionData(
        color: _getRandomColor(entry.key),
        value: entry.value,
        title: '${(entry.value / _totalSpending * 100).toStringAsFixed(0)}%',
        radius: 80,
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("By Category", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: pieChartSections,
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: _categoryData.keys.map((key) {
                return Chip(label: Text(key), backgroundColor: _getRandomColor(key).withAlpha(70));
              }).toList(),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    if (_dailySpending.isEmpty) return const Center(child: Text("No daily spending data"));

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("Daily Spending", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: _dailySpending.asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: data['amount'],
                          color: AppColors.oliveGreen,
                          width: 15,
                          borderRadius: BorderRadius.circular(4)
                        )
                      ]
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if(index < _dailySpending.length && index % 2 == 0) {
                            final dayString = _dailySpending[index]['day'];
                            if (dayString == null) return const Text('');
                            final day = DateTime.parse(dayString);
                            return Text(DateFormat('d/M').format(day));
                          }
                          return const Text('');
                        },
                        reservedSize: 30,
                      ),
                    ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
