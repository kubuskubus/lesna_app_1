import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lesna_app_1/screens/powierzchnia_screen/info_screen.dart';
import 'package:lesna_app_1/screens/powierzchnia_screen/kontrola_powierzchni.dart';
import 'package:lesna_app_1/screens/powierzchnia_screen/powierzchnia_model.dart';
import 'connector/bluetooth_device.dart';
import 'screens/powierzchnia_screen/powierzchnia_details.dart';
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

  PowierzchniaModel? _selectedPowierzchnia;
  WydzielenieModel? _selectedWydzData;
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
  bool _showNotComplete = false;
  bool _showComplete = false;

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

          // --- 3. NEW: Calculate and set completion status for all loaded surfaces ---
          KontrolaPowierzchni.checkControlForAllSurfaces(_powierzchnieList);

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
      // The 'bottom' property places widgets below the main title
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48.0), // Allocate height for the buttons
        child: Padding(
          padding: const EdgeInsets.only(right: 8.0, bottom: 4.0), // Match standard AppBar padding
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end, // Align buttons to the right
            children: [
              // NEW: Format Button
              IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                tooltip: 'Formatuj pamięć',
                onPressed: _showFormatDialog,
              ),
              TextButton(
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
                child: const Text(
                  'Import JSON',
                  style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () async {
                  String? initials = await showDialog<String>(
                    context: context,
                    builder: (BuildContext context) {
                      TextEditingController initialsController = TextEditingController();
                      return AlertDialog(
                        title: const Text('Udostępnij JSON'),
                        content: TextField(
                          controller: initialsController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'Podaj inicjały taksatora',
                            hintText: 'np. JL',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            child: const Text('Anuluj', style: TextStyle(color: Colors.grey)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(initialsController.text.trim());
                            },
                            child: const Text('Udostępnij'),
                          ),
                        ],
                      );
                    },
                  );

                  if (initials == null || initials.isEmpty) {
                    return;
                  }

                  bool success = await _dataHandler.exportPowierzchnieJson(initials);

                  if (context.mounted && !success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Anulowano udostępnianie lub wystąpił błąd.'),
                      ),
                    );
                  }
                },
                child: const Text(
                  'Udostępnij JSON',
                  style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, // Ensure children span the full width
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
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
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _isSearching = false;
                      _filteredNumPp.clear();
                    });
                    FocusScope.of(context).unfocus();
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // 1a. NEW: Narrow 2-Column Button Bar (Touching the table below)
          _buildDualActionButtons(),

          // 2. The Unified Table (Sits flush right beneath the buttons)
          _buildUnifiedTable(
            child: _isSearching
                ? _buildSearchListView() // Renders WydzielenieModel from JSON
                : _buildMainListView(),  // Renders PowierzchniaModel from memory
          ),
        ],
      ),
    );
  }

  /// Builds the narrow 2-column button bar with dynamic counts
  Widget _buildDualActionButtons() {
    // 1. Calculate counts dynamically from the loaded list
    int incompleteCount = _powierzchnieList
        .where((p) => p.completion['completion'] == 'notCompleted')
        .length;

    int completeCount = _powierzchnieList
        .where((p) => p.completion['completion'] == 'Completed')
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 0.0),
      child: Container(
        height: 36.0, // Narrow height
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- COLUMN 1 (Left Button - Niekompletne / Red) ---
              Expanded(
                child: Material(
                  color: _showNotComplete ? Colors.red.shade400 : Colors.red.shade50,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (_showNotComplete) {
                          _showNotComplete = false;
                        } else {
                          _showNotComplete = true;
                          _showComplete = false;
                        }
                      });
                    },
                    child: Center(
                      child: Text(
                        // 2. Display the count for incomplete surfaces
                        'Niekompletne ($incompleteCount)',
                        style: TextStyle(
                          color: _showNotComplete ? Colors.white : Colors.red.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Vertical divider
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: Colors.grey.shade300,
              ),

              // --- COLUMN 2 (Right Button - Kompletne / Green) ---
              Expanded(
                child: Material(
                  color: _showComplete ? Colors.green.shade400 : Colors.green.shade50,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (_showComplete) {
                          _showComplete = false;
                        } else {
                          _showComplete = true;
                          _showNotComplete = false;
                        }
                      });
                    },
                    child: Center(
                      child: Text(
                        // 3. Display the count for complete surfaces
                        'Kompletne ($completeCount)',
                        style: TextStyle(
                          color: _showComplete ? Colors.white : Colors.green.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildMainListView() {
    if (_powierzchnieList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Text('Brak danych. Kliknij "Wczytaj" lub + aby dodać.', style: TextStyle(color: Colors.grey)),
      );
    }

    // --- SORTING APPLIED HERE FOR MEMORY LIST ---
    List<PowierzchniaModel> sortedList = _sortListItems<PowierzchniaModel>(
      items: _powierzchnieList,
      getNumer: (item) => item.numer,
      // Simply read the saved state:
      getCompletionStatus: (item) => item.completion['completion'] ?? 'notEdited',
    );

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedList.length,
      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade300),
      itemBuilder: (context, index) {
        final item = sortedList[index];

        return _buildUnifiedTableRow(
          index: index,
          numer: item.numer,
          adres: item.adres.join(', '),
          isSearchResult: false,
        );
      },
    );
  }

  Widget _buildSearchListView() {
    if (_filteredNumPp.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Text('Brak wyników wyszukiwania.', style: TextStyle(color: Colors.grey)),
      );
    }

    // --- SORTING APPLIED HERE FOR SEARCH RESULTS ---
    List<WydzielenieModel> sortedList = _sortListItems<WydzielenieModel>(
      items: _filteredNumPp,
      getNumer: (item) => item.numPp,
      getCompletionStatus: (item) {
        // Find if this JSON search result exists in the saved surfaces
        int powIndex = _dataHandler.powierzchnie.indexWhere((p) => p.numer == item.numPp);
        if (powIndex != -1) {
          return _dataHandler.powierzchnie[powIndex].completion['completion'] ?? 'notEdited';
        }
        return 'notEdited'; // Not added yet counts as completely empty
      },
    );

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedList.length,
      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade300),
      itemBuilder: (context, index) {
        final item = sortedList[index];

        return _buildUnifiedTableRow(
          index: index,
          numer: item.numPp,
          adres: item.adressLes.join(', '),
          isSearchResult: true,
        );
      },
    );
  }

  Widget _buildUnifiedTable({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 80.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- SHARED TABLE HEADER ---
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: const Row(
                children: [
                  // Changed flex from 2 to 1
                  Expanded(flex: 1, child: Text('KPP', style: TextStyle(fontWeight: FontWeight.bold))),
                  // Changed flex from 3 to 4
                  Expanded(flex: 4, child: Text('Adres leśny', style: TextStyle(fontWeight: FontWeight.bold))),
                  // Kept at flex 2
                  Expanded(flex: 2, child: Text('Akcje', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                ],
              )
            ),

            // --- DYNAMIC ROWS GO HERE ---
            child,
          ],
        ),
      ),
    );
  }


  Widget _buildUnifiedTableRow({
    required int index,
    required String numer,
    required String adres,
    bool isSearchResult = false,
  }) {
    // 1. Find the specific surface for this row
    int powIndex = _dataHandler.powierzchnie.indexWhere((p) => p.numer == numer);
    bool existsInMainList = powIndex != -1;

    PowierzchniaModel? currentPowierzchnia;
    String completionStatus = 'notEdited'; // Default state

    if (existsInMainList) {
      currentPowierzchnia = _dataHandler.powierzchnie[powIndex];
      // Read the pre-calculated completion status directly from the map
      completionStatus = currentPowierzchnia.completion['completion'] ?? 'notEdited';
    }

    // Determine row color based on the saved completion status
    Color rowColor = Colors.transparent;
    if (completionStatus == 'Completed') {
      rowColor = Colors.green.shade50;
    } else if (completionStatus == 'notCompleted') {
      rowColor = Colors.amber.shade50; // Work in progress
    }

    // Helper flag
    bool isAdded = !isSearchResult || existsInMainList;

    // Actions column
    Widget actionsWidget = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.info_outline),
          tooltip: 'Informacje o powierzchni',
          onPressed: () {
            if (currentPowierzchnia != null) {
              showDialog(
                context: context,
                builder: (context) => PowierzchniaInfoDialog(powierzchnia: currentPowierzchnia!),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Zapisz powierzchnię, aby zobaczyć informacje.')),
              );
            }
          },
        ),
        const SizedBox(width: 16),
        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Material(
        color: rowColor, // <-- APPLIED THE STATUS-BASED DYNAMIC COLOR
        child: InkWell(
          onTap: () async { // 1. Make the onTap callback async
            if (isAdded && currentPowierzchnia != null) {
              int wydzIndex = _dataHandler.wydzList.indexWhere((w) => w.numPp == numer);
              WydzielenieModel? matchingWydz = wydzIndex >= 0 ? _dataHandler.wydzList[wydzIndex] : null;
              // 2. Await the Navigator.push
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PowierzchniaDetailScreen(
                    powierzchnia: currentPowierzchnia!,
                    wydzData: matchingWydz,
                    onUpdate: () {
                      // This is still useful if you want to save to memory
                      // while the user is actively working inside the Detail Screen.
                      _dataHandler.savePowierzchnie();
                    },
                  ),
                ),
              );

              // 3. THIS BLOCK RUNS EVERY TIME YOU RETURN TO THE MAIN SCREEN
              if (mounted) {
                // Recalculate the status for everything
                KontrolaPowierzchni.checkControlForAllSurfaces(_dataHandler.powierzchnie);
                // Save it to the device
                await _dataHandler.savePowierzchnie();
                // Rebuild the table so the colors update instantly
                setState(() {});
              }

            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Powierzchnia $numer nie została dodana. Użyj przycisku +, aby ją utworzyć.'),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(numer, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Expanded(flex: 4, child: Text(adres.isNotEmpty ? adres : '-')),
                  Expanded(flex: 2, child: actionsWidget),
                ],
              )
          ),
        ),
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


  /// Universal sorting helper for list items based on completion status & number order
  List<T> _sortListItems<T>({
    required List<T> items,
    required String Function(T item) getNumer,
    required String Function(T item) getCompletionStatus, // <-- NEW: Replaces boolean checks
  }) {
    // Create a mutable copy to sort
    List<T> sortedList = List.from(items);

    sortedList.sort((a, b) {
      int getWeight(T item) {
        // 1. If NEITHER button is selected -> all items have equal weight (0),
        // so the list sorts strictly by number order
        if (!_showNotComplete && !_showComplete) {
          return 0;
        }

        String status = getCompletionStatus(item);

        // 2. Empty surfaces (notEdited) always go last (weight 2)
        if (status == 'notEdited') {
          return 2;
        }

        // 3. Prioritize based on which button is active
        if (_showNotComplete) {
          // Niekompletne (0) -> Kompletne (1) -> Empty (2)
          return status == 'Completed' ? 1 : 0;
        } else {
          // Kompletne (0) -> Niekompletne (1) -> Empty (2)
          return status == 'Completed' ? 0 : 1;
        }
      }

      int weightA = getWeight(a);
      int weightB = getWeight(b);

      // Primary sort: by category weight (only when a button is active)
      if (weightA != weightB) {
        return weightA.compareTo(weightB);
      }

      // Secondary sort: Numerical order by `numer` (or `numPp`)
      int? numA = int.tryParse(getNumer(a).trim());
      int? numB = int.tryParse(getNumer(b).trim());

      if (numA != null && numB != null) {
        return numA.compareTo(numB);
      }

      // Fallback to alphabetical comparison if not pure numbers
      return getNumer(a).compareTo(getNumer(b));
    });

    return sortedList;
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