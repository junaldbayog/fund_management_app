import 'package:flutter/material.dart';
import '../models/client.dart';
import '../models/transaction.dart';
import '../services/storage_service.dart';
import '../widgets/jpb_app_bar.dart';
import 'package:intl/intl.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final Client client;

  const TransactionHistoryScreen({
    super.key,
    required this.client,
  });

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final StorageService _storage = StorageService();
  List<Transaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final transactions = await _storage.getTransactions(clientId: widget.client.id);
      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading transactions: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: JPBAppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Client Info Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.client.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Initial Investment: ${NumberFormat.currency(symbol: '\$').format(widget.client.initialInvestment)}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    'Started: ${DateFormat('MMM dd, yyyy').format(widget.client.startingDate)}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Transactions List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? const Center(
                        child: Text('No transactions yet'),
                      )
                    : ListView.builder(
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final transaction = _transactions[index];
                          final isDeposit =
                              transaction.type == TransactionType.deposit;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isDeposit
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                child: Icon(
                                  isDeposit ? Icons.add : Icons.remove,
                                  color:
                                      isDeposit ? Colors.green : Colors.red,
                                ),
                              ),
                              title: Text(
                                NumberFormat.currency(symbol: '\$')
                                    .format(transaction.amount),
                                style: TextStyle(
                                  color: isDeposit ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('MMM dd, yyyy hh:mm a')
                                        .format(transaction.date),
                                  ),
                                  if (transaction.description.isNotEmpty)
                                    Text(
                                      transaction.description,
                                      style: const TextStyle(
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                              isThreeLine: transaction.description.isNotEmpty,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
} 