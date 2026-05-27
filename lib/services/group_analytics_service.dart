class GroupAnalytics {
  final Map<String, double> spendingByPerson;
  final Map<String, double> percentageByPerson;
  final double totalSpent;
  final int expenseCount;
  final Map<String, int> countByPerson;

  GroupAnalytics({
    required this.spendingByPerson,
    required this.percentageByPerson,
    required this.totalSpent,
    required this.expenseCount,
    required this.countByPerson,
  });
}

class GroupAnalyticsService {
  static GroupAnalytics calculateGroupAnalytics(
    List<Map<String, dynamic>> expenses,
    List<String> members,
  ) {
    // Initialize maps
    final spendingByPerson = <String, double>{};
    final countByPerson = <String, int>{};

    for (final member in members) {
      spendingByPerson[member] = 0.0;
      countByPerson[member] = 0;
    }

    // Calculate total spending by person
    for (var expense in expenses) {
      final amount = (expense['amount'] as num?)?.toDouble() ?? 0.0;
      final paidBy = expense['paidBy'] as String?;

      if (paidBy != null && spendingByPerson.containsKey(paidBy)) {
        spendingByPerson[paidBy] = spendingByPerson[paidBy]! + amount;
        countByPerson[paidBy] = countByPerson[paidBy]! + 1;
      }
    }

    // Calculate total spent and percentage contribution
    final totalSpent = spendingByPerson.values.fold<double>(0, (a, b) => a + b);

    final percentageByPerson = <String, double>{};
    for (final entry in spendingByPerson.entries) {
      if (totalSpent > 0) {
        percentageByPerson[entry.key] = (entry.value / totalSpent) * 100;
      } else {
        percentageByPerson[entry.key] = 0.0;
      }
    }

    return GroupAnalytics(
      spendingByPerson: spendingByPerson,
      percentageByPerson: percentageByPerson,
      totalSpent: totalSpent,
      expenseCount: expenses.length,
      countByPerson: countByPerson,
    );
  }

  static Map<String, double> calculateAverageExpense(
    List<Map<String, dynamic>> expenses,
    List<String> members,
  ) {
    final averages = <String, double>{};
    final countByPerson = <String, int>{};
    final spendingByPerson = <String, double>{};

    for (final member in members) {
      spendingByPerson[member] = 0.0;
      countByPerson[member] = 0;
    }

    for (var expense in expenses) {
      final amount = (expense['amount'] as num?)?.toDouble() ?? 0.0;
      final paidBy = expense['paidBy'] as String?;

      if (paidBy != null && spendingByPerson.containsKey(paidBy)) {
        spendingByPerson[paidBy] = spendingByPerson[paidBy]! + amount;
        countByPerson[paidBy] = countByPerson[paidBy]! + 1;
      }
    }

    for (final entry in spendingByPerson.entries) {
      if (countByPerson[entry.key]! > 0) {
        averages[entry.key] = entry.value / countByPerson[entry.key]!;
      } else {
        averages[entry.key] = 0.0;
      }
    }

    return averages;
  }

  static Map<String, double> calculateExpenseShare(
    List<Map<String, dynamic>> expenses,
    List<String> members,
  ) {
    final shares = <String, double>{};

    for (final member in members) {
      shares[member] = 0.0;
    }

    for (var expense in expenses) {
      final amount = (expense['amount'] as num?)?.toDouble() ?? 0.0;
      final participants = (expense['participants'] as List?)?.cast<String>() ?? [];

      if (participants.isNotEmpty) {
        final share = amount / participants.length;
        for (final participant in participants) {
          if (shares.containsKey(participant)) {
            shares[participant] = shares[participant]! + share;
          }
        }
      }
    }

    return shares;
  }

  static Map<String, dynamic> getHighestSpender(
    Map<String, double> spendingByPerson,
  ) {
    if (spendingByPerson.isEmpty) {
      return {'name': 'N/A', 'amount': 0.0};
    }

    final entry = spendingByPerson.entries.reduce((a, b) => a.value > b.value ? a : b);
    return {
      'name': entry.key,
      'amount': entry.value,
    };
  }

  static String getTopExpenseTitle(
    List<Map<String, dynamic>> expenses,
  ) {
    if (expenses.isEmpty) return 'N/A';

    var topExpense = expenses[0];
    for (var expense in expenses) {
      if ((expense['amount'] as num?)?.toDouble() ?? 0 >
          (topExpense['amount'] as num?)?.toDouble() ?? 0) {
        topExpense = expense;
      }
    }

    return topExpense['title'] as String? ?? 'Unknown';
  }

  static double getAverageBillAmount(
    List<Map<String, dynamic>> expenses,
  ) {
    if (expenses.isEmpty) return 0.0;

    final total = expenses.fold<double>(0, (sum, exp) => sum + ((exp['amount'] as num?)?.toDouble() ?? 0));
    return total / expenses.length;
  }
}
