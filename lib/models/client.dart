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

class Transaction {
  final String id;
  final String clientId;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final String description;

  Transaction({
    required this.id,
    required this.clientId,
    required this.amount,
    required this.date,
    required this.type,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type.name,
      'description': description,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      clientId: map['clientId'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.deposit,
      ),
      description: map['description'],
    );
  }
}

enum TransactionType {
  deposit,
  withdrawal
} 