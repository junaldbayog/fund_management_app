import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/client.dart';
import '../services/storage_service.dart';
import '../widgets/jpb_app_bar.dart';
import '../utils/currency_input_formatter.dart';
import 'transaction_history_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final StorageService _storage = StorageService();
  List<Client> _clients = [];
  Map<String, double> _clientTotals = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() => _isLoading = true);
    try {
      final clients = await _storage.getClients();
      final Map<String, double> totals = {};
      
      // Calculate totals for each client
      for (final client in clients) {
        final transactions = await _storage.getTransactions(clientId: client.id);
        double total = client.initialInvestment;
        for (final transaction in transactions) {
          if (transaction.type == TransactionType.deposit) {
            total += transaction.amount;
          } else {
            total -= transaction.amount;
          }
        }
        totals[client.id] = total;
      }

      setState(() {
        _clients = clients;
        _clientTotals = totals;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading clients: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading clients: ${e.toString()}')),
        );
      }
    }
  }

  void _showAddClientDialog() {
    showDialog(
      context: context,
      builder: (context) => ClientDialog(
        onSave: (client) async {
          try {
            await _storage.insertClient(client);
            await _loadClients();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Client added successfully')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error adding client: ${e.toString()}')),
              );
            }
          }
        },
      ),
    );
  }

  void _showEditClientDialog(Client client) {
    showDialog(
      context: context,
      builder: (context) => ClientDialog(
        client: client,
        onSave: (updatedClient) async {
          try {
            await _storage.updateClient(updatedClient);
            await _loadClients();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Client updated successfully')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error updating client: ${e.toString()}')),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _deleteClient(Client client) async {
    try {
      await _storage.deleteClient(client.id);
      await _loadClients();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting client: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _confirmDelete(Client client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${client.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteClient(client);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const JPBAppBar(showBackButton: false),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _clients.isEmpty
              ? const Center(
                  child: Text('No clients yet. Add your first client!'),
                )
              : ListView.builder(
                  itemCount: _clients.length,
                  itemBuilder: (context, index) {
                    final client = _clients[index];
                    final totalInvestment = _clientTotals[client.id] ?? 0.0;
                    final hasGain = totalInvestment > client.initialInvestment;
                    final hasSameValue = totalInvestment == client.initialInvestment;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text(
                          client.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Initial Investment: ${NumberFormat.currency(symbol: '\$').format(client.initialInvestment)}',
                            ),
                            Row(
                              children: [
                                Text(
                                  'Current Value: ${NumberFormat.currency(symbol: '\$').format(totalInvestment)}',
                                  style: TextStyle(
                                    color: hasGain
                                        ? Colors.green
                                        : hasSameValue
                                            ? Colors.grey
                                            : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                if (!hasSameValue)
                                  Icon(
                                    hasGain
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 16,
                                    color: hasGain ? Colors.green : Colors.red,
                                  ),
                              ],
                            ),
                            Text(
                              'Started: ${DateFormat('MMM dd, yyyy').format(client.startingDate)}',
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.history),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TransactionHistoryScreen(
                                      client: client,
                                    ),
                                  ),
                                ).then((_) => _loadClients()); // Refresh after returning
                              },
                              tooltip: 'Transaction History',
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showEditClientDialog(client),
                              tooltip: 'Edit Client',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _confirmDelete(client),
                              tooltip: 'Delete Client',
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddClientDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ClientDialog extends StatefulWidget {
  final Client? client;
  final Function(Client) onSave;

  const ClientDialog({
    super.key,
    this.client,
    required this.onSave,
  });

  @override
  State<ClientDialog> createState() => _ClientDialogState();
}

class _ClientDialogState extends State<ClientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _investmentController = TextEditingController();
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    if (widget.client != null) {
      _nameController.text = widget.client!.name;
      _investmentController.text =
          widget.client!.initialInvestment.toStringAsFixed(2);
      _selectedDate = widget.client!.startingDate;
    } else {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _investmentController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final amount = CurrencyInputFormatter.getNumericValue(_investmentController.text);
      final client = Client(
        id: widget.client?.id ?? const Uuid().v4(),
        name: _nameController.text,
        initialInvestment: amount,
        startingDate: _selectedDate,
      );
      widget.onSave(client);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.client == null ? 'Add New Client' : 'Edit Client'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Client Name',
                  hintText: 'Enter client name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _investmentController,
                decoration: const InputDecoration(
                  labelText: 'Initial Investment',
                  hintText: 'Enter amount',
                  prefixText: '\$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  CurrencyInputFormatter(),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = CurrencyInputFormatter.getNumericValue(value);
                  if (amount <= 0) {
                    return 'Amount must be greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Starting Date'),
                subtitle: Text(
                  DateFormat('MMM dd, yyyy').format(_selectedDate),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selectDate,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitForm,
          child: Text(widget.client == null ? 'Add Client' : 'Save Changes'),
        ),
      ],
    );
  }
} 