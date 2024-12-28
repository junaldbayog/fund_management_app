class Trade {
  final String id;
  final DateTime date;
  final String ticker;
  final double buyPrice;
  final int quantity;
  final double? sellPrice;
  final String setup;
  final String notes;
  final DateTime? sellDate;

  Trade({
    required this.id,
    required this.date,
    required this.ticker,
    required this.buyPrice,
    required this.quantity,
    this.sellPrice,
    required this.setup,
    required this.notes,
    this.sellDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'ticker': ticker,
      'buyPrice': buyPrice,
      'quantity': quantity,
      'sellPrice': sellPrice,
      'setup': setup,
      'notes': notes,
      'sellDate': sellDate?.toIso8601String(),
    };
  }

  factory Trade.fromMap(Map<String, dynamic> map) {
    return Trade(
      id: map['id'],
      date: DateTime.parse(map['date']),
      ticker: map['ticker'],
      buyPrice: map['buyPrice'],
      quantity: map['quantity'],
      sellPrice: map['sellPrice'],
      setup: map['setup'],
      notes: map['notes'],
      sellDate: map['sellDate'] != null ? DateTime.parse(map['sellDate']) : null,
    );
  }
} 