import 'dart:math';

class DebtSimplifier {
  static List<Settlement> simplifyDebts(List<Map<String, dynamic>> expenses) {
    final Map<String, double> balances = {};

    // 1. Calculate Net Balances
    for (var expense in expenses) {
      final double amount = (expense['amount'] as num).toDouble();
      final String paidBy = expense['paidBy'];
      final List<String> participants = (expense['participants'] as List).cast<String>();

      if (participants.isEmpty) continue;

      // Creator paid the full amount, so they get +amount "credit" initially
      // But actually, it's easier to think: 
      // They paid X. They are owed X (conceptually).
      // Each participant owes X/N.
      // So Net Effect on Payer: +Amount - (Amount/N) [their share]
      // Net Effect on Participant: -(Amount/N)
      
      // Let's do it simply:
      // Payer pays Amount. Balance += Amount.
      // Everyone (including payer if participating) "consumes" Amount/N. Balance -= Amount/N.
      
      balances.update(paidBy, (value) => value + amount, ifAbsent: () => amount);

      final double splitAmount = amount / participants.length;
      for (var participant in participants) {
        balances.update(participant, (value) => value - splitAmount, ifAbsent: () => -splitAmount);
      }
    }

    // 2. Separate into Debtors and Creditors
    final List<MapEntry<String, double>> debtors = [];
    final List<MapEntry<String, double>> creditors = [];

    balances.forEach((user, amount) {
      // Use a small epsilon for float comparison
      if (amount < -0.01) {
        debtors.add(MapEntry(user, amount));
      } else if (amount > 0.01) {
        creditors.add(MapEntry(user, amount));
      }
    });

    // Sort to optimize (optional, but helps greedy approach)
    debtors.sort((a, b) => a.value.compareTo(b.value)); // Ascending (most negative first)
    creditors.sort((a, b) => b.value.compareTo(a.value)); // Descending (most positive first)

    final List<Settlement> settlements = [];

    // 3. Greedy Matching
    int debtorIndex = 0;
    int creditorIndex = 0;

    while (debtorIndex < debtors.length && creditorIndex < creditors.length) {
      final debtor = debtors[debtorIndex];
      final creditor = creditors[creditorIndex];

      final double amount = min(debtor.value.abs(), creditor.value);
      
      // Record settlement
      settlements.add(Settlement(
        fromUser: debtor.key,
        toUser: creditor.key,
        amount: amount,
      ));

      // Update remaining balances
      final double remainingDebt = debtor.value + amount;
      final double remainingCredit = creditor.value - amount;

      // Update entries in list (conceptually)
      // If debt is fully paid (approx 0), move to next debtor
      if (remainingDebt.abs() < 0.01) {
        debtorIndex++;
      } else {
        debtors[debtorIndex] = MapEntry(debtor.key, remainingDebt);
      }

      // If credit is fully used (approx 0), move to next creditor
      if (remainingCredit.abs() < 0.01) {
        creditorIndex++;
      } else {
        creditors[creditorIndex] = MapEntry(creditor.key, remainingCredit);
      }
    }

    return settlements;
  }
}

class Settlement {
  final String fromUser;
  final String toUser;
  final double amount;

  Settlement({required this.fromUser, required this.toUser, required this.amount});
}
