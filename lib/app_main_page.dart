import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lesna_app_1/screens/powierzchnia_model.dart';
import 'connector/bluetooth_device.dart';
import 'screens/powierzchnia_details.dart';
import '../data_handler/data_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';


class AppMainScreen extends StatefulWidget {
  const AppMainScreen({super.key});

  @override
  State<AppMainScreen> createState() => _AppMainScreenState();
}

class _AppMainScreenState extends State<AppMainScreen> {
  // --- 1. FIELDS & CONTROLLERS ---

  List<PowierzchniaModel> _powierzchnie = [];


  bool _isLoading = false; // Set to false so it doesn't spin on startup
  final TextEditingController _numerController = TextEditingController();
  final TextEditingController _adresController = TextEditingController();
  final DataHandler _dataHandler = DataHandler();

  // --- Bluetooth State & UUIDs ---
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false; // Tracks if the user is currently typing

  List<Map<String, dynamic>> _allNumPp = [];
  List<Map<String, dynamic>> _filteredNumPp = [];

  @override
  void dispose() {
    _searchController.dispose();
    _numerController.dispose();
    _adresController.dispose();
    _scanSubscription?.cancel();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadJsonData();
    // Removed _loadDataFromHandler() so it waits for the "Wczytaj" button
  }

  Future<void> _loadJsonData() async {
    // Call the method you created in data_handler.dart
    final loadedNums = await _dataHandler.loadNumPpFromJson();

    // Update the UI state once the data is loaded
    if (mounted) {
      setState(() {
        _allNumPp = loadedNums;
      });
    }
  }

  // Reads all three files from memory and updates the UI
  Future<void> _loadDataFromHandler() async {
    setState(() {
      _isLoading = true; // Show loading indicator while reading
    });

    try {
      // 1. Load only the surfaces, which now automatically include all their nested trees
      final loadedPowierzchnie = await _dataHandler.loadPowierzchnie();

      setState(() {
        _powierzchnie = loadedPowierzchnie;

        // You no longer need to set _drzewa or _drzewaMartwe here.
        // Make sure to delete the List<DrzewoModel> _drzewa and _drzewaMartwe
        // variable declarations from the top of your _AppMainScreenState class entirely!
      });
    } catch (e) {
      print('Error loading data in UI: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }



  // Deletes a single item by its index
  Future<void> _deletePowierzchnia(int index) async {
    setState(() {
      _powierzchnie.removeAt(index);
    });

    await _dataHandler.savePowierzchnie(_powierzchnie);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Usunięto powierzchnię.')),
    );
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
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
        // Import ZIP button using DataHandler directly
        // IconButton(
        //   icon: const Icon(Icons.folder_zip),
        //   tooltip: 'Importuj ZIP',
        //   onPressed: () async {
        //     bool success = await _dataHandler.pickAndImportDatabase();
        //     if (success) {
        //       ScaffoldMessenger.of(context).showSnackBar(
        //         const SnackBar(content: Text('Baza danych została pomyślnie zaimportowana!')),
        //       );
        //       _handleRefresh(); // Reloads the UI data
        //     }
        //   },
        // ),
        IconButton(
          icon: const Icon(Icons.data_object), // Using a JSON-appropriate icon
          tooltip: 'Importuj JSON',
          onPressed: () async {
            bool success = await _dataHandler.pickAndImportJson();
            if (success) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Plik JSON został pomyślnie zaimportowany!')),
                );
              }
              _handleRefresh(); // Reloads the UI data
            }
          },
        ),

