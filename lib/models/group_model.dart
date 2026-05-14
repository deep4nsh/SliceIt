class Group {
  final String id;
  final String name;
  final String createdBy;
  final List<String> members;

  Group({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.members,
  });

  factory Group.fromMap(Map<String, dynamic> map, String documentId) {
    return Group(
      id: documentId,
      name: map['name'] as String? ?? 'Unnamed Group',
      createdBy: map['createdBy'] as String? ?? '',
      members: (map['members'] as List?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdBy': createdBy,
      'members': members,
    };
  }

  Group copyWith({
    String? id,
    String? name,
    String? createdBy,
    List<String>? members,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      createdBy: createdBy ?? this.createdBy,
      members: members ?? this.members,
    );
  }
}
