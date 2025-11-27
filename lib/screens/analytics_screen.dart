import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../utils/colors.dart';

enum AnalyticsRange { week, month, year, all }

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;
  AnalyticsRange _selectedRange = AnalyticsRange.month;
  
  Map<String, double> _categoryData = {};
  List<Map<String, dynamic>> _trendData = [];
  List<DocumentSnapshot> _topExpenses = [];
  
  double _totalSpending = 0.0;
  double _previousTotalSpending = 0.0;
  double _monthlyBudget = 0.0;
  double _dailyAverage = 0.0;
  double _projectedSpend = 0.0;
  
  bool _isLoading = true;
  int _touchedIndex = -1;
  
  // Interactive chart state
  double? _selectedAmount;
  String? _selectedDateLabel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 1);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedRange = AnalyticsRange.values[_tabController.index];
          _fetchData();
        });
      }
    });
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _selectedAmount = null;
      _selectedDateLabel = null;
    });

    final uid = _auth.currentUser!.uid;
    final now = DateTime.now();
    DateTime startDate;
    DateTime previousStartDate;
    
    // Logic for forecasting
    int daysPassed = 0;
    int totalDaysInPeriod = 0;

    switch (_selectedRange) {
      case AnalyticsRange.week:
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day); // Start of day
        previousStartDate = startDate.subtract(const Duration(days: 7));
        daysPassed = now.difference(startDate).inDays + 1;
        totalDaysInPeriod = 7;
        break;
      case AnalyticsRange.month:
        startDate = DateTime(now.year, now.month, 1);
        previousStartDate = DateTime(now.year, now.month - 1, 1);
        daysPassed = now.day;
        totalDaysInPeriod = DateTime(now.year, now.month + 1, 0).day;
        break;
      case AnalyticsRange.year:
        startDate = DateTime(now.year, 1, 1);
        previousStartDate = DateTime(now.year - 1, 1, 1);
        daysPassed = now.difference(startDate).inDays + 1;
        totalDaysInPeriod = 365 + (now.year % 4 == 0 ? 1 : 0); // Leap year approx
        break;
      case AnalyticsRange.all:
        startDate = DateTime(2000);
        previousStartDate = DateTime(1900);
        daysPassed = 1; // Avoid division by zero
        totalDaysInPeriod = 1;
        break;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      _monthlyBudget = (userDoc.data()?['monthlyBudget'] ?? 0.0).toDouble();

      // Fetch Current Period Data
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('date', descending: true)
          .get();

      // Fetch Previous Period Data (for comparison)
      double prevTotal = 0;
      if (_selectedRange != AnalyticsRange.all) {
        final prevSnapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('expenses')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(previousStartDate))
            .where('date', isLessThan: Timestamp.fromDate(startDate))
            .get();
        
        for (var doc in prevSnapshot.docs) {
          prevTotal += (doc.data()['amount'] as num).toDouble();
        }
      }

      final categoryData = <String, double>{};
      final trendDataMap = <String, double>{};
      double totalSpending = 0;
      final topExpensesList = <DocumentSnapshot>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final category = data['category'] as String? ?? 'Uncategorized';
        final amount = (data['amount'] as num).toDouble();
        final date = (data['date'] as Timestamp).toDate();
        
        // Category aggregation
        categoryData.update(category, (value) => value + amount, ifAbsent: () => amount);
        
        // Trend aggregation
        String key;
        if (_selectedRange == AnalyticsRange.year || _selectedRange == AnalyticsRange.all) {
           key = DateFormat('yyyy-MM').format(date);
        } else {
           key = DateFormat('yyyy-MM-dd').format(date);
        }
        trendDataMap.update(key, (value) => value + amount, ifAbsent: () => amount);
        
        totalSpending += amount;
        
        if (topExpensesList.length < 5) {
          topExpensesList.add(doc);
        }
      }

      if (mounted) {
        setState(() {
          _categoryData = categoryData;
          _trendData = trendDataMap.entries
              .map((e) => {'key': e.key, 'amount': e.value})
              .toList()
            ..sort((a, b) => (a['key'] as String).compareTo(b['key'] as String));
          _totalSpending = totalSpending;
          _previousTotalSpending = prevTotal;
          
          // Sort top expenses by amount desc
          _topExpenses = topExpensesList;
          _topExpenses.sort((a, b) => (b.data() as Map)['amount'].compareTo((a.data() as Map)['amount']));
          if (_topExpenses.length > 5) _topExpenses = _topExpenses.sublist(0, 5);
          
          // Metrics Calculation
          if (daysPassed > 0) {
            _dailyAverage = totalSpending / daysPassed;
            if (_selectedRange == AnalyticsRange.month && now.month == startDate.month && now.year == startDate.year) {
               _projectedSpend = _dailyAverage * totalDaysInPeriod;
            } else {
               _projectedSpend = 0; // Only forecast for current month
            }
          } else {
            _dailyAverage = 0;
            _projectedSpend = 0;
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching analytics data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food': return Icons.fastfood_rounded;
      case 'transport': return Icons.directions_car_rounded;
      case 'shopping': return Icons.shopping_bag_rounded;
      case 'bills': return Icons.receipt_long_rounded;
      case 'entertainment': return Icons.movie_creation_rounded;
      case 'health': return Icons.medical_services_rounded;
      case 'education': return Icons.school_rounded;
      case 'groceries': return Icons.local_grocery_store_rounded;
      case 'travel': return Icons.flight_takeoff_rounded;
      default: return Icons.category_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food': return Colors.orange;
      case 'transport': return Colors.blue;
      case 'shopping': return Colors.purple;
      case 'bills': return Colors.red;
      case 'entertainment': return Colors.pink;
      case 'health': return Colors.teal;
      case 'education': return Colors.indigo;
      case 'groceries': return Colors.green;
      case 'travel': return Colors.cyan;
      default: return Colors.primaries[category.hashCode % Colors.primaries.length];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 120.0,
              floating: true,
              pinned: true,
              backgroundColor: AppColors.backgroundLight,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                title: const Text(
                  'Analytics',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
                background: Container(color: AppColors.backgroundLight),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      color: AppColors.primaryNavy,
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Week'),
                      Tab(text: 'Month'),
                      Tab(text: 'Year'),
                      Tab(text: 'All'),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 16),
                      _buildMetricsRow(),
                      const SizedBox(height: 24),
                      _buildSpendingTrendChart(),
                      const SizedBox(height: 24),
                      _buildCategoryBreakdown(),
                      const SizedBox(height: 24),
                      _buildTopExpenses(),
                      const SizedBox(height: 40), // Bottom padding
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    double percentageChange = 0;
    if (_previousTotalSpending > 0) {
      percentageChange = ((_totalSpending - _previousTotalSpending) / _previousTotalSpending) * 100;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryNavy, AppColors.primaryNavy.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.primaryNavy.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Spent',
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.w500),
              ),
              if (_selectedRange != AnalyticsRange.all && _previousTotalSpending > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        percentageChange > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${percentageChange.abs().toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₹${_totalSpending.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          if (_selectedRange == AnalyticsRange.month && _monthlyBudget > 0) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly Budget',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                ),
                Text(
                  '₹${_monthlyBudget.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (_totalSpending / _monthlyBudget).clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: _totalSpending > _monthlyBudget ? Colors.redAccent : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
             Align(
               alignment: Alignment.centerRight,
               child: Text(
                  '${(_totalSpending / _monthlyBudget * 100).toStringAsFixed(0)}% used',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11),
                ),
             ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: 'Daily Average',
            value: '₹${_dailyAverage.toStringAsFixed(0)}',
            icon: Icons.calendar_today_rounded,
            color: Colors.blueAccent,
          ),
        ),
        if (_projectedSpend > 0) ...[
          const SizedBox(width: 16),
          Expanded(
            child: _buildMetricTile(
              title: 'Projected',
              value: '₹${_projectedSpend.toStringAsFixed(0)}',
              icon: Icons.trending_up_rounded,
              color: Colors.orangeAccent,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetricTile({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingTrendChart() {
    if (_trendData.isEmpty) return const SizedBox.shrink();

    // Prepare spots for LineChart
    final spots = _trendData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value['amount']);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Spending Trend',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (_selectedAmount != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${_selectedAmount!.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                    ),
                    Text(
                      _selectedDateLabel ?? '',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1000, // Adjust based on data?
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.1),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _trendData.length) {
                           // Show fewer labels if too many data points
                          if (_trendData.length > 7 && index % (_trendData.length ~/ 5) != 0) return const SizedBox.shrink();
                          
                          final key = _trendData[index]['key'] as String;
                          String label = key;
                          if (key.contains('-') && key.length > 7) {
                             // Assume YYYY-MM-DD
                             try {
                               final date = DateTime.parse(key);
                               label = DateFormat('d/M').format(date);
                             } catch (_) {}
                          } else if (key.length == 7) {
                             // YYYY-MM
                             try {
                               final date = DateFormat('yyyy-MM').parse(key);
                               label = DateFormat('MMM').format(date);
                             } catch (_) {}
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: _trendData.length.toDouble() - 1,
                minY: 0,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppColors.secondaryTeal,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.secondaryTeal.withOpacity(0.2),
                          AppColors.secondaryTeal.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Colors.blueGrey,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                       return touchedBarSpots.map((_) => null).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                  touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                    if (touchResponse != null && touchResponse.lineBarSpots != null && touchResponse.lineBarSpots!.isNotEmpty) {
                      final spot = touchResponse.lineBarSpots![0];
                      final index = spot.x.toInt();
                      if (index >= 0 && index < _trendData.length) {
                        setState(() {
                          _selectedAmount = spot.y;
                          final key = _trendData[index]['key'] as String;
                          // Format date nicely
                           try {
                             if (key.length > 7) {
                               _selectedDateLabel = DateFormat('MMM d, yyyy').format(DateTime.parse(key));
                             } else {
                               _selectedDateLabel = DateFormat('MMMM yyyy').format(DateFormat('yyyy-MM').parse(key));
                             }
                           } catch (_) {
                             _selectedDateLabel = key;
                           }
                        });
                      }
                    } else if (event is FlTapUpEvent || event is FlPanEndEvent) {
                       // Optional: Clear selection on release
                       // setState(() {
                       //   _selectedAmount = null;
                       //   _selectedDateLabel = null;
                       // });
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    if (_categoryData.isEmpty) return const SizedBox.shrink();

    final sortedCategories = _categoryData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category Breakdown',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _touchedIndex = -1;
                        return;
                      }
                      _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: sortedCategories.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  final isTouched = index == _touchedIndex;
                  final fontSize = isTouched ? 20.0 : 14.0;
                  final radius = isTouched ? 60.0 : 50.0;
                  final percentage = (data.value / _totalSpending * 100);

                  return PieChartSectionData(
                    color: _getCategoryColor(data.key),
                    value: data.value,
                    title: percentage > 5 ? '${percentage.toStringAsFixed(0)}%' : '',
                    radius: radius,
                    titleStyle: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ...sortedCategories.map((entry) {
            final percentage = (entry.value / _totalSpending * 100);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(entry.key).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_getCategoryIcon(entry.key), size: 18, color: _getCategoryColor(entry.key)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Stack(
                          children: [
                            Container(
                              height: 4,
                              width: 100,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Container(
                              height: 4,
                              width: 100 * (percentage / 100),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(entry.key),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${entry.value.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTopExpenses() {
    if (_topExpenses.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Expenses',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ..._topExpenses.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final date = (data['date'] as Timestamp).toDate();
            final category = data['category'] as String? ?? 'Uncategorized';
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primaryNavy.withOpacity(0.1),
                    child: Icon(_getCategoryIcon(category), color: AppColors.primaryNavy, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['title'] ?? 'Expense', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        Text(DateFormat('MMM d').format(date), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                  Text(
                    '₹${(data['amount'] as num).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
