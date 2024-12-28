import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/jpb_app_bar.dart';
import '../models/trade.dart';
import '../utils/currency_input_formatter.dart';
import '../services/storage_service.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class TradingJournalScreen extends StatefulWidget {
  const TradingJournalScreen({super.key});

  @override
  State<TradingJournalScreen> createState() => _TradingJournalScreenState();
}

class _TradingJournalScreenState extends State<TradingJournalScreen> {
  final StorageService _storage = StorageService();
  final List<Trade> _trades = [];
  bool _isLoading = true;
  String? _filterTicker;
  String _sortBy = 'date'; // 'date', 'ticker', 'profit'
  bool _sortAscending = false;
  Map<String, double> _stats = {
    'winRate': 0,
    'hitRate': 0,
    'edgeRatio': 0,
    'totalProfit': 0,
    'averageWin': 0,
    'averageLoss': 0,
    'largestWin': 0,
    'largestLoss': 0,
    'profitFactor': 0,
    'averageHoldingDays': 0,
    'consecutiveWins': 0,
    'consecutiveLosses': 0,
    'expectancy': 0,
    'winningTrades': 0,
    'losingTrades': 0,
    'totalTrades': 0,
    'averageRisk': 0,
    'averageReward': 0,
    'riskRewardRatio': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadTrades();
  }

