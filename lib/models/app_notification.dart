import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String type; // 'expense_added' | 'group_invite' | 'settlement' | 'split_bill' | 'payment_reminder'
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? relatedId; // groupId or splitBillId
  final String? actionUserName;
  final double? amount;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.relatedId,
    this.actionUserName,
    this.amount,
  });

  factory AppNotification.fromFirestore(
    DocumentSnapshot doc,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      type: data['type'] as String? ?? 'general',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      isRead: data['isRead'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      relatedId: data['relatedId'] as String?,
      actionUserName: data['actionUserName'] as String?,
      amount: (data['amount'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'title': title,
      'body': body,
      'isRead': isRead,
      'createdAt': FieldValue.serverTimestamp(),
      'relatedId': relatedId,
      'actionUserName': actionUserName,
      'amount': amount,
    };
  }
}
