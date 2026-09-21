import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lesna_app_1/screens/powierzchnia_model.dart';
import 'connector/bluetooth_device.dart';
import 'connector/bluetooth_service.dart';
import 'screens/powierzchnia_details.dart';
import '../data_handler/data_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

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

  // --- Bluetooth State & UUIDs ---
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  final Guid serviceUuid = Guid("6e400001-b5a3-f393-e0a9-e50e24dcca9e");
  final Guid txUuid = Guid("6e400002-b5a3-f393-e0a9-e50e24dcca9e");
  final Guid rxUuid = Guid("6e400003-b5a3-f393-e0a9-e50e24dcca9e");

  @override
  void initState() {
    super.initState();
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

    await _dataHandler.saveDataLocally(_powierzchnie);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Usunięto powierzchnię.')),
    );
  }

  @override
  void dispose() {
    _numerController.dispose();
    _adresController.dispose();
    _scanSubscription?.cancel();
    super.dispose();
  }

  // --- BLUETOOTH PERMISSIONS & CONNECTION ---
  Future<void> _requestBluetoothPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }



  // --- 3. UI BUILD & LAYOUT METHODS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildBottomActionsRow(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _handleRefresh() async {
    await _loadDataFromHandler();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wczytano dane z pamięci.')),
    );
  }

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
                  await _dataHandler.saveDataLocally(_powierzchnie);
                },
              ),
            ),
          );
        },
      ),
    );
  }


// Inside your _PowierzchnieScreenState:
  Widget _buildBottomActionsRow() {
    // Rely solely on BleConnector
    bool isConnected = BleConnector.isConnected;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.extended(
          onPressed: () async {
            if (isConnected) {
              await BleConnector.disconnect();
              setState(() {}); // Odśwież UI po rozłączeniu
            } else {
              await BleConnector.connect(context);
              setState(() {}); // Odśwież UI po połączeniu
            }
          },
          icon: Icon(
            Icons.bluetooth,
            color: isConnected ? Colors.green.shade800 : Colors.black87,
          ),
          label: Text(
            isConnected ? 'Rozłącz' : 'Klupa (BLE)',
          ),
          backgroundColor: isConnected ? Colors.green[300] : Colors.green[100],
        ),
        const SizedBox(width: 12),
        FloatingActionButton(
          onPressed: _showAddPowierzchniaDialog,
          child: const Icon(Icons.add),
        ),
      ],
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