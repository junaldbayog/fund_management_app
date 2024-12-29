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
  final TradeType type;

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
    required this.type,
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
      'type': type.name,
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
      type: map['type'] != null 
        ? TradeType.values.firstWhere(
            (e) => e.name == map['type'],
            orElse: () => TradeType.long,
          )
        : TradeType.long,
    );
  }

  Trade copyWith({
    String? id,
    DateTime? date,
    String? ticker,
    double? buyPrice,
    int? quantity,
    double? sellPrice,
    String? setup,
    String? notes,
    DateTime? sellDate,
    TradeType? type,
  }) {
    return Trade(
      id: id ?? this.id,
      date: date ?? this.date,
      ticker: ticker ?? this.ticker,
      buyPrice: buyPrice ?? this.buyPrice,
      quantity: quantity ?? this.quantity,
      sellPrice: sellPrice ?? this.sellPrice,
      setup: setup ?? this.setup,
      notes: notes ?? this.notes,
      sellDate: sellDate ?? this.sellDate,
      type: type ?? this.type,
    );
  }
}

enum TradeType {
  long,
  short
} 