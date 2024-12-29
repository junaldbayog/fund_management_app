import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/jpb_app_bar.dart';
import '../models/trade.dart';
import '../models/trading_setup.dart';
import '../utils/currency_input_formatter.dart';
import '../services/storage_service.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/trade_statistics.dart';

class TradingJournalScreen extends StatefulWidget {
  const TradingJournalScreen({super.key});

  @override
  State<TradingJournalScreen> createState() => _TradingJournalScreenState();
}

class _TradingJournalScreenState extends State<TradingJournalScreen> {
  final StorageService _storage = StorageService();
  final List<Trade> _trades = [];
  bool _isLoading = true;
  bool _showExpandedStats = false;
  String? _filterTicker;
  String _sortBy = 'date'; // 'date', 'ticker', 'profit'
  bool _sortAscending = false;
  double _totalInvestment = 0.0;
  Map<String, double> _stats = {
    'winRate': 0,
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
    'twrr': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadTrades();
  }

  void _calculateStats(List<Trade> trades) {
    _stats = TradeStatistics.calculateStats(trades, _totalInvestment);
  }

  Future<void> _loadTrades() async {
    setState(() => _isLoading = true);
    try {
      final trades = await _storage.getTrades();
      final sortedTrades = _sortTrades(trades);
      
      // Calculate total investment including initial investment and profits/losses
      double total = trades.fold<double>(
        0,
        (sum, trade) => sum + (trade.buyPrice * trade.quantity),
      );
      
      // Add profits/losses from closed trades
      final closedTrades = trades.where((t) => t.sellPrice != null);
      for (final trade in closedTrades) {
        final profit = trade.type == TradeType.long
          ? (trade.sellPrice! - trade.buyPrice) * trade.quantity
          : (trade.buyPrice - trade.sellPrice!) * trade.quantity;
        total += profit;
      }
      
      setState(() {
        _trades.clear();
        _trades.addAll(sortedTrades);
        _totalInvestment = total;
        _calculateStats(trades);
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
                Row(
                  children: [
                    Text(
                      'Total Trades: ${_stats['totalTrades']?.toInt()}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(_showExpandedStats ? Icons.expand_less : Icons.expand_more),
                      onPressed: () {
                        setState(() {
                          _showExpandedStats = !_showExpandedStats;
                        });
                      },
                      tooltip: _showExpandedStats ? 'Show less' : 'Show more',
                    ),
                  ],
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
                    'Edge Ratio',
                    _stats['edgeRatio']?.toStringAsFixed(2) ?? '0',
                    _stats['edgeRatio']! >= 1 ? Colors.green : Colors.red,
                    Icons.show_chart_rounded,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Total P/L',
                    NumberFormat.currency(symbol: '\$').format(_stats['totalProfit']),
                    _stats['totalProfit']! > 0 ? Colors.green : Colors.red,
                    Icons.account_balance_rounded,
                  ),
                ),
              ],
            ),
            if (_showExpandedStats) ...[
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
                      'Expectancy',
                      NumberFormat.currency(symbol: '\$').format(_stats['expectancy']),
                      _stats['expectancy']! > 0 ? Colors.green : Colors.red,
                      Icons.trending_flat_rounded,
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Risk/Reward',
                      _stats['riskRewardRatio']?.toStringAsFixed(2) ?? '0',
                      _stats['riskRewardRatio']! >= 1 ? Colors.green : Colors.red,
                      Icons.balance_rounded,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Largest Win',
                      NumberFormat.currency(symbol: '\$').format(_stats['largestWin']),
                      Colors.green,
                      Icons.arrow_circle_up_rounded,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Largest Loss',
                      NumberFormat.currency(symbol: '\$').format(_stats['largestLoss']),
                      Colors.red,
                      Icons.arrow_circle_down_rounded,
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Avg Hold Days',
                      _stats['averageHoldingDays']?.toStringAsFixed(1) ?? '0',
                      null,
                      Icons.calendar_today_rounded,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Consec. Wins',
                      _stats['consecutiveWins']?.toStringAsFixed(0) ?? '0',
                      Colors.green,
                      Icons.repeat_rounded,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Consec. Losses',
                      _stats['consecutiveLosses']?.toStringAsFixed(0) ?? '0',
                      Colors.red,
                      Icons.repeat_rounded,
                    ),
                  ),
                ],
              ),
            ],
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 2),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
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

    // Determine if PNL is negative
    final isPnlNegative = accountValue < 0;
    final chartColor = isPnlNegative ? Colors.red : Theme.of(context).colorScheme.primary;

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
              color: chartColor,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: chartColor.withOpacity(0.1),
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
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: trade.type == TradeType.long 
                                              ? Colors.blue.withOpacity(0.1)
                                              : Colors.purple.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                trade.type == TradeType.long 
                                                  ? Icons.arrow_upward 
                                                  : Icons.arrow_downward,
                                                size: 12,
                                                color: trade.type == TradeType.long 
                                                  ? Colors.blue
                                                  : Colors.purple,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                trade.type.name.toUpperCase(),
                                                style: TextStyle(
                                                  color: trade.type == TradeType.long 
                                                    ? Colors.blue
                                                    : Colors.purple,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Buy: ${NumberFormat.currency(symbol: '\$').format(trade.buyPrice)} x ${trade.quantity}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit_rounded),
                                              onPressed: () => _showEditTradeDialog(trade),
                                              tooltip: 'Edit Trade',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              iconSize: 20,
                                            ),
                                            const SizedBox(width: 12),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded),
                                              onPressed: () => _confirmDelete(trade),
                                              tooltip: 'Delete Trade',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              iconSize: 20,
                                              color: Colors.red,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Date: ${DateFormat('MMM dd, yyyy').format(trade.date)}',
                                                style: const TextStyle(fontSize: 13),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Setup: ${trade.setup}',
                                                style: const TextStyle(fontSize: 13),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (trade.sellPrice != null) ...[
                                          Text(
                                            'Sell: ${NumberFormat.currency(symbol: '\$').format(trade.sellPrice)}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: hasProfit
                                                  ? Colors.green
                                                  : hasLoss
                                                      ? Colors.red
                                                      : null,
                                            ),
                                          ),
                                        ] else ...[
                                          ElevatedButton.icon(
                                            onPressed: () => _showEditTradeDialog(trade),
                                            icon: const Icon(Icons.sell_rounded, size: 16),
                                            label: Text(
                                              trade.type == TradeType.long ? 'SELL' : 'COVER',
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (trade.notes.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Notes: ${trade.notes}',
                                        style: const TextStyle(
                                          fontStyle: FontStyle.italic,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    ],
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
  final _notesController = TextEditingController();
  final _tickerController = TextEditingController();
  final StorageService _storage = StorageService();
  DateTime _selectedDate = DateTime.now();
  DateTime? _selectedSellDate;
  bool _hasSold = false;
  TradeType _tradeType = TradeType.long;
  List<TradingSetup> _setups = [];
  TradingSetup? _selectedSetup;
  bool _isLoadingSetups = true;

  @override
  void initState() {
    super.initState();
    if (widget.trade != null) {
      _tickerController.text = widget.trade!.ticker;
      _buyPriceController.text = widget.trade!.buyPrice.toStringAsFixed(2);
      _quantityController.text = widget.trade!.quantity.toString();
      _notesController.text = widget.trade!.notes;
      _selectedDate = widget.trade!.date;
      _tradeType = widget.trade!.type;
      if (widget.trade!.sellPrice != null) {
        _hasSold = true;
        _sellPriceController.text = widget.trade!.sellPrice!.toStringAsFixed(2);
        _selectedSellDate = widget.trade!.sellDate;
      }
    }
    _loadSetups();
  }

  Future<void> _loadSetups() async {
    try {
      final setups = await _storage.getTradingSetups();
      setState(() {
        _setups = setups.where((s) => s.isActive).toList();
        _isLoadingSetups = false;
        if (widget.trade != null) {
          // Find the matching setup or use the first one if available
          _selectedSetup = _setups
              .where((s) => s.name == widget.trade!.setup)
              .firstOrNull ?? (_setups.isNotEmpty ? _setups.first : null);
        }
      });
    } catch (e) {
      print('Error loading setups: $e');
      setState(() => _isLoadingSetups = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading setups: $e')),
        );
      }
    }
  }

  void _showSetupRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trading Setups Required'),
        content: const Text(
          'You need to define at least one trading setup before adding trades.\n\n'
          'Go to Menu → Settings → Trading Setups to add your setups.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
    if (_setups.isEmpty) {
      _showSetupRequiredDialog();
      return;
    }

    if (_selectedSetup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a trading setup')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      // Validate dates
      String? dateError;
      
      // Normalize dates to start of day for comparison
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final tradeDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      
      if (tradeDate.isAfter(todayStart)) {
        dateError = 'Trade date cannot be in the future';
      }

      if (_hasSold) {
        if (_selectedSellDate == null) {
          dateError = _tradeType == TradeType.long 
            ? 'Please select a sell date'
            : 'Please select a cover date';
        } else {
          final sellDate = DateTime(_selectedSellDate!.year, _selectedSellDate!.month, _selectedSellDate!.day);
          if (sellDate.isAfter(todayStart)) {
            dateError = _tradeType == TradeType.long 
              ? 'Sell date cannot be in the future'
              : 'Cover date cannot be in the future';
          } else if (sellDate.isBefore(tradeDate)) {
            dateError = _tradeType == TradeType.long 
              ? 'Sell date cannot be before the trade date'
              : 'Cover date cannot be before the entry date';
          }
        }
      }

      if (dateError != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Invalid Date'),
            content: Text(dateError!),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      final trade = Trade(
        id: widget.trade?.id ?? const Uuid().v4(),
        date: _selectedDate,
        ticker: _tickerController.text.toUpperCase(),
        buyPrice: double.parse(_buyPriceController.text),
        quantity: int.parse(_quantityController.text),
        sellPrice: _hasSold
            ? double.parse(_sellPriceController.text)
            : null,
        setup: _selectedSetup!.name,
        notes: _notesController.text,
        sellDate: _hasSold ? _selectedSellDate : null,
        type: _tradeType,
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
                // Trade Type
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Trade Type',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<TradeType>(
                          segments: const [
                            ButtonSegment<TradeType>(
                              value: TradeType.long,
                              label: Text('LONG'),
                              icon: Icon(Icons.arrow_upward),
                            ),
                            ButtonSegment<TradeType>(
                              value: TradeType.short,
                              label: Text('SHORT'),
                              icon: Icon(Icons.arrow_downward),
                            ),
                          ],
                          selected: {_tradeType},
                          onSelectionChanged: (Set<TradeType> selected) {
                            setState(() {
                              _tradeType = selected.first;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                        onChanged: (value) {
                          if (value != value.toUpperCase()) {
                            _tickerController.value = _tickerController.value.copyWith(
                              text: value.toUpperCase(),
                              selection: TextSelection.collapsed(offset: value.length),
                            );
                          }
                        },
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
                          labelText: _tradeType == TradeType.long ? 'Buy Price' : 'Sell Price',
                          prefixText: '\$ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final number = double.tryParse(value);
                          if (number == null) {
                            return 'Enter a valid number';
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
                      child: _isLoadingSetups
                          ? const Center(child: CircularProgressIndicator())
                          : DropdownButtonFormField<TradingSetup>(
                              value: _selectedSetup,
                              decoration: InputDecoration(
                                labelText: 'Setup',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                              ),
                              items: _setups.map((setup) {
                                return DropdownMenuItem(
                                  value: setup,
                                  child: Text(setup.name),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedSetup = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
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
                    title: Text(_tradeType == TradeType.long ? 'Sold?' : 'Covered?'),
                    subtitle: Text(
                      _hasSold 
                        ? _tradeType == TradeType.long ? 'Trade closed' : 'Position covered'
                        : _tradeType == TradeType.long ? 'Trade still open' : 'Position still open',
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
                            Text(
                              _tradeType == TradeType.long ? 'Sell Date' : 'Cover Date',
                              style: const TextStyle(
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
                      labelText: _tradeType == TradeType.long ? 'Sell Price' : 'Cover Price',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    validator: (value) {
                      if (_hasSold && (value == null || value.isEmpty)) {
                        return 'Required when sold';
                      }
                      if (_hasSold) {
                        final number = double.tryParse(value!);
                        if (number == null) {
                          return 'Enter a valid number';
                        }
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