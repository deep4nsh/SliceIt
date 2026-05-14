import 'package:cloud_firestore/cloud_firestore.dart';

class Subscription {
  final String id;
  final String title;
  final double amount;
  final String category;
  final String billingCycle;
  final DateTime nextDueDate;
  final List<String> sharedWith;
  final String paidBy;
  final DateTime createdAt;

  Subscription({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.billingCycle,
    required this.nextDueDate,
    required this.sharedWith,
    required this.paidBy,
    required this.createdAt,
  });

  factory Subscription.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parsedNextDueDate = DateTime.now().add(const Duration(days: 30));
    if (map['nextDueDate'] is Timestamp) {
      parsedNextDueDate = (map['nextDueDate'] as Timestamp).toDate();
    } else if (map['nextDueDate'] is String) {
      parsedNextDueDate = DateTime.tryParse(map['nextDueDate'] as String) ?? parsedNextDueDate;
    }

    DateTime parsedCreatedAt = DateTime.now();
    if (map['createdAt'] is Timestamp) {
      parsedCreatedAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      parsedCreatedAt = DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now();
    }

    return Subscription(
      id: documentId,
      title: map['title'] as String? ?? 'Subscription',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] as String? ?? 'Entertainment',
      billingCycle: map['billingCycle'] as String? ?? 'monthly',
      nextDueDate: parsedNextDueDate,
      sharedWith: (map['sharedWith'] as List?)?.cast<String>() ?? [],
      paidBy: map['paidBy'] as String? ?? '',
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'category': category,
      'billingCycle': billingCycle,
      'nextDueDate': Timestamp.fromDate(nextDueDate),
      'sharedWith': sharedWith,
      'paidBy': paidBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Subscription copyWith({
    String? id,
    String? title,
    double? amount,
    String? category,
    String? billingCycle,
    DateTime? nextDueDate,
    List<String>? sharedWith,
    String? paidBy,
    DateTime? createdAt,
  }) {
    return Subscription(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      billingCycle: billingCycle ?? this.billingCycle,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      sharedWith: sharedWith ?? this.sharedWith,
      paidBy: paidBy ?? this.paidBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
