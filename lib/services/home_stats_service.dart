import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<Map<String, double>> getHomeStats() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value({'spent': 0.0, 'owe': 0.0, 'owed': 0.0});
    }

    // Combine streams from Groups and Split Bills
    // This is complex because we need to listen to *all* expenses in *all* groups.
    // For a scalable solution, we'd use Cloud Functions to maintain a 'stats' document on the user.
    // For this implementation, we will fetch snapshots.
    
    // Actually, listening to a query of all groups, then for each group listenting to expenses is too many listeners.
    // We will do a one-time fetch for "Total Spent" (or simplified stream) and "Balances".
    // Better: For "Total Balance" logic, we might need to iterate.
    
    // Let's implement a simpler version:
    // 1. Fetch all groups user is in.
    // 2. Fetch all expenses in those groups.
    // 3. Calculate metrics.
    // This is read-heavy.
    
    // Alternative: Just listen to `users/{uid}` if we updated stats there. (We didn't).
    
    // Let's use a Stream that emits periodically or on refresh? 
    // Or just a Future for now? User asked for "real money spent data".
    // I will use a Stream that combines latest values.
    
    return _firestore
        .collection('groups')
        .where('members', arrayContains: user.uid)
        .snapshots()
        .asyncMap((groupsSnapshot) async {
          double totalSpent = 0.0;
          double youOwe = 0.0; // Net negative
          double owedToYou = 0.0; // Net positive

          // 1. Group Expenses
          for (var groupDoc in groupsSnapshot.docs) {
             final expensesSnapshot = await groupDoc.reference.collection('expenses').get();
             for (var expenseDoc in expensesSnapshot.docs) {
               final data = expenseDoc.data();
               final amount = (data['amount'] as num).toDouble();
               final paidBy = data['paidBy'] as String;
               final participants = (data['participants'] as List).cast<String>();
               
               if (participants.isEmpty) continue;
               final splitAmount = amount / participants.length;
               
               // Spent: My share of any expense
               if (participants.contains(user.uid)) {
                 totalSpent += splitAmount;
               }
               
               // Debts/Credits
               if (paidBy == user.uid) {
                 // I paid. Others owe me.
                 // Owed to me = Amount - My Share (if I participated)
                 // If I am a participant, I paid for myself (0 net) + others (positive net)
                 // If I am NOT a participant, I paid for others (positive net)
                 if (participants.contains(user.uid)) {
                   owedToYou += (amount - splitAmount);
                 } else {
                   owedToYou += amount;
                 }
               } else if (participants.contains(user.uid)) {
                 // Someone else paid, and I am a participant. I Owe.
                 youOwe += splitAmount;
               }
             }
          }
          
          // 2. Split Bills (Direct splits)
          // ... (Existing logic for Split Bills if separate collection)
          // Assuming Split Bills are similar structure
          final splitBillsSnapshot = await _firestore
              .collection('split_bills')
              .where('participants', arrayContains: user.email) // Note: using email for split bills?
              .get();
              
          // Note: SplitBillsScreen uses email for participants array.
          // We need user email.
          final userEmail = user.email;
          if (userEmail != null) {
            for (var doc in splitBillsSnapshot.docs) {
              final data = doc.data();
              final totalAmount = (data['totalAmount'] as num).toDouble();
               final createdBy = data['createdBy'] as String; // Email
               final participants = (data['participants'] as List).cast<String>();
               // Simplified equal split logic from SplitBillsScreen
               final splitAmt = totalAmount / participants.length;
               
               if (createdBy == userEmail) {
                 // I paid/created.
                 owedToYou += (totalAmount - splitAmt);
                 // Assuming I am also a participant? SplitBillsScreen logic implies createdBy is owed.
                 totalSpent += splitAmt;
               } else {
                 // I owe
                 youOwe += splitAmt;
                 totalSpent += splitAmt;
               }
            }
          }

          return {
            'spent': totalSpent,
            'owe': youOwe,
            'owed': owedToYou,
          };
        });
  }
}
