import 'package:flutter/material.dart';
import '../widgets/jpb_app_bar.dart';

class TradingJournalScreen extends StatelessWidget {
  const TradingJournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const JPBAppBar(showBackButton: false),
      body: const Center(
        child: Text('Trading Journal Screen'),
      ),
    );
  }
} 