        TextButton.icon(
          onPressed: _handleRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Wczytaj'),
        ),
        // ... your export button ...
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
    return Column(
      children: [
        // 1. The Search Window at the top
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: (query) {
              setState(() {
                _isSearching = query.isNotEmpty;
                if (_isSearching) {
                  _filteredNumPp = _allNumPp
                      .where((item) => item['num_pp'].toString().startsWith(query))
                      .toList();
                }
              });
            },
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Szukaj num_pp w bazie...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              // Use clear button to reset the view back to _powierzchnie
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _isSearching = false;
                    _filteredNumPp.clear();
                  });
                  FocusScope.of(context).unfocus(); // Close keyboard
                },
              )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        // 2. The Dynamic Content Below
        Expanded(
          child: _isSearching
              ? _buildSearchResults()     // Show JSON suggestions if typing
              : _buildPowierzchnieList(), // Show normal data if not typing
        ),
      ],
    );
  }

  // Helper: Renders the search results from JSON
  Widget _buildSearchResults() {
    return ListView.builder(
      itemCount: _filteredNumPp.length,
      itemBuilder: (context, index) {
        final item = _filteredNumPp[index];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: Text(
              'num_pp: ${item['num_pp']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.deepPurple),
              // 1. Trigger the dialog when the + icon is pressed
              onPressed: () {
                // If your dialog needs to know WHICH item was clicked, pass the item data:
                // _showAddPowierzchniaDialog(item['num_pp']);
                _showAddPowierzchniaDialog(item);
              },
            ),
            // 2. Optional: Trigger the dialog if the user taps anywhere on the row
            onTap: () {
              _showAddPowierzchniaDialog(item); // Passes the chosen surface number and its background data
            },
          ),
        );
      },
    );
  }

// Helper: Your original logic for existing powierzchnie
  Widget _buildPowierzchnieList() {
    if (_powierzchnie.isEmpty) {
      return const Center(
        child: Text(
          'Brak danych. Kliknij "Wczytaj" lub + aby dodać.',
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
                powierzchnia: _powierzchnie[index], // This now contains its own list of trees
                onUpdate: () async {
                  setState(() {});
                  // Only one save call is needed now
                  await _dataHandler.savePowierzchnie(_powierzchnie);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomActionsRow() {
    bool isConnected = BleConnector.isConnected;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.extended(
          onPressed: () async {
            if (isConnected) {
              await BleConnector.disconnect();
              setState(() {});
            } else {
              await BleConnector.connect(context);
              setState(() {});
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

  void _showAddPowierzchniaDialog([Map<String, dynamic>? selectedData]) {
    // Pre-fill the controller if data was passed from the list
    final TextEditingController numerController = TextEditingController(
      text: selectedData != null ? selectedData['num_pp'].toString() : '',
    );

    final TextEditingController adresController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Nowa powierzchnia'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numerController,
                decoration: const InputDecoration(
                  labelText: 'Numer',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: adresController,
                decoration: const InputDecoration(
                  labelText: 'Adres leśny (opcjonalny)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () async {
                final String parsedNumer = numerController.text.trim();

                if (parsedNumer.isEmpty) {
                  return;
                }

                // 1. Check if surface already exists in the loaded memory
                int existingIndex = _powierzchnie.indexWhere((p) => p.numer == parsedNumer);
                PowierzchniaModel currentPowierzchnia;

                if (existingIndex >= 0) {
                  // If it exists, use the existing one to avoid duplicates
                  currentPowierzchnia = _powierzchnie[existingIndex];
                } else {
                  // If it is new, create the object, add to state, and save to internal file
                  currentPowierzchnia = PowierzchniaModel(
                    numer: parsedNumer,
                    adres: adresController.text.trim(),
                    wydz_data: selectedData ?? <String, dynamic>{},
                  );

                  setState(() {
                    _powierzchnie.add(currentPowierzchnia);
                  });

                  // Write the updated list to the internal file (powierzchnie.json)
                  await _dataHandler.savePowierzchnie(_powierzchnie);
                }

                // 2. Close the dialog
                if (!context.mounted) return;
                Navigator.of(context).pop();

                // 3. Navigate to the detail screen
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PowierzchniaDetailScreen(
                      powierzchnia: currentPowierzchnia,
                      // The _drzewa and _drzewaMartwe parameters have been removed here
                      onUpdate: () async {
                        setState(() {});
                        // Save only Powierzchnie, which automatically saves all nested trees
                        await _dataHandler.savePowierzchnie(_powierzchnie);
                      },
                    ),
                  ),
                );
              },
              child: const Text('Dodaj'),
            )
          ],
        );
      },
    );
  }
}