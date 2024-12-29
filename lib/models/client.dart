class Client {
  final String id;
  final String name;
  final double initialInvestment;
  final DateTime startingDate;

  Client({
    required this.id,
    required this.name,
    required this.initialInvestment,
    required this.startingDate,
  });

  // Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'initialInvestment': initialInvestment,
      'startingDate': startingDate.toIso8601String(),
    };
  }

  // Create Client from Map (database)
  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'],
      name: map['name'],
      initialInvestment: map['initialInvestment'],
      startingDate: DateTime.parse(map['startingDate']),
    );
  }
} 