import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:sliceit/screens/split_bill_detail_screen.dart';
import 'package:sliceit/utils/colors.dart';

class SplitHistoryScreen extends StatefulWidget {
  const SplitHistoryScreen({super.key});

  @override
  State<SplitHistoryScreen> createState() => _SplitHistoryScreenState();
}

class _SplitHistoryScreenState extends State<SplitHistoryScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  int _limit = 20;
  bool _hasMore = true;
  int _loadedCount = 0;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && _loadedCount == _limit) {
        setState(() {
          _limit += 20;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserEmail = _auth.currentUser?.email;
    if (currentUserEmail == null) {
      return const Center(
        child: Text("Please log in to view your split history."),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Bill History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('split_bills')
            .where('participants', arrayContains: currentUserEmail)
            .orderBy('createdAt', descending: true)
            .limit(_limit)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _loadedCount == 0) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint("Firestore Error in SplitHistoryScreen: ${snapshot.error}");
            return const Center(child: Text('Error loading split bills. Check logs for details.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No split bills found.'));
          }

          final docs = snapshot.data!.docs;
          _loadedCount = docs.length;
          _hasMore = _loadedCount >= _limit;

          return ListView.builder(
            controller: _scrollController,
            itemCount: docs.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == docs.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryNavy),
                      ),
                    ),
                  ),
                );
              }
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              // Safely extract data
              final title = data['title'] as String? ?? 'Untitled';
              final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
              final participants = (data['participants'] as List?)?.cast<String>() ?? [];
              final paidStatus = (data['paidStatus'] as Map?)?.cast<String, bool>() ?? {};
              final createdAt = data['createdAt'] as Timestamp?;
              final formattedDate = createdAt != null ? DateFormat('MMM d, yyyy').format(createdAt.toDate()) : '';
              final splitType = data['splitType'] as String? ?? 'equal';
              final amounts = (data['amounts'] as Map?)?.cast<String, num>() ?? {};

              double amountOwed = 0;
              if (splitType.contains('unequal')) {
                amountOwed = (amounts[currentUserEmail] ?? 0).toDouble();
              } else {
                amountOwed = participants.isNotEmpty ? totalAmount / participants.length : 0;
              }

              final isPaid = paidStatus[currentUserEmail] ?? false;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Icon(
                    isPaid ? Icons.check_circle : Icons.cancel,
                    color: isPaid ? AppColors.successGreen : AppColors.errorRed,
                  ),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Your share: ₹${amountOwed.toStringAsFixed(2)} • $formattedDate'),
                  trailing: Text(
                    isPaid ? "Paid" : "Unpaid", 
                    style: TextStyle(color: isPaid ? AppColors.successGreen : AppColors.errorRed, fontWeight: FontWeight.bold)
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SplitBillDetailScreen(splitId: doc.id)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
