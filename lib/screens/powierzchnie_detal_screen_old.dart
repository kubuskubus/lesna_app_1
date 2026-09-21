import 'package:flutter/material.dart';
import 'powierzchnia_details.dart';
import 'powierzchnia_model.dart';
import '../data_handler/data_handler.dart';

class PowierzchnieScreen extends StatefulWidget {
  const PowierzchnieScreen({super.key});

  @override
  State<PowierzchnieScreen> createState() => _PowierzchnieScreenState();
}

class _PowierzchnieScreenState extends State<PowierzchnieScreen> {
  // --- 1. FIELDS & CONTROLLERS ---
  final List<PowierzchniaModel> _powierzchnie = [];
  final TextEditingController _numerController = TextEditingController();
  final TextEditingController _adresController = TextEditingController();
  final DataHandler _dataHandler = DataHandler();

  @override
  void initState() {
    super.initState();
    // Automatically load data when the main screen opens
    _loadDataFromHandler();
  }

  // Async method to handle reading from memory and updating the UI
  Future<void> _loadDataFromHandler() async {
    try {
      final loadedData = await _dataHandler.loadSavedData();
      setState(() {
        _powierzchnie.clear();
        _powierzchnie.addAll(loadedData);
      });
    } catch (e) {
      print('Error loading data in UI: $e');
    }
  }

  // Deletes a single item by its index
  Future<void> _deletePowierzchnia(int index) async {
    setState(() {
      _powierzchnie.removeAt(index);
    });

    // Save the updated list back to local memory
    await _dataHandler.saveDataLocally(_powierzchnie);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Usunięto powierzchnię.')),
    );
  }

  @override
  void dispose() {
    _numerController.dispose();
    _adresController.dispose();
    super.dispose();
  }

  // --- 3. UI BUILD & LAYOUT METHODS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(), // Only the Add button is needed here
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // Button action to read values from memory manually
  void _handleRefresh() async {
    await _loadDataFromHandler();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wczytano dane z pamięci.')),
    );
  }

  // 2. UI Builder
  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Powierzchnie próbne'),
      actions: [
        TextButton.icon(
          onPressed: _handleRefresh,
          icon: const Icon(Icons.refresh, size: 18, color: Colors.deepPurple),
          label: const Text(
            'Wczytaj',
            style: TextStyle(color: Colors.deepPurple),
          ),
        ),
        TextButton(
          onPressed: () {},
          child: const Text(
            'Eksport XML',
            style: TextStyle(color: Colors.deepPurple),
          ),
        ),
      ],
    );
  }

  // --- 1. UI BUILDERS (Separate from Logic) ---

  Widget _buildBody() {
    if (_powierzchnie.isEmpty) {
      return const Center(
        child: Text(
          'Brak powierzchni. Kliknij + aby dodać.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: _powierzchnie.length,
      itemBuilder: (context, index) {
        final item = _powierzchnie[index];
        return _buildPowierzchniaItem(item, index);
      },
    );
  }

  // Separate widget builder for a single list item
  Widget _buildPowierzchniaItem(PowierzchniaModel item, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text('Powierzchnia ${item.numer}'),
        subtitle: item.adres.isNotEmpty ? Text('Adres: ${item.adres}') : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Usuń',
              onPressed: () => _deletePowierzchnia(index),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PowierzchniaDetailScreen(
                powierzchnia: item,
                onUpdate: () async {
                  setState(() {});
                  // Save the full list of surfaces to memory whenever an update occurs
                  await _dataHandler.saveDataLocally(_powierzchnie);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _showAddPowierzchniaDialog,
      child: const Icon(Icons.add),
    );
  }

  void _showAddPowierzchniaDialog() {
    _numerController.clear();
    _adresController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nowa powierzchnia'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _numerController,
                decoration: InputDecoration(
                  labelText: 'Numer',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _adresController,
                decoration: InputDecoration(
                  labelText: 'Adres leśny (opcjonalny)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.black87,
              ),
              onPressed: () async {
                if (_numerController.text.isNotEmpty) {
                  setState(() {
                    _powierzchnie.add(
                      PowierzchniaModel(
                        numer: _numerController.text,
                        adres: _adresController.text,
                      ),
                    );
                  });

                  // Save locally via the DataHandler instance
                  await _dataHandler.saveDataLocally(_powierzchnie);
                  Navigator.pop(context);
                }
              },
              child: const Text('Zapisz'),
            ),
          ],
        );
      },
    );
  }
}