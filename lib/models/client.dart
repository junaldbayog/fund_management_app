class Client {
  final String id;
  final String name;
  final double initialInvestment;
  final DateTime startingDate;
  final bool isActive;

  Client({
    required this.id,
    required this.name,
    required this.initialInvestment,
    required this.startingDate,
    this.isActive = true,
  });

  // Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'initialInvestment': initialInvestment,
      'startingDate': startingDate.toIso8601String(),
      'isActive': isActive,
    };
  }

  // Create Client from Map (database)
  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'],
      name: map['name'],
      initialInvestment: map['initialInvestment'],
      startingDate: DateTime.parse(map['startingDate']),
      isActive: map['isActive'] ?? true,
    );
  }

  // Create a copy of the client with updated fields
  Client copyWith({
    String? id,
    String? name,
    double? initialInvestment,
    DateTime? startingDate,
    bool? isActive,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      initialInvestment: initialInvestment ?? this.initialInvestment,
      startingDate: startingDate ?? this.startingDate,
      isActive: isActive ?? this.isActive,
    );
  }
} 