import 'package:cloud_firestore/cloud_firestore.dart';

class Settlement {
  final String id;
  final String groupId;
  final String fromUserUid;
  final String toUserUid;
  final double amount;
  final DateTime settledAt;
  final String? proofUrl;
  final String? note;
  final bool isSettled;

  Settlement({
    required this.id,
    required this.groupId,
    required this.fromUserUid,
    required this.toUserUid,
    required this.amount,
    required this.settledAt,
    this.proofUrl,
    this.note,
    this.isSettled = true,
  });

  factory Settlement.fromMap(Map<String, dynamic> map, String documentId) {
    return Settlement(
      id: documentId,
      groupId: map['groupId'] as String? ?? '',
      fromUserUid: map['fromUserUid'] as String? ?? '',
      toUserUid: map['toUserUid'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      settledAt: (map['settledAt'] is Timestamp)
          ? (map['settledAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['settledAt'] as String? ?? '') ?? DateTime.now(),
      proofUrl: map['proofUrl'] as String?,
      note: map['note'] as String?,
      isSettled: map['isSettled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'fromUserUid': fromUserUid,
      'toUserUid': toUserUid,
      'amount': amount,
      'settledAt': Timestamp.fromDate(settledAt),
      'proofUrl': proofUrl,
      'note': note,
      'isSettled': isSettled,
    };
  }

  Settlement copyWith({
    String? id,
    String? groupId,
    String? fromUserUid,
    String? toUserUid,
    double? amount,
    DateTime? settledAt,
    String? proofUrl,
    String? note,
    bool? isSettled,
  }) {
    return Settlement(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      fromUserUid: fromUserUid ?? this.fromUserUid,
      toUserUid: toUserUid ?? this.toUserUid,
      amount: amount ?? this.amount,
      settledAt: settledAt ?? this.settledAt,
      proofUrl: proofUrl ?? this.proofUrl,
      note: note ?? this.note,
      isSettled: isSettled ?? this.isSettled,
    );
  }
}
