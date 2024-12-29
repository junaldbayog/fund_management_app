import '../models/trade.dart';
import 'dart:math';

class TradeStatistics {
  static Map<String, double> calculateStats(List<Trade> trades, double totalInvestment) {
    if (trades.isEmpty) {
      return _getEmptyStats();
    }

    final closedTrades = trades.where((t) => t.sellPrice != null).toList();
    if (closedTrades.isEmpty) {
      return _getEmptyStats();
    }

    // Calculate profit based on trade type
    double calculateProfit(Trade trade) {
      if (trade.type == TradeType.long) {
        return (trade.sellPrice! - trade.buyPrice) * trade.quantity;
      } else {
        return (trade.buyPrice - trade.sellPrice!) * trade.quantity;
      }
    }

    final winningTrades = closedTrades.where((t) {
      if (t.type == TradeType.long) {
        return t.sellPrice! > t.buyPrice;
      } else {
        return t.sellPrice! < t.buyPrice;
      }
    }).toList();

    final losingTrades = closedTrades.where((t) {
      if (t.type == TradeType.long) {
        return t.sellPrice! < t.buyPrice;
      } else {
        return t.sellPrice! > t.buyPrice;
      }
    }).toList();

    final totalProfit = closedTrades.fold<double>(
      0,
      (sum, trade) => sum + calculateProfit(trade),
    );

    final averageWin = winningTrades.isEmpty
        ? 0.0
        : winningTrades.fold<double>(
            0,
            (sum, trade) => sum + calculateProfit(trade),
          ) / winningTrades.length;

    final averageLoss = losingTrades.isEmpty
        ? 0.0
        : losingTrades.fold<double>(
            0,
            (sum, trade) => sum + calculateProfit(trade),
          ) / losingTrades.length;

    // Calculate largest win/loss
    double largestWin = 0;
    double largestLoss = 0;
    if (winningTrades.isNotEmpty) {
      largestWin = winningTrades
          .map((t) => calculateProfit(t))
          .reduce((a, b) => max(a, b));
    }
    if (losingTrades.isNotEmpty) {
      largestLoss = losingTrades
          .map((t) => calculateProfit(t))
          .reduce((a, b) => min(a, b));
    }

    // Calculate holding days
    final totalHoldingDays = closedTrades.fold<int>(
      0,
      (sum, trade) => sum + (trade.sellDate?.difference(trade.date).inDays ?? 0),
    );
    final averageHoldingDays = closedTrades.isEmpty ? 0.0 : totalHoldingDays / closedTrades.length;

    // Calculate consecutive wins/losses
    int maxConsecutiveWins = 0;
    int maxConsecutiveLosses = 0;
    int currentConsecutiveWins = 0;
    int currentConsecutiveLosses = 0;

    for (final trade in closedTrades) {
      final isWinningTrade = trade.type == TradeType.long 
          ? trade.sellPrice! > trade.buyPrice
          : trade.sellPrice! < trade.buyPrice;

      if (isWinningTrade) {
        currentConsecutiveWins++;
        currentConsecutiveLosses = 0;
        if (currentConsecutiveWins > maxConsecutiveWins) {
          maxConsecutiveWins = currentConsecutiveWins;
        }
      } else {
        currentConsecutiveLosses++;
        currentConsecutiveWins = 0;
        if (currentConsecutiveLosses > maxConsecutiveLosses) {
          maxConsecutiveLosses = currentConsecutiveLosses;
        }
      }
    }

    // Calculate TWRR
    double twrr = 0.0;
    if (closedTrades.isNotEmpty && totalInvestment > 0) {
      final sortedTrades = List<Trade>.from(closedTrades)..sort((a, b) => a.date.compareTo(b.date));
      
      List<double> subPeriodReturns = [];
      double periodStartValue = totalInvestment;
      
      for (final trade in sortedTrades) {
        if (trade.sellPrice != null && trade.sellDate != null) {
          final profit = calculateProfit(trade);
          final periodEndValue = periodStartValue + profit;
          
          if (periodStartValue > 0) {
            final periodReturn = (periodEndValue - periodStartValue) / periodStartValue;
            subPeriodReturns.add(1 + periodReturn);
          }
          
          periodStartValue = periodEndValue;
        }
      }
      
      if (subPeriodReturns.isNotEmpty) {
        final linkedReturn = subPeriodReturns.reduce((a, b) => a * b);
        twrr = (linkedReturn - 1) * 100;
      }
    }

    final winRate = winningTrades.length / closedTrades.length;
    final hitRate = closedTrades.length / trades.length * 100;
    final expectancy = (winRate * averageWin) - ((1 - winRate) * averageLoss.abs());
    final profitFactor = averageLoss == 0 ? 0.0 : (averageWin / averageLoss.abs());

    return {
      'winRate': winRate * 100,
      'hitRate': hitRate,
      'edgeRatio': averageLoss == 0 ? 0 : (averageWin / averageLoss.abs()),
      'totalProfit': totalProfit,
      'averageWin': averageWin,
      'averageLoss': averageLoss,
      'largestWin': largestWin,
      'largestLoss': largestLoss,
      'profitFactor': profitFactor,
      'averageHoldingDays': averageHoldingDays,
      'consecutiveWins': maxConsecutiveWins.toDouble(),
      'consecutiveLosses': maxConsecutiveLosses.toDouble(),
      'expectancy': expectancy,
      'winningTrades': winningTrades.length.toDouble(),
      'losingTrades': losingTrades.length.toDouble(),
      'totalTrades': closedTrades.length.toDouble(),
      'averageRisk': averageLoss.abs(),
      'averageReward': averageWin,
      'riskRewardRatio': averageLoss == 0 ? 0 : (averageWin / averageLoss.abs()),
      'twrr': twrr,
    };
  }

  static Map<String, double> _getEmptyStats() {
    return {
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
      'twrr': 0,
    };
  }
} 