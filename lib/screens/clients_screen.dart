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

  Future<void> _deactivateClient(Client client) async {
    try {
      // Create a withdrawal transaction for the remaining balance
      final balance = _clientBalances[client.id] ?? 0.0;
      if (balance > 0) {
        final transaction = Transaction(
          id: const Uuid().v4(),
          clientId: client.id,
          amount: balance,
          date: DateTime.now(),
          type: TransactionType.withdrawal,
          description: 'Account deactivation withdrawal',
        );
        await _storage.addTransaction(transaction);
      }

      // Update client status to inactive
      final updatedClient = client.copyWith(isActive: false);
      await _storage.updateClient(updatedClient);
      await _loadClients();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${client.name} has been deactivated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deactivating client: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _confirmDeactivate(Client client) async {
    final balance = _clientBalances[client.id] ?? 0.0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deactivation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to deactivate ${client.name}?'),
            const SizedBox(height: 16),
            if (balance > 0) ...[
              Text(
                'Current balance of ${NumberFormat.currency(symbol: '\$').format(balance)} will be withdrawn.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
            ],
            const Text(
              'This action will remove all funds and mark the account as inactive.',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deactivateClient(client);
    }
  }

  Future<void> _reactivateClient(Client client) async {
    try {
      // Create a new client with zero investment and active status
      final updatedClient = client.copyWith(
        isActive: true,
        initialInvestment: 0,
      );
      await _storage.updateClient(updatedClient);

      // Reset the client's balance in the local state
      setState(() {
        _clientBalances[client.id] = 0;
      });

      await _loadClients();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${client.name} has been reactivated with zero balance')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reactivating client: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _confirmReactivate(Client client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Reactivation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to reactivate ${client.name}?'),
            const SizedBox(height: 8),
            const Text(
              'The client will be reactivated with a zero balance and will need to make new deposits to invest.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _reactivateClient(client);
    }
  }

  Widget _buildInvestmentInfo(String label, double amount, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            NumberFormat.currency(symbol: '\$').format(amount),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    // Calculate total investment only from active clients
    final activeClients = _clients.where((c) => c.isActive).toList();
    double totalInvestment = 0;
    for (final client in activeClients) {
      totalInvestment += _clientBalances[client.id] ?? 0.0;
    }

    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.groups_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Portfolio Summary',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${activeClients.length} Active ${activeClients.length == 1 ? 'Client' : 'Clients'}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Assets Under Management',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    NumberFormat.currency(symbol: '\$').format(totalInvestment),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter active clients for the main list
    final activeClients = _clients.where((c) => c.isActive).toList();
    final inactiveClients = _clients.where((c) => !c.isActive).toList();

    return Scaffold(
      appBar: const JPBAppBar(showBackButton: false),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _clients.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No clients yet',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first client to get started',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _showAddClientDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Client'),
                      ),
                    ],
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildSummaryCard(),
                    ),
                    if (activeClients.isNotEmpty) ...[
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            children: [
                              Text(
                                'Active Clients',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  activeClients.length.toString(),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final client = activeClients[index];
                              final balance = _clientBalances[client.id] ?? 0.0;
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.person_rounded,
                                              color: Theme.of(context).colorScheme.primary,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  client.name,
                                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
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
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert),
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 'history',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.history_rounded),
                                                    SizedBox(width: 8),
                                                    Text('Transaction History'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit_rounded),
                                                    SizedBox(width: 8),
                                                    Text('Edit'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'deactivate',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.person_off_rounded, color: Colors.red),
                                                    SizedBox(width: 8),
                                                    Text('Deactivate', style: TextStyle(color: Colors.red)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            onSelected: (value) {
                                              switch (value) {
                                                case 'history':
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => TransactionHistoryScreen(client: client),
                                                    ),
                                                  );
                                                  break;
                                                case 'edit':
                                                  _showEditClientDialog(client);
                                                  break;
                                                case 'deactivate':
                                                  _confirmDeactivate(client);
                                                  break;
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildInvestmentInfo(
                                              'Initial Investment',
                                              client.initialInvestment,
                                              Icons.account_balance_rounded,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _buildInvestmentInfo(
                                              'Total Investment',
                                              balance,
                                              Icons.account_balance_wallet_rounded,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: activeClients.length,
                          ),
                        ),
                      ),
                    ],
                    if (inactiveClients.isNotEmpty) ...[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            children: [
                              Text(
                                'Inactive Clients',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  inactiveClients.length.toString(),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final client = inactiveClients[index];
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.person_off_rounded,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              client.name,
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                              ),
                                            ),
                                            if (client.startingDate != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'Deactivated: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.history_rounded),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => TransactionHistoryScreen(client: client),
                                                ),
                                              );
                                            },
                                            tooltip: 'Transaction History',
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.person_add_rounded),
                                            onPressed: () => _confirmReactivate(client),
                                            tooltip: 'Reactivate Client',
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: inactiveClients.length,
                          ),
                        ),
                      ),
                    ],
                  ],
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