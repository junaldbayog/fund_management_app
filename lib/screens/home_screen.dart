import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../widgets/jpb_app_bar.dart';
import '../models/client.dart';
import '../utils/currency_input_formatter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/trade.dart';
import '../models/transaction.dart';
import '../utils/trade_statistics.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();
  double _totalInvestment = 0;
  bool _isLoading = true;
  bool _showInvestment = false;
  Map<String, double> _stats = {
    'winRate': 0,
    'totalProfit': 0,
    'edgeRatio': 0,
    'expectancy': 0,
    'averageWin': 0,
    'averageLoss': 0,
    'twrr': 0,
  };
  List<Trade> _trades = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final futures = await Future.wait([
        _storage.getClients(),
        _storage.getTrades(),
        _storage.getTransactions(),
      ]);

      final clients = futures[0] as List<Client>;
      final trades = futures[1] as List<Trade>;
      final transactions = futures[2] as List<Transaction>;

      // Calculate total investment including initial investments, transactions, and trade profits/losses
      double total = 0;
      for (final client in clients) {
        if (client.isActive != false) { // Only include active clients
          double clientTotal = client.initialInvestment;
          
          // Add transactions
          final clientTransactions = transactions.where((t) => t.clientId == client.id);
          for (final transaction in clientTransactions) {
            if (transaction.type == TransactionType.deposit) {
              clientTotal += transaction.amount;
            } else {
              clientTotal -= transaction.amount;
            }
          }
          
          total += clientTotal;
        }
      }

      // Add trade profits/losses from closed trades
      final closedTrades = trades.where((t) => t.sellPrice != null);
      for (final trade in closedTrades) {
        final profit = trade.type == TradeType.long
          ? (trade.sellPrice! - trade.buyPrice) * trade.quantity
          : (trade.buyPrice - trade.sellPrice!) * trade.quantity;
        total += profit;
      }

      setState(() {
        _totalInvestment = total;
        _trades = trades;
        _calculateStats(trades);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  void _calculateStats(List<Trade> trades) {
    if (trades.isEmpty) {
      _stats = {
        'winRate': 0,
        'totalProfit': 0,
        'edgeRatio': 0,
        'expectancy': 0,
        'averageWin': 0,
        'averageLoss': 0,
        'twrr': 0,
      };
      return;
    }
    _stats = TradeStatistics.calculateStats(trades, _totalInvestment);
  }

  Widget _buildStatItem(String label, String value, Color? valueColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountValueChart() {
    if (_trades.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort trades by date
    final sortedTrades = List<Trade>.from(_trades)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Calculate cumulative account value over time
    double accountValue = 0;
    final dataPoints = <FlSpot>[];
    final dates = <DateTime>[];

    for (var i = 0; i < sortedTrades.length; i++) {
      final trade = sortedTrades[i];
      if (trade.sellPrice != null && trade.sellDate != null) {
        final profit = trade.type == TradeType.long
          ? (trade.sellPrice! - trade.buyPrice) * trade.quantity
          : (trade.buyPrice - trade.sellPrice!) * trade.quantity;
        accountValue += profit;
        dataPoints.add(FlSpot(i.toDouble(), accountValue));
        dates.add(trade.sellDate!);
      }
    }

    if (dataPoints.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    Icons.show_chart_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'PNL Over Time',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            NumberFormat.compactCurrency(symbol: '\$').format(value),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < dates.length) {
                            int interval = (dates.length / 4).ceil(); // Show about 4 dates
                            if (value.toInt() % interval == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 10.0),
                                child: Transform.rotate(
                                  angle: -0.5, // Rotate by about 30 degrees
                                  child: Text(
                                    DateFormat('MM/dd').format(dates[value.toInt()]),
                                    style: const TextStyle(fontSize: 10),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              );
                            }
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: dataPoints,
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeStats() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    Icons.analytics_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Trading Performance',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildStatItem(
                  'Win Rate',
                  '${_stats['winRate']?.toStringAsFixed(1)}%',
                  _stats['winRate']! >= 50 ? Colors.green : Colors.red,
                  Icons.analytics_rounded,
                ),
                _buildStatItem(
                  'Total P/L',
                  NumberFormat.currency(symbol: '\$').format(_stats['totalProfit']),
                  _stats['totalProfit']! > 0 ? Colors.green : Colors.red,
                  Icons.account_balance_rounded,
                ),
                _buildStatItem(
                  'Edge Ratio',
                  _stats['edgeRatio']?.toStringAsFixed(2) ?? '0',
                  _stats['edgeRatio']! >= 1 ? Colors.green : Colors.red,
                  Icons.show_chart_rounded,
                ),
                _buildStatItem(
                  'Expectancy',
                  NumberFormat.currency(symbol: '\$').format(_stats['expectancy']),
                  _stats['expectancy']! > 0 ? Colors.green : Colors.red,
                  Icons.trending_flat_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDepositDialog() async {
    final TextEditingController amountController = TextEditingController();
    String? selectedClientId;
    List<Client> clients = [];

    try {
      clients = await _storage.getClients();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading clients: $e')),
        );
      }
      return;
    }

    if (clients.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add a client first')),
        );
      }
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make a Deposit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Select Client',
                border: OutlineInputBorder(),
              ),
              items: clients.map((client) {
                return DropdownMenuItem(
                  value: client.id,
                  child: Text(client.name),
                );
              }).toList(),
              onChanged: (value) {
                selectedClientId = value;
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select a client';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: 'Enter amount to deposit',
                prefixText: '\$',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (selectedClientId == null || amountController.text.isEmpty) {
                return;
              }

              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                return;
              }

              final selectedClient = clients.firstWhere((c) => c.id == selectedClientId);
              final transaction = Transaction(
                id: const Uuid().v4(),
                clientId: selectedClient.id,
                amount: amount,
                date: DateTime.now(),
                type: TransactionType.deposit,
                description: 'Deposit',
              );

              await _storage.addTransaction(transaction);
              await _loadData();

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Successfully deposited \$${amount.toStringAsFixed(2)} for ${selectedClient.name}')),
                );
              }
            },
            child: const Text('Deposit'),
          ),
        ],
      ),
    );
  }

  Future<void> _showWithdrawDialog() async {
    final TextEditingController amountController = TextEditingController();
    String? selectedClientId;
    List<Client> clients = [];
    Map<String, double> clientBalances = {};

    try {
      final futures = await Future.wait([
        _storage.getClients(),
        _storage.getTransactions(),
      ]);

      clients = futures[0] as List<Client>;
      final transactions = futures[1] as List<Transaction>;

      // Calculate each client's total investment (initial + deposits - withdrawals)
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading clients: $e')),
        );
      }
      return;
    }

    if (clients.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add a client first')),
        );
      }
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Make a Withdrawal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Select Client',
                  border: OutlineInputBorder(),
                ),
                items: clients.map((client) {
                  return DropdownMenuItem(
                    value: client.id,
                    child: Text('${client.name} (Balance: \$${clientBalances[client.id]?.toStringAsFixed(2)})'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedClientId = value;
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
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: 'Enter amount to withdraw',
                  prefixText: '\$',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedClientId == null || amountController.text.isEmpty) {
                  return;
                }

                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  return;
                }

                final clientBalance = clientBalances[selectedClientId] ?? 0;
                if (amount > clientBalance) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Cannot withdraw \$${amount.toStringAsFixed(2)}. Available balance: \$${clientBalance.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final selectedClient = clients.firstWhere((c) => c.id == selectedClientId);
                final transaction = Transaction(
                  id: const Uuid().v4(),
                  clientId: selectedClient.id,
                  amount: amount,
                  date: DateTime.now(),
                  type: TransactionType.withdrawal,
                  description: 'Withdrawal',
                );

                await _storage.addTransaction(transaction);
                await _loadData();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Successfully withdrew \$${amount.toStringAsFixed(2)} from ${selectedClient.name}')),
                  );
                }
              },
              child: const Text('Withdraw'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const JPBAppBar(showBackButton: false),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
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
                                  Icons.account_balance_wallet_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Investment',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (_showInvestment)
                                        _isLoading
                                          ? const SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  NumberFormat.currency(
                                                    symbol: '\$',
                                                    decimalDigits: 2,
                                                  ).format(_totalInvestment),
                                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                                    color: Theme.of(context).colorScheme.primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.trending_up_rounded,
                                                      size: 14,
                                                      color: _stats['twrr']! > 0 ? Colors.green : Colors.red,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'TWRR: ${_stats['twrr']?.toStringAsFixed(1)}%',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: _stats['twrr']! > 0 ? Colors.green : Colors.red,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            )
                                      else
                                        Text(
                                          '••••••',
                                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      IconButton(
                                        icon: Icon(
                                          _showInvestment ? Icons.visibility_off : Icons.visibility,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _showInvestment = !_showInvestment;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _showDepositDialog,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.arrow_circle_up_rounded,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Deposit',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _showWithdrawDialog,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.arrow_circle_down_rounded,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Withdraw',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_trades.isNotEmpty) _buildAccountValueChart(),
                  _buildTradeStats(),
                ],
              ),
            ),
    );
  }
} 