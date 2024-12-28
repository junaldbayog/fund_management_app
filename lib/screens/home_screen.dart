import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../widgets/jpb_app_bar.dart';
import '../models/client.dart';
import '../utils/currency_input_formatter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();
  double _totalInvestment = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTotalInvestment();
  }

  Future<void> _loadTotalInvestment() async {
    setState(() => _isLoading = true);
    try {
      final clients = await _storage.getClients();
      final total = clients.fold<double>(
        0,
        (sum, client) => sum + client.initialInvestment,
      );
      setState(() {
        _totalInvestment = total;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading total investment: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading total investment: $e')),
        );
      }
    }
  }

  void _showDepositDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const DepositDialog(),
    );

    if (result == true) {
      _loadTotalInvestment(); // Refresh the total
    }
  }

  void _showWithdrawDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const WithdrawDialog(),
    );

    if (result == true) {
      _loadTotalInvestment(); // Refresh the total
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const JPBAppBar(showBackButton: false),
      body: RefreshIndicator(
        onRefresh: _loadTotalInvestment,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Investment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _isLoading
                            ? const CircularProgressIndicator()
                            : Text(
                                NumberFormat.currency(
                                  symbol: '\$',
                                  decimalDigits: 2,
                                ).format(_totalInvestment),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00d293),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showDepositDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Deposit'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showWithdrawDialog,
                        icon: const Icon(Icons.remove),
                        label: const Text('Withdraw'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
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

class DepositDialog extends StatefulWidget {
  const DepositDialog({super.key});

  @override
  State<DepositDialog> createState() => _DepositDialogState();
}

class _DepositDialogState extends State<DepositDialog> {
  final StorageService _storage = StorageService();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedClientId;
  List<Client> _clients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    try {
      final clients = await _storage.getClients();
      setState(() {
        _clients = clients;
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

  Future<void> _submitDeposit() async {
    if (_formKey.currentState!.validate() && _selectedClientId != null) {
      try {
        final amount = CurrencyInputFormatter.getNumericValue(_amountController.text);
        final transaction = Transaction(
          id: const Uuid().v4(),
          clientId: _selectedClientId!,
          amount: amount,
          date: DateTime.now(),
          type: TransactionType.deposit,
          description: _descriptionController.text.trim(),
        );

        await _storage.addTransaction(transaction);

        // Update client's initial investment
        final client = await _storage.getClient(_selectedClientId!);
        if (client != null) {
          final updatedClient = Client(
            id: client.id,
            name: client.name,
            initialInvestment: client.initialInvestment + amount,
            startingDate: client.startingDate,
          );
          await _storage.updateClient(updatedClient);
        }

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deposit successful')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error making deposit: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Make a Deposit'),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedClientId,
                      decoration: const InputDecoration(
                        labelText: 'Select Client',
                        hintText: 'Choose a client',
                      ),
                      items: _clients.map((client) {
                        return DropdownMenuItem(
                          value: client.id,
                          child: Text(client.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedClientId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a client';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
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
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Enter description',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitDeposit,
          child: const Text('Deposit'),
        ),
      ],
    );
  }
}

class WithdrawDialog extends StatefulWidget {
  const WithdrawDialog({super.key});

  @override
  State<WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends State<WithdrawDialog> {
  final StorageService _storage = StorageService();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedClientId;
  Client? _selectedClient;
  List<Client> _clients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    try {
      final clients = await _storage.getClients();
      setState(() {
        _clients = clients;
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

  void _onClientSelected(String? clientId) async {
    setState(() => _selectedClientId = clientId);
    if (clientId != null) {
      final client = await _storage.getClient(clientId);
      setState(() => _selectedClient = client);
    }
  }

  Future<void> _submitWithdrawal() async {
    if (_formKey.currentState!.validate() && _selectedClientId != null) {
      try {
        final amount = CurrencyInputFormatter.getNumericValue(_amountController.text);
        final transaction = Transaction(
          id: const Uuid().v4(),
          clientId: _selectedClientId!,
          amount: amount,
          date: DateTime.now(),
          type: TransactionType.withdrawal,
          description: _descriptionController.text.trim(),
        );

        await _storage.addTransaction(transaction);

        // Update client's initial investment
        if (_selectedClient != null) {
          final updatedClient = Client(
            id: _selectedClient!.id,
            name: _selectedClient!.name,
            initialInvestment: _selectedClient!.initialInvestment - amount,
            startingDate: _selectedClient!.startingDate,
          );
          await _storage.updateClient(updatedClient);
        }

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Withdrawal successful')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error making withdrawal: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Make a Withdrawal'),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedClientId,
                      decoration: const InputDecoration(
                        labelText: 'Select Client',
                        hintText: 'Choose a client',
                      ),
                      items: _clients.map((client) {
                        return DropdownMenuItem(
                          value: client.id,
                          child: Text(client.name),
                        );
                      }).toList(),
                      onChanged: _onClientSelected,
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a client';
                        }
                        return null;
                      },
                    ),
                    if (_selectedClient != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Available Balance: ${NumberFormat.currency(symbol: '\$').format(_selectedClient!.initialInvestment)}',
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
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
                        if (_selectedClient != null && amount > _selectedClient!.initialInvestment) {
                          return 'Amount exceeds available balance';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Enter description',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitWithdrawal,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Withdraw'),
        ),
      ],
    );
  }
} 