  void _calculateStats(List<Trade> trades) {
    if (trades.isEmpty) {
      _stats = Map.fromIterables(_stats.keys, List.filled(_stats.length, 0.0));
      return;
    }

    final closedTrades = trades.where((t) => t.sellPrice != null).toList();
    if (closedTrades.isEmpty) {
      _stats = Map.fromIterables(_stats.keys, List.filled(_stats.length, 0.0));
      return;
    }

    final winningTrades = closedTrades.where((t) => t.sellPrice! > t.buyPrice).toList();
    final losingTrades = closedTrades.where((t) => t.sellPrice! < t.buyPrice).toList();

    final totalProfit = closedTrades.fold<double>(
      0,
      (sum, trade) => sum + ((trade.sellPrice! - trade.buyPrice) * trade.quantity),
    );

    final averageWin = winningTrades.isEmpty
        ? 0.0
        : winningTrades.fold<double>(
            0,
            (sum, trade) => sum + ((trade.sellPrice! - trade.buyPrice) * trade.quantity),
          ) / winningTrades.length;

    final averageLoss = losingTrades.isEmpty
        ? 0.0
        : losingTrades.fold<double>(
            0,
            (sum, trade) => sum + ((trade.sellPrice! - trade.buyPrice) * trade.quantity),
          ) / losingTrades.length;

    // Calculate risk and reward
    final averageRisk = losingTrades.isEmpty
        ? 0.0
        : losingTrades.fold<double>(
            0,
            (sum, trade) => sum + (trade.buyPrice * trade.quantity),
          ) / losingTrades.length;

    final averageReward = winningTrades.isEmpty
        ? 0.0
        : winningTrades.fold<double>(
            0,
            (sum, trade) => sum + (trade.sellPrice! * trade.quantity),
          ) / winningTrades.length;

    final riskRewardRatio = averageRisk == 0 ? 0 : averageReward / averageRisk;

    // Calculate expectancy
    final winRate = winningTrades.length / closedTrades.length;
    final averageWinAmount = averageWin;
    final averageLossAmount = averageLoss.abs();
    final expectancy = (winRate * averageWinAmount) - ((1 - winRate) * averageLossAmount);

    // Other calculations remain the same...
    double largestWin = 0;
    double largestLoss = 0;
    if (winningTrades.isNotEmpty) {
      largestWin = winningTrades
          .map((t) => (t.sellPrice! - t.buyPrice) * t.quantity)
          .reduce((a, b) => a > b ? a : b);
    }
    if (losingTrades.isNotEmpty) {
      largestLoss = losingTrades
          .map((t) => (t.sellPrice! - t.buyPrice) * t.quantity)
          .reduce((a, b) => a < b ? a : b);
    }

    final totalWins = winningTrades.fold<double>(
      0,
      (sum, trade) => sum + ((trade.sellPrice! - trade.buyPrice) * trade.quantity),
    );
    final totalLosses = losingTrades.fold<double>(
      0,
      (sum, trade) => sum + ((trade.buyPrice - trade.sellPrice!) * trade.quantity),
    );
    final profitFactor = totalLosses == 0 ? 0 : (totalWins / totalLosses);

    final totalHoldingDays = closedTrades.fold<int>(
      0,
      (sum, trade) => sum + trade.sellDate!.difference(trade.date).inDays,
    );
    final averageHoldingDays = totalHoldingDays / closedTrades.length;

    int maxConsecutiveWins = 0;
    int maxConsecutiveLosses = 0;
    int currentConsecutiveWins = 0;
    int currentConsecutiveLosses = 0;

    for (final trade in closedTrades) {
      if (trade.sellPrice! > trade.buyPrice) {
        currentConsecutiveWins++;
        currentConsecutiveLosses = 0;
        if (currentConsecutiveWins > maxConsecutiveWins) {
          maxConsecutiveWins = currentConsecutiveWins;
        }
      } else if (trade.sellPrice! < trade.buyPrice) {
        currentConsecutiveLosses++;
        currentConsecutiveWins = 0;
        if (currentConsecutiveLosses > maxConsecutiveLosses) {
          maxConsecutiveLosses = currentConsecutiveLosses;
        }
      }
    }

    setState(() {
      _stats = {
        'winRate': winningTrades.length / closedTrades.length * 100,
        'hitRate': closedTrades.length / trades.length * 100,
        'edgeRatio': averageLoss == 0 ? 0 : (averageWin / averageLoss.abs()),
        'totalProfit': totalProfit,
        'averageWin': averageWin,
        'averageLoss': averageLoss,
        'largestWin': largestWin,
        'largestLoss': largestLoss,
        'profitFactor': profitFactor.toDouble(),
        'averageHoldingDays': averageHoldingDays,
        'consecutiveWins': maxConsecutiveWins.toDouble(),
        'consecutiveLosses': maxConsecutiveLosses.toDouble(),
        'expectancy': expectancy,
        'winningTrades': winningTrades.length.toDouble(),
        'losingTrades': losingTrades.length.toDouble(),
        'totalTrades': closedTrades.length.toDouble(),
        'averageRisk': averageRisk,
        'averageReward': averageReward,
        'riskRewardRatio': riskRewardRatio.toDouble(),
      };
    });
  }

  Future<void> _loadTrades() async {
    setState(() => _isLoading = true);
    try {
      final trades = await _storage.getTrades();
      final sortedTrades = _sortTrades(trades);
      setState(() {
        _trades.clear();
        _trades.addAll(sortedTrades);
        _calculateStats(trades); // Calculate stats on all trades, not just filtered
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading trades: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading trades: $e')),
        );
      }
    }
  }

