import 'package:flutter/material.dart';
import '../models/trading_setup.dart';
import '../services/storage_service.dart';
import 'package:uuid/uuid.dart';

class TradingSetupsScreen extends StatefulWidget {
  const TradingSetupsScreen({super.key});

  @override
  State<TradingSetupsScreen> createState() => _TradingSetupsScreenState();
}

class _TradingSetupsScreenState extends State<TradingSetupsScreen> {
  final StorageService _storage = StorageService();
  List<TradingSetup> _setups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSetups();
  }

  Future<void> _loadSetups() async {
    setState(() => _isLoading = true);
    try {
      final setups = await _storage.getTradingSetups();
      setState(() {
        _setups = setups;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading setups: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading setups: $e')),
        );
      }
    }
  }

  Future<void> _showSetupDialog([TradingSetup? setup]) async {
    final nameController = TextEditingController(text: setup?.name);
    final descriptionController = TextEditingController(text: setup?.description);
    bool isActive = setup?.isActive ?? true;

    final result = await showDialog<TradingSetup>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(setup == null ? 'Add Trading Setup' : 'Edit Trading Setup'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g., Breakout',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe your trading setup...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active'),
                  subtitle: Text(
                    isActive ? 'Setup is available for use' : 'Setup is archived',
                  ),
                  value: isActive,
                  onChanged: (value) {
                    setState(() => isActive = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.isEmpty) {
                  return;
                }

                final newSetup = TradingSetup(
                  id: setup?.id ?? const Uuid().v4(),
                  name: nameController.text,
                  description: descriptionController.text,
                  isActive: isActive,
                );

                Navigator.pop(context, newSetup);
              },
              child: Text(setup == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        if (setup == null) {
          await _storage.addTradingSetup(result);
        } else {
          await _storage.updateTradingSetup(result);
        }
        await _loadSetups();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving setup: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDelete(TradingSetup setup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Setup'),
        content: Text('Are you sure you want to delete "${setup.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _storage.deleteTradingSetup(setup.id);
        await _loadSetups();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Setup deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting setup: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trading Setups'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _setups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No trading setups yet'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _showSetupDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Setup'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _setups.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final setup = _setups[index];
                    return Card(
                      child: ListTile(
                        title: Text(
                          setup.name,
                          style: TextStyle(
                            color: setup.isActive ? null : Colors.grey,
                          ),
                        ),
                        subtitle: setup.description.isNotEmpty
                            ? Text(
                                setup.description,
                                style: TextStyle(
                                  color: setup.isActive ? null : Colors.grey,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showSetupDialog(setup),
                              tooltip: 'Edit Setup',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _confirmDelete(setup),
                              tooltip: 'Delete Setup',
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSetupDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
} 