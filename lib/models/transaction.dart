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
      description: map['description'] ?? '',
    );
  }
}

enum TransactionType {
  deposit,
  withdrawal
} 