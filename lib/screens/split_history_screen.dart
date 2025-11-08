import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:sliceit/screens/split_bill_detail_screen.dart';

class SplitHistoryScreen extends StatefulWidget {
  const SplitHistoryScreen({super.key});

  @override
  State<SplitHistoryScreen> createState() => _SplitHistoryScreenState();
}

class _SplitHistoryScreenState extends State<SplitHistoryScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late final String _currentUserEmail;

  @override
  void initState() {
    super.initState();
    _currentUserEmail = _auth.currentUser!.email!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Split Bill History')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('split_bills')
            .where('participants', arrayContains: _currentUserEmail)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading split bills.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No split bills found.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] as String;
              final totalAmount = (data['totalAmount'] as num).toDouble();
              final createdAt = (data['createdAt'] as Timestamp).toDate();
              final formattedDate = DateFormat('MMM d, yyyy').format(createdAt);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Created on $formattedDate'),
                  trailing: Text('₹${totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
