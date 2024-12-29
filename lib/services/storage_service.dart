import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/client.dart';
import '../models/trade.dart';
import '../models/transaction.dart';
import 'dart:convert';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  late Box<String> _clientsBox;
  late Box<String> _transactionsBox;
  late Box<String> _tradesBox;
  static const String _tradesBoxName = 'trades';

  factory StorageService() => _instance;

  StorageService._internal();

  Future<void> init() async {
    await Hive.initFlutter();
    _clientsBox = await Hive.openBox<String>('clients');
    _transactionsBox = await Hive.openBox<String>('transactions');
    _tradesBox = await Hive.openBox<String>(_tradesBoxName);
  }

  Future<void> insertClient(Client client) async {
    await _clientsBox.put(client.id, jsonEncode(client.toMap()));
  }

  Future<List<Client>> getClients() async {
    final clientMaps = _clientsBox.values.map((str) => jsonDecode(str)).toList();
    return clientMaps.map((map) => Client.fromMap(map)).toList();
  }

  Future<Client?> getClient(String id) async {
    final clientStr = _clientsBox.get(id);
    if (clientStr == null) return null;
    return Client.fromMap(jsonDecode(clientStr));
  }

  Future<void> updateClient(Client client) async {
    await _clientsBox.put(client.id, jsonEncode(client.toMap()));
  }

  Future<void> deleteClient(String id) async {
    await _clientsBox.delete(id);
  }

  Future<void> addTransaction(Transaction transaction) async {
    await _transactionsBox.put(
      transaction.id,
      jsonEncode(transaction.toMap()),
    );
  }

  Future<List<Transaction>> getTransactions({String? clientId}) async {
    final transactionMaps =
        _transactionsBox.values.map((str) => jsonDecode(str)).toList();
    final transactions =
        transactionMaps.map((map) => Transaction.fromMap(map)).toList();

    if (clientId != null) {
      return transactions.where((t) => t.clientId == clientId).toList();
    }
    return transactions;
  }

  Future<void> deleteTransaction(String id) async {
    await _transactionsBox.delete(id);
  }

  Future<List<Trade>> getTrades() async {
    final tradeMaps = _tradesBox.values.map((str) => jsonDecode(str)).toList();
    return tradeMaps.map((map) => Trade.fromMap(map)).toList().reversed.toList();
  }

  Future<void> addTrade(Trade trade) async {
    await _tradesBox.put(trade.id, jsonEncode(trade.toMap()));
  }

  Future<void> updateTrade(Trade trade) async {
    await _tradesBox.put(trade.id, jsonEncode(trade.toMap()));
  }

  Future<void> deleteTrade(String id) async {
    await _tradesBox.delete(id);
  }
} 