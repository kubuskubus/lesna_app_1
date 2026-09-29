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

  List<PowierzchniaModel> _powierzchnieList = [];


  bool _isLoading = false; // Set to false so it doesn't spin on startup
  final TextEditingController _numerController = TextEditingController();
  final TextEditingController _adresController = TextEditingController();
  final DataHandler _dataHandler = DataHandler();

  // --- Bluetooth State & UUIDs ---
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false; // Tracks if the user is currently typing

// Change these at the top of _AppMainScreenState
  List<WydzielenieModel> _allNumPp = [];
  List<WydzielenieModel> _filteredNumPp = [];

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
    _loadDataFromHandler(); // <-- Add this to load memory on startup
    // Removed _loadDataFromHandler() so it waits for the "Wczytaj" button
  }

  Future<void> _loadJsonData() async {
    if (_dataHandler.wydzList.isEmpty) {
      await _dataHandler.loadData();
    }

    if (mounted) {
      setState(() {
        // Assign directly, no Map conversion needed
        _allNumPp = _dataHandler.wydzList;
        _filteredNumPp = _allNumPp; // Initialize the filtered list
      });
    }
  }

  // Reads all three files from memory and updates the UI
  Future<void> _loadDataFromHandler() async {
    setState(() {
      _isLoading = true; // Show loading indicator while reading
    });

    try {
      // 1. Call the unified load method that reads both lists
      await _dataHandler.loadData();

      if (mounted) {
        setState(() {
          // 2. Fetch the mutable list directly from the handler
          _powierzchnieList = _dataHandler.powierzchnie;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }



  // Deletes a single item by its index
  Future<void> _deletePowierzchnia(int index) async {
    setState(() {
      // 1. Remove the item directly from the DataHandler's master list
      _dataHandler.powierzchnie.removeAt(index);

      // 2. Sync your local UI list with the handler's list
      _powierzchnieList = _dataHandler.powierzchnie;
    });

    // 3. Call save with NO arguments
    await _dataHandler.savePowierzchnie();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usunięto powierzchnię.')),
      );
    }
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
        // NEW: Format Button
        IconButton(
          icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
          tooltip: 'Formatuj pamięć',
          onPressed: _showFormatDialog,
        ),
        IconButton(
          icon: const Icon(Icons.data_object),
          tooltip: 'Nadpisz plik JSON',
          onPressed: () async {
            // Pass the exact name of the file you want to overwrite in memory
            bool success = await _dataHandler.mergeOrInitExternalFile('powierzchnie.json');
            if (success) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Plik JSON został pomyślnie nadpisany!')),
                );
              }
              _handleRefresh(); // Reloads the UI data from the newly overwritten file
            }
          },
        ),
        TextButton(
          onPressed: () async {
            bool success = await _dataHandler.exportPowierzchnieJson();

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success
                      ? 'Plik JSON został pomyślnie wyeksportowany!'
                      : 'Anulowano eksport lub plik nie istnieje.'),
                ),
              );
            }
          },
          child: const Text(
            'Eksport JSON',
            style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
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
                      .where((item) => item.numPp.startsWith(query))
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
              'num_pp: ${item.numPp}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Adres leśny: ${item.adressLes}'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () {
              // 1. Check if this surface is already active in your DataHandler
              int existingIndex = _dataHandler.powierzchnie.indexWhere((p) => p.numer == item.numPp);

              if (existingIndex >= 0) {
                // Surface exists, load it and navigate
                PowierzchniaModel currentPowierzchnia = _dataHandler.powierzchnie[existingIndex];

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PowierzchniaDetailScreen(
                      powierzchnia: currentPowierzchnia,
                      wydzData: item, // Pass the read-only reference data
                      onUpdate: () async {
                        setState(() {});
                        await _dataHandler.savePowierzchnie();
                      },
                    ),
                  ),
                );
              } else {
                // Surface is not active, prompt the user to use the + button
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Powierzchnia ${item.numPp} nie została dodana. Użyj przycisku +, aby ją utworzyć.'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

// Helper: Your original logic for existing powierzchnie
  Widget _buildPowierzchnieList() {
    if (_powierzchnieList.isEmpty) {
      return const Center(
        child: Text(
          'Brak danych. Kliknij "Wczytaj" lub + aby dodać.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: _powierzchnieList.length,
      itemBuilder: (context, index) {
        final item = _powierzchnieList[index];
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
          // 1. Znajdź dopasowane dane "tylko do odczytu" w DataHandler
          int wydzIndex = _dataHandler.wydzList.indexWhere((w) => w.numPp == item.numer);
          WydzielenieModel? matchingWydz = wydzIndex >= 0
              ? _dataHandler.wydzList[wydzIndex]
              : null;

          // 2. Przejdź do ekranu i przekaż oba modele
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PowierzchniaDetailScreen(
                powierzchnia: _powierzchnieList[index],
                wydzData: matchingWydz, // <-- Przekazanie danych tylko do odczytu
                onUpdate: () async {
                  setState(() {});
                  await _dataHandler.savePowierzchnie();
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
      ],
    );
  }

  void _showEditPowierzchniaDialog(WydzielenieModel? item) {
    // 1. Zmieniono 'selectedData' na 'item' oraz użyto notacji obiektowej (item.numPp)
    final TextEditingController numerController = TextEditingController(
      text: item != null ? item.numPp : '',
    );

    // Dodatkowo: automatycznie pre-wypełnia adres leśny jeśli jest dostępny
    final TextEditingController adresController = TextEditingController(
      text: item != null ? item.adressLes : '',
    );

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

                // Update state using the master list in DataHandler
                int existingIndex = _dataHandler.powierzchnie.indexWhere((p) => p.numer == parsedNumer);
                PowierzchniaModel currentPowierzchnia;

                if (existingIndex >= 0) {
                  currentPowierzchnia = _dataHandler.powierzchnie[existingIndex];
                } else {
                  // 2. Usunięto argument wydz_data, ponieważ usunęliśmy go z PowierzchniaModel
                  currentPowierzchnia = PowierzchniaModel(
                    numer: parsedNumer,
                    adres: adresController.text.trim(),
                  );

                  setState(() {
                    _dataHandler.powierzchnie.add(currentPowierzchnia);
                    _powierzchnieList = _dataHandler.powierzchnie; // Synchronizacja UI
                  });

                  await _dataHandler.savePowierzchnie();
                }

                if (!context.mounted) return;
                Navigator.of(context).pop();

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PowierzchniaDetailScreen(
                      powierzchnia: currentPowierzchnia,
                      wydzData: item, // 3. Przekazujemy dane 'tylko do odczytu' bezpośrednio do ekranu
                      onUpdate: () async {
                        setState(() {});
                        await _dataHandler.savePowierzchnie(); // Zapis z pustymi nawiasami
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

  // Deleting data from app
  void _showFormatDialog() {
    final TextEditingController pinController = TextEditingController();
    bool isError = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Formatuj pamięć',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('UWAGA! Ta operacja usunie wszystkie zapisane dane w pamięci aplikacji. Tej operacji nie można cofnąć.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true, // Hides the typed PIN
                    decoration: InputDecoration(
                      labelText: 'Wpisz PIN (123)',
                      errorText: isError ? 'Nieprawidłowy PIN' : null,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Anuluj'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    if (pinController.text.trim() == '123') {
                      Navigator.of(context).pop(); // Close dialog immediately

                      // Delete the files via DataHandler
                      await _dataHandler.formatInternalMemory();

                      // Clear the UI state completely
                      setState(() {
                        _powierzchnieList.clear();
                        _allNumPp.clear();
                        _filteredNumPp.clear();
                      });

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pamięć aplikacji została sformatowana.')),
                        );
                      }
                    } else {
                      // Show error state inside the dialog
                      setDialogState(() => isError = true);
                    }
                  },
                  child: const Text('Formatuj', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}