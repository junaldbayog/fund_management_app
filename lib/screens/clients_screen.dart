import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/client.dart';
import '../models/transaction.dart';
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
  Map<String, double> _clientBalances = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() => _isLoading = true);
    try {
      final futures = await Future.wait([
        _storage.getClients(),
        _storage.getTransactions(),
      ]);

      final clients = futures[0] as List<Client>;
      final transactions = futures[1] as List<Transaction>;

      // Calculate total investment for each client (initial + deposits - withdrawals)
      Map<String, double> clientBalances = {};
      for (final client in clients) {
        double balance = client.initialInvestment;
        
        // Add transactions
        final clientTransactions = transactions.where((t) => t.clientId == client.id);
        for (final transaction in clientTransactions) {
          if (transaction.type == TransactionType.deposit) {
            balance += transaction.amount;
          } else {
            balance -= transaction.amount;
          }
        }
        
        clientBalances[client.id] = balance;
      }

      setState(() {
        _clients = clients;
        _clientBalances = clientBalances;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading clients: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading clients: $e')),
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
              ? const Center(child: Text('No clients yet. Add your first client!'))
              : ListView.builder(
                  itemCount: _clients.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final client = _clients[index];
                    final balance = _clientBalances[client.id] ?? 0.0;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        client.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Initial: ${NumberFormat.currency(symbol: '\$').format(client.initialInvestment)}',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Total Investment: ${NumberFormat.currency(symbol: '\$').format(balance)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded),
                                      onPressed: () => _showEditClientDialog(client),
                                      tooltip: 'Edit Client',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded),
                                      onPressed: () => _confirmDelete(client),
                                      tooltip: 'Delete Client',
                                      color: Colors.red,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (client.startingDate != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Started: ${DateFormat('MMM dd, yyyy').format(client.startingDate!)}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ],
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
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      widget.client == null ? Icons.person_add : Icons.edit,
                      size: 28,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.client == null ? 'Add New Client' : 'Edit Client',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Client Name',
                    hintText: 'Enter client name',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Investment Field
                TextFormField(
                  controller: _investmentController,
                  decoration: InputDecoration(
                    labelText: 'Initial Investment',
                    hintText: 'Enter amount',
                    prefixIcon: const Icon(Icons.attach_money_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
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
                
                // Date Field
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      color: theme.inputDecorationTheme.fillColor,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Starting Date',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM dd, yyyy').format(_selectedDate),
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          widget.client == null ? 'Add Client' : 'Save Changes',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 