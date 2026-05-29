import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../utils/colors.dart';
import '../utils/text_styles.dart';
import '../utils/app_spacing.dart';
import '../widgets/modern_card.dart';
import '../widgets/mesh_background.dart';

enum AnalyticsRange { week, month, year, all }

// Separate widget to isolate line chart touch state
class _LineChartTouchState extends StatefulWidget {
  final List<Map<String, dynamic>> trendData;
  final List<FlSpot> spots;

  const _LineChartTouchState({
    required this.trendData,
    required this.spots,
  });

  @override
  State<_LineChartTouchState> createState() => _LineChartTouchStateState();
}

class _LineChartTouchStateState extends State<_LineChartTouchState> {
  double? _selectedAmount;
  String? _selectedDateLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ModernCard(
      padding: const EdgeInsets.all(20),
      color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spending Trend',
                style: AppTextStyles.h3.copyWith(
                  color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_selectedAmount != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${_selectedAmount!.toStringAsFixed(0)}',
                      style: AppTextStyles.bodyL.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                      ),
                    ),
                    Text(
                      _selectedDateLabel ?? '',
                      style: AppTextStyles.label.copyWith(
                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 24),
          RepaintBoundary(
            child: SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1000,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: (isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder)
                            .withValues(alpha: 0.5),
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
                          if (index >= 0 && index < widget.trendData.length) {
                            if (widget.trendData.length > 7 && index % (widget.trendData.length ~/ 5) != 0) {
                              return const SizedBox.shrink();
                            }

                            final key = widget.trendData[index]['key'] as String;
                            String label = key;
                            if (key.contains('-') && key.length > 7) {
                              try {
                                final date = DateTime.parse(key);
                                label = DateFormat('d/M').format(date);
                              } catch (_) {}
                            } else if (key.length == 7) {
                              try {
                                final date = DateFormat('yyyy-MM').parse(key);
                                label = DateFormat('MMM').format(date);
                              } catch (_) {}
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                label,
                                style: AppTextStyles.label.copyWith(
                                  color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                  fontSize: 10,
                                ),
                              ),
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
                  maxX: widget.trendData.length.toDouble() - 1,
                  minY: 0,
                  lineBarsData: [
                    LineChartBarData(
                      spots: widget.spots,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: AppColors.secondaryAccent,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.secondaryAccent.withValues(alpha: 0.25),
                            AppColors.secondaryAccent.withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((_) => null).toList();
                      },
                    ),
                    handleBuiltInTouches: true,
                    touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                      if (touchResponse != null &&
                          touchResponse.lineBarSpots != null &&
                          touchResponse.lineBarSpots!.isNotEmpty) {
                        final spot = touchResponse.lineBarSpots![0];
                        final index = spot.x.toInt();
                        if (index >= 0 && index < widget.trendData.length) {
                          setState(() {
                            _selectedAmount = spot.y;
                            final key = widget.trendData[index]['key'] as String;
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
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Separate widget for pie chart touch state
class _PieChartTouchState extends StatefulWidget {
  final Map<String, double> categoryData;
  final double totalSpending;
  final Color Function(String) getCategoryColor;
  final IconData Function(String) getCategoryIcon;
  final List<MapEntry<String, double>> sortedCategories;

  const _PieChartTouchState({
    required this.categoryData,
    required this.totalSpending,
    required this.getCategoryColor,
    required this.getCategoryIcon,
    required this.sortedCategories,
  });

  @override
  State<_PieChartTouchState> createState() => _PieChartTouchStateState();
}

class _PieChartTouchStateState extends State<_PieChartTouchState> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ModernCard(
      padding: const EdgeInsets.all(20),
      color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Breakdown',
            style: AppTextStyles.h3.copyWith(
              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
              fontWeight: FontWeight.bold,
            ),
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
                sections: widget.sortedCategories.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  final isTouched = index == _touchedIndex;
                  final fontSize = isTouched ? 18.0 : 12.0;
                  final radius = isTouched ? 60.0 : 50.0;
                  final percentage = widget.totalSpending > 0 ? (data.value / widget.totalSpending * 100) : 0.0;

                  return PieChartSectionData(
                    color: widget.getCategoryColor(data.key),
                    value: data.value,
                    title: percentage > 5 ? '${percentage.toStringAsFixed(0)}%' : '',
                    radius: radius,
                    titleStyle: AppTextStyles.label.copyWith(
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
          ...widget.sortedCategories.map((entry) {
            final percentage = widget.totalSpending > 0 ? (entry.value / widget.totalSpending * 100) : 0.0;
            final catColor = widget.getCategoryColor(entry.key);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Icon(
                      widget.getCategoryIcon(entry.key),
                      size: 20,
                      color: catColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: AppTextStyles.bodyL.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children: [
                                Container(
                                  height: 6,
                                  width: constraints.maxWidth,
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                                  ),
                                ),
                                Container(
                                  height: 6,
                                  width: constraints.maxWidth * (percentage / 100).clamp(0.0, 1.0),
                                  decoration: BoxDecoration(
                                    color: catColor,
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${entry.value.toStringAsFixed(0)}',
                        style: AppTextStyles.bodyL.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: AppTextStyles.label.copyWith(
                          color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

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

  // Cached computed data
  List<FlSpot>? _cachedSpots;
  List<MapEntry<String, double>>? _cachedSortedCategories;

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
    });

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final uid = currentUser.uid;
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
      // Run all three reads in parallel
      final userDocFuture = _firestore.collection('users').doc(uid).get();
      final currentPeriodFuture = _firestore
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('date', descending: true)
          .get();
      final previousPeriodFuture = _selectedRange != AnalyticsRange.all
          ? _firestore
              .collection('users')
              .doc(uid)
              .collection('expenses')
              .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(previousStartDate))
              .where('date', isLessThan: Timestamp.fromDate(startDate))
              .get()
          : Future.value(null);

      final results = await Future.wait([userDocFuture, currentPeriodFuture, previousPeriodFuture]);
      final userDoc = results[0] as DocumentSnapshot;
      final snapshot = results[1] as QuerySnapshot;
      final prevSnapshot = results[2] as QuerySnapshot?;

      final userData = userDoc.data() as Map<String, dynamic>?;
      _monthlyBudget = ((userData)?['monthlyBudget'] as num?)?.toDouble() ?? 0.0;

      double prevTotal = 0;
      if (prevSnapshot != null) {
        for (var doc in prevSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          prevTotal += ((data)?['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }

      final categoryData = <String, double>{};
      final trendDataMap = <String, double>{};
      double totalSpending = 0;
      final topExpensesList = <DocumentSnapshot>[];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final category = data['category'] as String? ?? 'Uncategorized';
        final amount = ((data['amount'] as num?) ?? 0.0).toDouble();
        final timestamp = data['date'] as Timestamp?;
        final date = timestamp?.toDate() ?? DateTime.now();

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
        // Compute cached data before setState
        final trendList = trendDataMap.entries
            .map((e) => {'key': e.key, 'amount': e.value})
            .toList()
          ..sort((a, b) => (a['key'] as String).compareTo(b['key'] as String));

        final cachedSpots = trendList.asMap().entries.map((entry) {
          return FlSpot(entry.key.toDouble(), entry.value['amount'] as double);
        }).toList();

        final sortedCats = categoryData.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

        setState(() {
          _categoryData = categoryData;
          _trendData = trendList;
          _cachedSpots = cachedSpots;
          _cachedSortedCategories = sortedCats;
          _totalSpending = totalSpending;
          _previousTotalSpending = prevTotal;

          // Sort top expenses by amount desc safely
          _topExpenses = topExpensesList;
          _topExpenses.sort((a, b) {
            final aAmt = (((a.data() as Map<String, dynamic>?)?['amount'] as num?) ?? 0.0).toDouble();
            final bAmt = (((b.data() as Map<String, dynamic>?)?['amount'] as num?) ?? 0.0).toDouble();
            return bAmt.compareTo(aAmt);
          });
          if (_topExpenses.length > 5) _topExpenses = _topExpenses.sublist(0, 5);

          // Metrics Calculation
          if (daysPassed > 0) {
            _dailyAverage = totalSpending / daysPassed;
            if (_selectedRange == AnalyticsRange.month &&
                now.month == startDate.month &&
                now.year == startDate.year) {
              _projectedSpend = _dailyAverage * totalDaysInPeriod;
            } else {
              _projectedSpend = 0;
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
      case 'food':
        return Icons.fastfood_rounded;
      case 'transport':
        return Icons.directions_car_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'bills':
        return Icons.receipt_long_rounded;
      case 'entertainment':
        return Icons.movie_creation_rounded;
      case 'health':
        return Icons.medical_services_rounded;
      case 'education':
        return Icons.school_rounded;
      case 'groceries':
        return Icons.local_grocery_store_rounded;
      case 'travel':
        return Icons.flight_takeoff_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return const Color(0xFFF59E0B); // Amber
      case 'transport':
        return const Color(0xFF3B82F6); // Blue
      case 'shopping':
        return const Color(0xFF8B5CF6); // Violet
      case 'bills':
        return const Color(0xFFEF4444); // Red
      case 'entertainment':
        return const Color(0xFFEC4899); // Pink
      case 'health':
        return const Color(0xFF10B981); // Emerald
      case 'education':
        return const Color(0xFF6366F1); // Indigo
      case 'groceries':
        return const Color(0xFF84CC16); // Lime
      case 'travel':
        return const Color(0xFF06B6D4); // Cyan
      default:
        return const Color(0xFFEAB308);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 120.0,
                floating: true,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                  title: Text(
                    'Analytics',
                    style: AppTextStyles.h2.copyWith(
                      color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  background: const SizedBox.shrink(),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(56),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      border: Border.all(
                        color: isDark ? AppColors.darkSurfaceBorder : AppColors.lightSurfaceBorder,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                        color: AppColors.primaryAccent,
                      ),
                      labelColor: Colors.white,
                      labelStyle: AppTextStyles.button.copyWith(fontWeight: FontWeight.bold),
                      unselectedLabelColor: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                      unselectedLabelStyle: AppTextStyles.button.copyWith(fontWeight: FontWeight.normal),
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
                  color: AppColors.primaryAccent,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSummaryCard(isDark).animate().fade().scaleXY(begin: 0.95, end: 1.0),
                        const SizedBox(height: 16),
                        _buildMetricsRow(isDark).animate().fade(delay: 50.ms).slideY(begin: 0.05),
                        const SizedBox(height: 24),
                        if (_cachedSpots != null && _cachedSpots!.isNotEmpty)
                          _LineChartTouchState(
                            trendData: _trendData,
                            spots: _cachedSpots!,
                          ).animate().fade(delay: 100.ms).slideY(begin: 0.05),
                        if (_cachedSpots != null && _cachedSpots!.isNotEmpty) const SizedBox(height: 24),
                        if (_cachedSortedCategories != null && _categoryData.isNotEmpty)
                          _PieChartTouchState(
                            categoryData: _categoryData,
                            totalSpending: _totalSpending,
                            getCategoryColor: _getCategoryColor,
                            getCategoryIcon: _getCategoryIcon,
                            sortedCategories: _cachedSortedCategories!,
                          ).animate().fade(delay: 150.ms).slideY(begin: 0.05),
                        if (_cachedSortedCategories != null && _categoryData.isNotEmpty) const SizedBox(height: 24),
                        _buildTopExpenses(isDark).animate().fade(delay: 200.ms).slideY(begin: 0.05),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    double percentageChange = 0;
    if (_previousTotalSpending > 0) {
      percentageChange = ((_totalSpending - _previousTotalSpending) / _previousTotalSpending) * 100;
    }

    return ModernCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Spent',
                style: AppTextStyles.label.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
              if (_selectedRange != AnalyticsRange.all && _previousTotalSpending > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        percentageChange > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${percentageChange.abs().toStringAsFixed(1)}%',
                        style: AppTextStyles.label.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₹${_totalSpending.toStringAsFixed(2)}',
            style: AppTextStyles.h1.copyWith(
              color: Colors.white,
              fontSize: 36,
            ),
          ),
          if (_selectedRange == AnalyticsRange.month && _monthlyBudget > 0) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly Budget',
                  style: AppTextStyles.label.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                Text(
                  '₹${_monthlyBudget.toStringAsFixed(0)}',
                  style: AppTextStyles.label.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(
                      height: 8,
                      width: constraints.maxWidth,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      ),
                    ),
                    Container(
                      height: 8,
                      width: constraints.maxWidth * (_totalSpending / _monthlyBudget).clamp(0.0, 1.0),
                      decoration: BoxDecoration(
                        color: _totalSpending > _monthlyBudget ? AppColors.error : AppColors.secondaryAccent,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(_totalSpending / _monthlyBudget * 100).toStringAsFixed(0)}% used',
                style: AppTextStyles.label.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricsRow(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: 'Daily Average',
            value: '₹${_dailyAverage.toStringAsFixed(0)}',
            icon: Icons.calendar_today_rounded,
            color: AppColors.secondaryAccent,
            isDark: isDark,
          ),
        ),
        if (_projectedSpend > 0) ...[
          const SizedBox(width: 16),
          Expanded(
            child: _buildMetricTile(
              title: 'Projected',
              value: '₹${_projectedSpend.toStringAsFixed(0)}',
              icon: Icons.trending_up_rounded,
              color: AppColors.warning,
              isDark: isDark,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return ModernCard(
      padding: const EdgeInsets.all(16),
      color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.h3.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTextStyles.label.copyWith(
              color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopExpenses(bool isDark) {
    if (_topExpenses.isEmpty) return const SizedBox.shrink();

    return ModernCard(
      padding: const EdgeInsets.all(20),
      color: isDark ? AppColors.darkSurface1 : AppColors.lightSurface1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Expenses',
            style: AppTextStyles.h3.copyWith(
              color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._topExpenses.map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return const SizedBox.shrink();

            final timestamp = data['date'] as Timestamp?;
            final date = timestamp?.toDate() ?? DateTime.now();
            final category = data['category'] as String? ?? 'Uncategorized';
            final catColor = _getCategoryColor(category);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getCategoryIcon(category), color: catColor, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['title'] ?? 'Expense',
                          style: AppTextStyles.bodyL.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('MMM d').format(date),
                          style: AppTextStyles.label.copyWith(
                            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${(((data['amount'] as num?) ?? 0.0)).toStringAsFixed(2)}',
                    style: AppTextStyles.bodyL.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.secondaryAccent : AppColors.primaryAccent,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
