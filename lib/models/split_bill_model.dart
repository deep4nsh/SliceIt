import 'package:cloud_firestore/cloud_firestore.dart';
import 'split_item_model.dart';

class SplitBill {
  final String id;
  final String title;
  final double totalAmount;
  final String createdBy;
  final List<String> participants;
  final Map<String, bool> paidStatus;
  final String splitType;
  final Map<String, double> amounts;
  final DateTime createdAt;
  final String? receiptUrl;
  final List<SplitItem>? items;
  final double? taxAmount;
  final double? tipAmount;
  final bool isItemized;

  SplitBill({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.createdBy,
    required this.participants,
    required this.paidStatus,
    required this.splitType,
    required this.amounts,
    required this.createdAt,
    this.receiptUrl,
    this.items,
    this.taxAmount,
    this.tipAmount,
    this.isItemized = false,
  });

  factory SplitBill.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parsedDate = DateTime.now();
    if (map['createdAt'] is Timestamp) {
      parsedDate = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      parsedDate = DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now();
    }

    final rawAmounts = (map['amounts'] as Map?) ?? {};
    final parsedAmounts = <String, double>{};
    rawAmounts.forEach((key, value) {
      parsedAmounts[key.toString()] = (value as num).toDouble();
    });

    final rawPaidStatus = (map['paidStatus'] as Map?) ?? {};
    final parsedPaidStatus = <String, bool>{};
    rawPaidStatus.forEach((key, value) {
      parsedPaidStatus[key.toString()] = value == true;
    });

    final rawItems = (map['items'] as List?) ?? [];
    final parsedItems = rawItems.map((itemMap) => SplitItem.fromMap(itemMap as Map<String, dynamic>)).toList();

    return SplitBill(
      id: documentId,
      title: map['title'] as String? ?? 'Unknown',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      createdBy: map['createdBy'] as String? ?? '',
      participants: (map['participants'] as List?)?.cast<String>() ?? [],
      paidStatus: parsedPaidStatus,
      splitType: map['splitType'] as String? ?? 'SplitType.equal',
      amounts: parsedAmounts,
      createdAt: parsedDate,
      receiptUrl: map['receiptUrl'] as String?,
      items: parsedItems.isNotEmpty ? parsedItems : null,
      taxAmount: (map['taxAmount'] as num?)?.toDouble(),
      tipAmount: (map['tipAmount'] as num?)?.toDouble(),
      isItemized: map['isItemized'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'totalAmount': totalAmount,
      'createdBy': createdBy,
      'participants': participants,
      'paidStatus': paidStatus,
      'splitType': splitType,
      'amounts': amounts,
      'createdAt': Timestamp.fromDate(createdAt),
      if (receiptUrl != null) 'receiptUrl': receiptUrl,
      if (items != null) 'items': items!.map((item) => item.toMap()).toList(),
      if (taxAmount != null) 'taxAmount': taxAmount,
      if (tipAmount != null) 'tipAmount': tipAmount,
      'isItemized': isItemized,
    };
  }

  SplitBill copyWith({
    String? id,
    String? title,
    double? totalAmount,
    String? createdBy,
    List<String>? participants,
    Map<String, bool>? paidStatus,
    String? splitType,
    Map<String, double>? amounts,
    DateTime? createdAt,
    String? receiptUrl,
    List<SplitItem>? items,
    double? taxAmount,
    double? tipAmount,
    bool? isItemized,
  }) {
    return SplitBill(
      id: id ?? this.id,
      title: title ?? this.title,
      totalAmount: totalAmount ?? this.totalAmount,
      createdBy: createdBy ?? this.createdBy,
      participants: participants ?? this.participants,
      paidStatus: paidStatus ?? this.paidStatus,
      splitType: splitType ?? this.splitType,
      amounts: amounts ?? this.amounts,
      createdAt: createdAt ?? this.createdAt,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      items: items ?? this.items,
      taxAmount: taxAmount ?? this.taxAmount,
      tipAmount: tipAmount ?? this.tipAmount,
      isItemized: isItemized ?? this.isItemized,
    );
  }
}