  List<Trade> _sortTrades(List<Trade> trades) {
    final filteredTrades = _filterTicker != null
        ? trades.where((t) => t.ticker.toUpperCase() == _filterTicker!.toUpperCase()).toList()
        : trades;

    switch (_sortBy) {
      case 'date':
        filteredTrades.sort((a, b) => _sortAscending
            ? a.date.compareTo(b.date)
            : b.date.compareTo(a.date));
        break;
      case 'ticker':
        filteredTrades.sort((a, b) => _sortAscending
            ? a.ticker.compareTo(b.ticker)
            : b.ticker.compareTo(a.ticker));
        break;
      case 'profit':
        filteredTrades.sort((a, b) {
          final profitA = a.sellPrice != null ? a.sellPrice! - a.buyPrice : 0.0;
          final profitB = b.sellPrice != null ? b.sellPrice! - b.buyPrice : 0.0;
          return _sortAscending
              ? profitA.compareTo(profitB)
              : profitB.compareTo(profitA);
        });
        break;
    }
    return filteredTrades;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Ticker'),
        content: TextField(
          decoration: const InputDecoration(
            labelText: 'Ticker Symbol',
            hintText: 'Enter ticker (e.g., AAPL)',
          ),
          textCapitalization: TextCapitalization.characters,
          controller: TextEditingController(text: _filterTicker),
          onChanged: (value) {
            setState(() {
              _filterTicker = value.isEmpty ? null : value;
              _trades.clear();
              _loadTrades();
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _filterTicker = null;
                _trades.clear();
                _loadTrades();
              });
              Navigator.of(context).pop();
            },
            child: const Text('Clear Filter'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Trades'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Date'),
              value: 'date',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                  _trades.clear();
                  _loadTrades();
                });
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<String>(
              title: const Text('Ticker'),
              value: 'ticker',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                  _trades.clear();
                  _loadTrades();
                });
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<String>(
              title: const Text('Profit/Loss'),
              value: 'profit',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                  _trades.clear();
                  _loadTrades();
                });
                Navigator.of(context).pop();
              },
            ),
            SwitchListTile(
              title: const Text('Ascending Order'),
              value: _sortAscending,
              onChanged: (value) {
                setState(() {
                  _sortAscending = value;
                  _trades.clear();
                  _loadTrades();
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddTradeDialog() async {
    final result = await showDialog<Trade>(
      context: context,
      builder: (context) => const AddTradeDialog(),
    );

    if (result != null) {
      try {
        await _storage.addTrade(result);
        await _loadTrades(); // Refresh the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trade added successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding trade: $e')),
          );
        }
      }
    }
  }

  void _showEditTradeDialog(Trade trade) async {
    final result = await showDialog<Trade>(
      context: context,
      builder: (context) => AddTradeDialog(trade: trade),
    );

    if (result != null) {
      try {
        await _storage.updateTrade(result);
        await _loadTrades(); // Refresh the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trade updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating trade: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDelete(Trade trade) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trade'),
        content: Text('Are you sure you want to delete this ${trade.ticker} trade?'),
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
      try {
        await _storage.deleteTrade(trade.id);
        await _loadTrades(); // Refresh the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trade deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting trade: $e')),
          );
        }
      }
    }
  }

  Widget _buildStatsCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Trading Statistics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Total Trades: ${_stats['totalTrades']?.toInt()}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Win Rate',
                    '${_stats['winRate']?.toStringAsFixed(1)}%',
                    _stats['winRate']! >= 50 ? Colors.green : Colors.red,
                    Icons.analytics_rounded,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Hit Rate',
                    '${_stats['hitRate']?.toStringAsFixed(1)}%',
                    null,
                    Icons.percent_rounded,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Edge Ratio',
                    _stats['edgeRatio']?.toStringAsFixed(2) ?? '0',
                    _stats['edgeRatio']! >= 1 ? Colors.green : Colors.red,
                    Icons.show_chart_rounded,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total P/L',
                    NumberFormat.currency(symbol: '\$').format(_stats['totalProfit']),
                    _stats['totalProfit']! > 0 ? Colors.green : Colors.red,
                    Icons.account_balance_rounded,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Expectancy',
                    NumberFormat.currency(symbol: '\$').format(_stats['expectancy']),
                    _stats['expectancy']! > 0 ? Colors.green : Colors.red,
                    Icons.trending_flat_rounded,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Risk/Reward',
                    _stats['riskRewardRatio']?.toStringAsFixed(2) ?? '0',
                    _stats['riskRewardRatio']! >= 1 ? Colors.green : Colors.red,
                    Icons.balance_rounded,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Avg Win',
                    NumberFormat.currency(symbol: '\$').format(_stats['averageWin']),
                    Colors.green,
                    Icons.trending_up_rounded,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Avg Loss',
                    NumberFormat.currency(symbol: '\$').format(_stats['averageLoss']),
                    Colors.red,
                    Icons.trending_down_rounded,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Avg Hold Days',
                    _stats['averageHoldingDays']?.toStringAsFixed(1) ?? '0',
                    null,
                    Icons.calendar_today_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildAccountValueChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color? valueColor, IconData? icon) {
    String tooltip = '';
    switch (label) {
      case 'Win Rate':
        tooltip = 'Percentage of profitable trades out of all closed trades';
        break;
      case 'Hit Rate':
        tooltip = 'Percentage of closed trades out of all trades';
        break;
      case 'Edge Ratio':
        tooltip = 'Average win amount divided by average loss amount. Higher is better.';
        break;
      case 'Total P/L':
        tooltip = 'Total profit or loss across all closed trades';
        break;
      case 'Expectancy':
        tooltip = 'Average amount you can expect to win/lose per trade';
        break;
      case 'Risk/Reward':
        tooltip = 'Average reward divided by average risk. Higher than 1 means rewards exceed risks';
        break;
      case 'Avg Win':
        tooltip = 'Average profit amount from winning trades';
        break;
      case 'Avg Loss':
        tooltip = 'Average loss amount from losing trades';
        break;
      case 'Avg Hold Days':
        tooltip = 'Average number of days between buy and sell';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
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
      if (trade.sellPrice != null) {
        final profit = (trade.sellPrice! - trade.buyPrice) * trade.quantity;
        accountValue += profit;
        dataPoints.add(FlSpot(i.toDouble(), accountValue));
        dates.add(trade.sellDate!);
      }
    }

    if (dataPoints.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
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
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < dates.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('MMM dd').format(dates[value.toInt()]),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: JPBAppBar(
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: _showFilterDialog,
            tooltip: 'Filter Trades',
          ),
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            onPressed: _showSortDialog,
            tooltip: 'Sort Trades',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatsCard(),
                Expanded(
                  child: _trades.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _filterTicker != null
                                    ? 'No trades found for $_filterTicker'
                                    : 'No trades recorded yet. Add your first trade!',
                              ),
                              if (_filterTicker != null)
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _filterTicker = null;
                                      _loadTrades();
                                    });
                                  },
                                  child: const Text('Clear Filter'),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _trades.length,
                          itemBuilder: (context, index) {
                            final trade = _trades[index];
                            final hasProfit = trade.sellPrice != null && trade.sellPrice! > trade.buyPrice;
                            final hasLoss = trade.sellPrice != null && trade.sellPrice! < trade.buyPrice;
                            
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                title: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        trade.ticker,
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Buy: ${NumberFormat.currency(symbol: '\$').format(trade.buyPrice)} x ${trade.quantity}',
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Date: ${DateFormat('MMM dd, yyyy').format(trade.date)}'),
                                    Text('Setup: ${trade.setup}'),
                                    if (trade.sellPrice != null) ...[
                                      Text(
                                        'Sell: ${NumberFormat.currency(symbol: '\$').format(trade.sellPrice)}',
                                        style: TextStyle(
                                          color: hasProfit
                                              ? Colors.green
                                              : hasLoss
                                                  ? Colors.red
                                                  : null,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Sell Date: ${DateFormat('MMM dd, yyyy').format(trade.sellDate!)}',
                                      ),
                                    ],
                                    if (trade.notes.isNotEmpty)
                                      Text(
                                        'Notes: ${trade.notes}',
                                        style: const TextStyle(
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded),
                                      onPressed: () => _showEditTradeDialog(trade),
                                      tooltip: 'Edit Trade',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded),
                                      onPressed: () => _confirmDelete(trade),
                                      tooltip: 'Delete Trade',
                                      color: Colors.red,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTradeDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddTradeDialog extends StatefulWidget {
  final Trade? trade;

  const AddTradeDialog({
    super.key,
    this.trade,
  });

  @override
  State<AddTradeDialog> createState() => _AddTradeDialogState();
}

class _AddTradeDialogState extends State<AddTradeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _buyPriceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _setupController = TextEditingController();
  final _notesController = TextEditingController();
  final _tickerController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  DateTime? _selectedSellDate;
  bool _hasSold = false;

  @override
  void initState() {
    super.initState();
    if (widget.trade != null) {
      _tickerController.text = widget.trade!.ticker;
      _buyPriceController.text = widget.trade!.buyPrice.toStringAsFixed(2);
      _quantityController.text = widget.trade!.quantity.toString();
      _setupController.text = widget.trade!.setup;
      _notesController.text = widget.trade!.notes;
      _selectedDate = widget.trade!.date;
      if (widget.trade!.sellPrice != null) {
        _hasSold = true;
        _sellPriceController.text = widget.trade!.sellPrice!.toStringAsFixed(2);
        _selectedSellDate = widget.trade!.sellDate;
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isSellDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isSellDate ? _selectedSellDate ?? DateTime.now() : _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isSellDate) {
          _selectedSellDate = picked;
        } else {
          _selectedDate = picked;
        }
      });
    }
  }

  void _submitTrade() {
    if (_formKey.currentState!.validate()) {
      final trade = Trade(
        id: widget.trade?.id ?? const Uuid().v4(),
        date: _selectedDate,
        ticker: _tickerController.text.toUpperCase(),
        buyPrice: CurrencyInputFormatter.getNumericValue(_buyPriceController.text),
        quantity: int.parse(_quantityController.text),
        sellPrice: _hasSold
            ? CurrencyInputFormatter.getNumericValue(_sellPriceController.text)
            : null,
        setup: _setupController.text,
        notes: _notesController.text,
        sellDate: _hasSold ? _selectedSellDate : null,
      );

      Navigator.of(context).pop(trade);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.trade == null ? 'Add Trade' : 'Edit Trade',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Trade Date
                Card(
                  child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Trade Date',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('MMM dd, yyyy').format(_selectedDate),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Ticker and Buy Price Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tickerController,
                        decoration: InputDecoration(
                          labelText: 'Ticker Symbol',
                          hintText: 'e.g., AAPL',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _buyPriceController,
                        decoration: InputDecoration(
                          labelText: 'Buy Price',
                          prefixText: '\$ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [CurrencyInputFormatter()],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Quantity and Setup Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _setupController,
                        decoration: InputDecoration(
                          labelText: 'Setup',
                          hintText: 'e.g., Breakout',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Sold Switch
                Card(
                  child: SwitchListTile(
                    title: const Text('Sold?'),
                    subtitle: Text(
                      _hasSold ? 'Trade closed' : 'Trade still open',
                      style: TextStyle(
                        color: _hasSold ? Colors.green : Colors.grey,
                      ),
                    ),
                    value: _hasSold,
                    onChanged: (value) {
                      setState(() {
                        _hasSold = value;
                      });
                    },
                  ),
                ),
                if (_hasSold) ...[
                  const SizedBox(height: 16),
                  // Sell Date
                  Card(
                    child: InkWell(
                      onTap: () => _selectDate(context, true),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sell Date',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedSellDate != null
                                      ? DateFormat('MMM dd, yyyy').format(_selectedSellDate!)
                                      : 'Select date',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Sell Price
                  TextFormField(
                    controller: _sellPriceController,
                    decoration: InputDecoration(
                      labelText: 'Sell Price',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [CurrencyInputFormatter()],
                    validator: (value) {
                      if (_hasSold && (value == null || value.isEmpty)) {
                        return 'Required when sold';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Add any trade notes here...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _submitTrade,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: Text(widget.trade == null ? 'Add Trade' : 'Save Changes'),
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