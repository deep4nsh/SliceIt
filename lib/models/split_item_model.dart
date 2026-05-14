class SplitItem {
  final String id;
  final String name;
  final double price;
  final List<String> assignedParticipants;

  SplitItem({
    required this.id,
    required this.name,
    required this.price,
    required this.assignedParticipants,
  });

  factory SplitItem.fromMap(Map<String, dynamic> map) {
    return SplitItem(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Item',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      assignedParticipants: (map['assignedParticipants'] as List?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'assignedParticipants': assignedParticipants,
    };
  }

  SplitItem copyWith({
    String? id,
    String? name,
    double? price,
    List<String>? assignedParticipants,
  }) {
    return SplitItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      assignedParticipants: assignedParticipants ?? this.assignedParticipants,
    );
  }
}
