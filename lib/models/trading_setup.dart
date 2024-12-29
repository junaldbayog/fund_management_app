class TradingSetup {
  final String id;
  final String name;
  final String description;
  final bool isActive;

  TradingSetup({
    required this.id,
    required this.name,
    required this.description,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'isActive': isActive,
    };
  }

  factory TradingSetup.fromMap(Map<String, dynamic> map) {
    return TradingSetup(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      isActive: map['isActive'] ?? true,
    );
  }

  TradingSetup copyWith({
    String? id,
    String? name,
    String? description,
    bool? isActive,
  }) {
    return TradingSetup(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
    );
  }
} 