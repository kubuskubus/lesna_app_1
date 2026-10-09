import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:lesna_app_1/screens/powierzchnia_screen/pomiar_wysokosci.dart';
import '../../data_handler/data_handler.dart';
import 'drzewo_dialog.dart';
import 'kontrola_powierzchni.dart';
import 'powierzchnia_model.dart';
import '../../connector/bluetooth_service.dart';

class PowierzchniaDetailScreen extends StatefulWidget {
  final PowierzchniaModel powierzchnia;
  final VoidCallback onUpdate;
  final WydzielenieModel? wydzData; // <-- Dodane pole dla danych tylko do odczytu

  const PowierzchniaDetailScreen({
    super.key,
    required this.powierzchnia,
    required this.onUpdate,
    this.wydzData,
  });


  @override
  State<PowierzchniaDetailScreen> createState() => _PowierzchniaDetailScreenState();
}

enum DialogMode { addSingle, edit, addBatch }

class _PowierzchniaDetailScreenState extends State<PowierzchniaDetailScreen> with SingleTickerProviderStateMixin {
  // --- Data Handler for Saving ---
  final DataHandler _dataHandler = DataHandler();
  bool _isBatchDialogOpen = false;
  bool _isDrzewoDialogOpen = false;

  // --- Bluetooth State & UUIDs ---
  final List<String> _logs = [];
  bool _isMeasurementModeActive = false;
  int _currentMeasurementIndex = -1;
  double _maxRadiusSurface = 11.28; // Default value for 0 degrees

  // Sorting table
  int? _sortColumnIndex;
  bool _sortAscending = true;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<double>? _treeSubscription;


  // --- Controllers & State for Drzewo ---
  String _selectedDrzewoGatunek = 'SO';
  // --- NEW SEPARATED VARIABLES (for the Expansion Tile & BLE Auto-add) ---
// --- NEW SEPARATED VARIABLES ---
  String _defaultGatunekWysokosc = 'Najgrubsze'; //
  int _defaultWiekWysokosc = 0;
  // --- NEW VARIABLE FOR HEIGHT MEASUREMENT TOGGLE ---
  bool _isWysokoscPomiarActive = false;


  final TextEditingController _srednicaController = TextEditingController();
  final TextEditingController _wysokoscController = TextEditingController();
  final TextEditingController _azymutController = TextEditingController();
  final TextEditingController _odlController = TextEditingController();
  final TextEditingController _wiekController = TextEditingController(); // Added
  final TextEditingController _numerDrzewaController = TextEditingController();

  // Add this near your TextEditingControllers
  final FocusNode _srednicaFocusNode = FocusNode();

  List<DrzewoModel> get _currentDrzewa => widget.powierzchnia.drzewa
      .where((d) => d.typ == 'zywe')
      .toList();

  List<DrzewoModel> get _currentDrzewaMartwe => widget.powierzchnia.drzewa
      .where((d) => d.typ == 'martwe')
      .toList();

  // Add this variable
  late TabController _tabController;

  String _selectedWarstwa = '1'; // Default value as a string

  @override
  void initState() {
    super.initState();
    // Initialize the controller with 3 tabs
    _tabController = TabController(length: 3, vsync: this);
    _treeSubscription = BluetoothServiceManager().onTreeMeasured.listen(_handleIncomingBleMeasurement);
    placeholderFunction();
    // _inputNachylenieValue();
    _setMaxPromienPowierzchni(); // Calculates and saves the radius based on current nachylenie
    _syncGatunkiFromWydzData(); // Synchronizes and saves missing species on open
    if (widget.powierzchnia.warstwa.isNotEmpty) {
      _selectedWarstwa = widget.powierzchnia.warstwa.first;
    }
  }



  @override
  void dispose() {
    _srednicaController.dispose();
    _wysokoscController.dispose();
    _azymutController.dispose();
    _odlController.dispose();
    _wiekController.dispose();
    _scanSubscription?.cancel();
    _treeSubscription?.cancel();
    _srednicaFocusNode.dispose(); // Don't forget to dispose!
    // Add this line
    _tabController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Padding(
        // Changed to only() to keep sides at 16, but reduce the top gap
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0, top: 0.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- NEW: Expandable Gatunek List ---
            _buildWysokoscToggleAndGatunek(),
            const SizedBox(height: 4), // Small spacing before tabs
            _buildContentArea(),
          ],
        ),
      ),
    );
  }

  void _inputNachylenieValue() {
    // Reset transient state left over from a previous visit
    _isMeasurementModeActive = false;
    _currentMeasurementIndex = -1;
    _isBatchDialogOpen = false;
    _isDrzewoDialogOpen = false;
    _isWysokoscPomiarActive = false;
    _defaultGatunekWysokosc = 'Najgrubsze';
    _defaultWiekWysokosc = 0;

    // Make sure the selected layer still exists in this powierzchnia
    final warstwy = widget.powierzchnia.warstwa;
    if (warstwy.isNotEmpty && !warstwy.contains(_selectedWarstwa)) {
      _selectedWarstwa = warstwy.first;
    }

    // Check if nachylenie is 100 and prompt for a new value
    if (widget.powierzchnia.nachylenie == 100) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        int? _selectedNachylenie; // Local variable to hold the dropdown state
        final List<int> _availableValues = [0, 5, 10, 15, 20, 25, 30, 35];

        showDialog(
          context: context,
          barrierDismissible: false, // User must select a value
          builder: (BuildContext dialogContext) {
            // StatefulBuilder is required here so the Dropdown updates visually when changed
            return StatefulBuilder(
              builder: (context, setStateDialog) {
                return PopScope(
                  canPop: false, // Replaces WillPopScope to prevent Android back button
                  child: AlertDialog(
                    title: const Text('Wprowadź nachylenie'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Wybierz wartość nachylenia z listy:'),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: _selectedNachylenie,
                          decoration: const InputDecoration(
                            labelText: 'Nachylenie',
                            border: OutlineInputBorder(),
                          ),
                          items: _availableValues.map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(value.toString()),
                            );
                          }).toList(),
                          onChanged: (int? newValue) {
                            // Update the local dialog state
                            setStateDialog(() {
                              _selectedNachylenie = newValue;
                            });
                          },
                        ),
                      ],
                    ),
                    actions: [
                      ElevatedButton(
                        onPressed: () async {
                          if (_selectedNachylenie == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Proszę wybrać wartość z listy')),
                            );
                            return;
                          }

                          // 1. Save the new value to your powierzchnia model
                          setState(() {
                            widget.powierzchnia.nachylenie = _selectedNachylenie!;
                          });

                          // 2. Save the change to the JSON file using your widget's callback
                          if (widget.onUpdate != null) {
                            widget.onUpdate!();
                          }
                          // Note: If onUpdate doesn't handle the file save directly,
                          // call your file service here, e.g.:
                          // await TwojSerwisPlikow.zapiszPowierzchnie(widget.powierzchnia);

                          if (mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                        child: const Text('Zapisz'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      });
    }
  }

  void _setMaxPromienPowierzchni() {
    final int nachylenie = widget.powierzchnia.nachylenie;

    setState(() {
      switch (nachylenie) {
        case 0:
          _maxRadiusSurface = 11.28; //[cite: 3]
          break;
        case 5:
          _maxRadiusSurface = 11.30; //[cite: 3]
          break;
        case 10:
          _maxRadiusSurface = 11.37; //[cite: 3]
          break;
        case 15:
          _maxRadiusSurface = 11.48; //[cite: 3]
          break;
        case 20:
          _maxRadiusSurface = 11.64; //[cite: 3]
          break;
        case 25:
          _maxRadiusSurface = 11.85; //[cite: 3]
          break;
        case 30:
          _maxRadiusSurface = 12.12; //[cite: 3]
          break;
        case 35:
          _maxRadiusSurface = 12.46; //[cite: 3]
          break;
        default:
          _maxRadiusSurface = 11.28; // Fallback
      }

      // IMPORTANT: If you want to save this to your JSON file, you must add
      // maxRadiusSurface as a property in your PowierzchniaModel class.
      // Uncomment the line below once added to your model:
      // widget.powierzchnia.maxRadiusSurface = _maxRadiusSurface;
    });

    // Triggers the file save via your existing callback mechanism
    if (widget.onUpdate != null) {
      widget.onUpdate!();
    }
  }

  AppBar _buildAppBar(BuildContext context) {
    final List<int> availableValues = [0, 5, 10, 15, 20, 25, 30, 35];
    // Moved outside of the children list to fix the syntax error
    final bool showWszystkieOption = widget.powierzchnia.warstwa.length > 1;

    return AppBar(
      titleSpacing: 0,
      title: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(width: 4),

            // --- Dropdown for slope (nachylenie) ---
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.terrain, size: 16, color: Colors.black87),
                  const SizedBox(width: 4),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isDense: true,
                      value: widget.powierzchnia.nachylenie == 100
                          ? null
                          : widget.powierzchnia.nachylenie,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.black87, size: 20),
                      hint: const Text(
                        '-',
                        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
                      items: availableValues.map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text('$value°'),
                        );
                      }).toList(),
                      onChanged: (int? newValue) {
                        if (newValue != null) {
                          setState(() {
                            widget.powierzchnia.nachylenie = newValue;
                          });
                          if (widget.onUpdate != null) {
                            widget.onUpdate!();
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 6),

            // --- Dropdown for layers (warstwy) with dynamic 'Wszyst.' option ---
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isDense: true,
                  value: _selectedWarstwa,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.black87, size: 20),
                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
                  items: [
                    if (showWszystkieOption)
                      const DropdownMenuItem<String>(
                        value: 'Wszyst.',
                        child: Text('Wszystkie warstwy'),
                      ),
                    ...widget.powierzchnia.warstwa.map((String warstwaStr) {
                      return DropdownMenuItem<String>(
                        value: warstwaStr,
                        child: Text('Wydz. $warstwaStr'),
                      );
                    }),
                  ],
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedWarstwa = newValue;
                      });
                    }
                  },
                ),
              ),
            ),

            const SizedBox(width: 6),

            // --- Add tree button ---
            SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade100,
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => _showDrzewoDialog(
                  mode: DialogMode.addSingle,
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Drz.', style: TextStyle(fontSize: 13)),
              ),
            ),

            const SizedBox(width: 8),
          ],
        ),
      ),
      actions: const [],
    );
  }

  Widget _buildWysokoscToggleAndGatunek() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- 1. THE TOGGLE BUTTON ---
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                // Toggle the state
                _isWysokoscPomiarActive = !_isWysokoscPomiarActive;

                // --- NEW: Reset to 'Najgrubsze' when closing the menu ---
                if (!_isWysokoscPomiarActive) {
                  _defaultGatunekWysokosc = 'Najgrubsze';
                  _defaultWiekWysokosc = 0;
                }
              });
            },
            icon: Icon(
              _isWysokoscPomiarActive ? Icons.straighten : Icons.height,
              color: _isWysokoscPomiarActive ? Colors.blue : Colors.grey.shade700,
            ),
            label: const Text(
              'Pomiar wysokości',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isWysokoscPomiarActive ? Colors.blue.shade50 : Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0,
              side: BorderSide(
                color: _isWysokoscPomiarActive ? Colors.blue : Colors.grey.shade300,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        // --- 2. CONDITIONALLY DISPLAY THE EXPANSION LIST ---
        if (_isWysokoscPomiarActive)
          _buildGatunekExpansion(),
      ],
    );
  }

  // Create list of gatunek - and najgrubsze
  Widget _buildGatunekExpansion() {
    return Card(
      margin: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          'Wybrany gatunek: $_defaultGatunekWysokosc' + (_defaultGatunekWysokosc == 'Najgrubsze' ? '' : ' $_defaultWiekWysokosc'),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: const Text('Kliknij, aby zmienić / filtrować', style: TextStyle(fontSize: 12)),
        childrenPadding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _buildGatunekChips(), // <-- Dynamic chips generated based on rules
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGatunekChips() {
    final bool hasMultipleLayers = widget.powierzchnia.warstwa.length > 1;
    final bool isAllLayersSelected = _selectedWarstwa == 'Wszyst.';

    List<Widget> chips = [];

    // --- RULE: If "Wszyst." is selected, ONLY show "Najgrubsze" ---
    if (isAllLayersSelected) {
      chips.add(
        ChoiceChip(
          label: const Text('Najgrubsze'),
          selected: _defaultGatunekWysokosc == 'Najgrubsze',
          selectedColor: Colors.blue.shade100,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: _defaultGatunekWysokosc == 'Najgrubsze' ? Colors.blue : Colors.grey.shade300,
            ),
          ),
          onSelected: (bool selected) {
            if (selected) {
              setState(() {
                _defaultGatunekWysokosc = 'Najgrubsze';
                _defaultWiekWysokosc = 0;
              });
            }
          },
        ),
      );
      return chips; // Exit early so no species chips are added
    }

    // --- If a specific layer is selected, or only 1 layer exists ---
    // Show "Najgrubsze" only if there is just 1 layer total
    if (!hasMultipleLayers) {
      chips.add(
        ChoiceChip(
          label: const Text('Najgrubsze'),
          selected: _defaultGatunekWysokosc == 'Najgrubsze',
          selectedColor: Colors.blue.shade100,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: _defaultGatunekWysokosc == 'Najgrubsze' ? Colors.blue : Colors.grey.shade300,
            ),
          ),
          onSelected: (bool selected) {
            if (selected) {
              setState(() {
                _defaultGatunekWysokosc = 'Najgrubsze';
                _defaultWiekWysokosc = 0;
              });
            }
          },
        ),
      );
    }

    // Filter species strictly belonging to the chosen single layer
    var availableGatunki = _getGatunkiFromExistingTrees();
    if (hasMultipleLayers) {
      availableGatunki = availableGatunki.where((gatunek) {
        return widget.powierzchnia.drzewa.any((tree) =>
        tree.warstwa.toString() == _selectedWarstwa &&
            tree.gatunek == gatunek.nazwa &&
            tree.wiek == gatunek.wiek
        );
      }).toList();
    }

    // Map the filtered species to ChoiceChips
    for (var gatunek in availableGatunki) {
      final bool isSelected = _defaultGatunekWysokosc == gatunek.nazwa && _defaultWiekWysokosc == gatunek.wiek;

      chips.add(
        ChoiceChip(
          label: Text('${gatunek.nazwa} ${gatunek.wiek}'),
          selected: isSelected,
          selectedColor: Colors.blue.shade100,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected ? Colors.blue : Colors.grey.shade300,
            ),
          ),
          onSelected: (bool selected) {
            if (selected) {
              setState(() {
                _defaultGatunekWysokosc = gatunek.nazwa;
                _defaultWiekWysokosc = gatunek.wiek;
              });
            }
          },
        ),
      );
    }

    return chips;
  }




  List<Gatunek> _getGatunkiFromExistingTrees() {
    final seen = <String>{};
    final List<Gatunek> result = [];

    for (var drzewo in widget.powierzchnia.drzewa) {
      // Create a unique key for each Gatunek + Age combination
      final key = '${drzewo.gatunek}_${drzewo.wiek}';

      if (seen.add(key)) {
        result.add(Gatunek(nazwa: drzewo.gatunek, wiek: drzewo.wiek));
      }
    }

    // Optional: Sort them alphabetically so they look nice in the list
    result.sort((a, b) => a.nazwa.compareTo(b.nazwa));

    return result;
  }


  Widget _buildContentArea() {
    return Expanded(
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.deepPurple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepPurple,
            tabs: const [
              Tab(text: 'Drzewa żyw.'),
              Tab(text: 'Drzewa martw.'),
              Tab(text: 'Kontrola'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Drzewa żywe
                _currentDrzewa.isEmpty
                    ? _buildEmptyState('Brak żywych drzew. Kliknij "+ dodaj wiele" lub "+ drzewo".')
                    : _buildTreeTabContent(_currentDrzewa),

                // Tab 2: Drzewa martwe
                _currentDrzewaMartwe.isEmpty
                    ? _buildEmptyState('Brak martwych drzew.')
                    : _buildTreeTabContent(_currentDrzewaMartwe),

                // Tab 3: Kontrola
                SingleChildScrollView(
                  // Only pass trees that match the currently selected layer
                  child: KontrolaPowierzchni.buildKontrolaTable(
                    widget.powierzchnia.drzewa
                        .where((tree) => tree.warstwa == _selectedWarstwa)
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(color: Colors.grey),
        textAlign: TextAlign.center,
      ),
    );
  }

// 1. Unify the widget to accept a list of trees
  Widget _buildTreeTabContent(List<DrzewoModel> treesList) {

    // --- CHANGED: Only reset the trees belonging to this specific Tab! ---
    // Instead of widget.powierzchnia.drzewa, we use treesList.
    for (var tree in treesList) {
      tree.wysRequired = false;
    }

    // --- 2. Filter the list ---
    final List<DrzewoModel> filteredTrees = treesList.where((tree) {
      // If 'Wszyst.' is selected, match all layers; otherwise, match the specific layer
      bool matchesWarstwa = (_selectedWarstwa == 'Wszyst.') ||
          (tree.warstwa.toString() == _selectedWarstwa || tree.warstwa.toString().isEmpty);

      // Optional: Filter by type (e.g., only 'zywe' or 'martwe' depending on your toggle/state)
      // Replace `_selectedTyp` with your actual variable if you have one, or hardcode the condition if needed.
      // bool matchesTyp = tree.typ == 'zywe' || tree.typ == 'martwe';

      bool matchesGatunek = true;
      if (_isWysokoscPomiarActive && _defaultGatunekWysokosc != 'Najgrubsze') {
        matchesGatunek = (tree.gatunek == _defaultGatunekWysokosc && tree.wiek == _defaultWiekWysokosc);
      }

      return matchesWarstwa && matchesGatunek; // && matchesTyp (if you need type filtering)
    }).toList();

    // --- 3. Apply the flags ONLY if the mode is active ---
    if (_isWysokoscPomiarActive) {
      final pomiarManager = PomiarWysokosci(powierzchnia: widget.powierzchnia);
      pomiarManager.assignTreesForHeight(filteredTrees, _defaultGatunekWysokosc);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        _buildDrzewaTable(filteredTrees),
      ],
    );
  }


  Widget _buildDrzewaTable(List<DrzewoModel> drzewaList) {
    List<DrzewoModel> displayList = List.from(drzewaList);

    if (_isWysokoscPomiarActive) {
      displayList.sort((a, b) => a.odl.compareTo(b.odl));
    }

    // Adjusted fixed widths. The FittedBox will handle scaling them down to fit the screen.
    final double colNrWidth = 20.0;
    final double colGatWidth = 55.0;
    final double colOdlWidth = 45.0;
    final double colSredWidth = 40.0;
    final double colWysWidth = 40.0;
    final double colAkcjeWidth = 35.0;

    return Container(
      width: double.infinity, // Forces the container to take all available width
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      // --- THIS IS THE FIX: Scales the entire table down if it overflows ---
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: DataTable(
          // Keep spacing tight to minimize how much it needs to scale
          columnSpacing: 12.0,
          horizontalMargin: 12.0,

          sortColumnIndex: _isWysokoscPomiarActive ? 2 : _sortColumnIndex,
          sortAscending: _isWysokoscPomiarActive ? true : _sortAscending,
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
          dataRowMinHeight: 40,
          dataRowMaxHeight: 48,
          columns: [
            DataColumn(
              label: SizedBox(width: colNrWidth, child: const Text('Nr.', style: TextStyle(fontWeight: FontWeight.bold))),
              onSort: _onSort,
            ),
            DataColumn(
              label: SizedBox(width: colGatWidth, child: const Text('Gat.', style: TextStyle(fontWeight: FontWeight.bold))),
              onSort: _onSort,
            ),
            DataColumn(
              label: SizedBox(width: colOdlWidth, child: const Text('Odl.', style: TextStyle(fontWeight: FontWeight.bold))),
              onSort: _onSort,
              numeric: true,
            ),
            DataColumn(
              label: SizedBox(width: colSredWidth, child: const Text('Śred.', style: TextStyle(fontWeight: FontWeight.bold))),
              onSort: _onSort,
              numeric: true,
            ),
            DataColumn(
              label: SizedBox(width: colWysWidth, child: const Text('Wys.', style: TextStyle(fontWeight: FontWeight.bold))),
              onSort: _onSort,
              numeric: true,
            ),
            DataColumn(
              label: SizedBox(width: colAkcjeWidth, child: const Text('Akcje', style: TextStyle(fontWeight: FontWeight.bold))),
            ),
          ],
          rows: List.generate(displayList.length, (index) {
            final drzewo = displayList[index];
            final globalIndex = widget.powierzchnia.drzewa.indexOf(drzewo);

            final String numerStr = drzewo.numer.toString();
            final String gatunekStr = '${drzewo.gatunek}${drzewo.wiek}';

            return DataRow(
              color: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
                if (drzewo.wysRequired) {
                  if (drzewo.wysokosc > 0) {
                    return Colors.green.shade50;
                  } else {
                    return Colors.red.shade50;
                  }
                }
                return null;
              }),
              cells: [
                DataCell(
                  SizedBox(width: colNrWidth, child: Text(numerStr, style: const TextStyle(fontWeight: FontWeight.w500))),
                  onTap: () {
                    if (globalIndex >= 0) _showDrzewoDialog(mode: DialogMode.edit, globalIndex: globalIndex, existingTree: drzewo);
                  },
                ),
                DataCell(
                  SizedBox(width: colGatWidth, child: Text(gatunekStr)),
                  onTap: () {
                    if (globalIndex >= 0) _showDrzewoDialog(mode: DialogMode.edit, globalIndex: globalIndex, existingTree: drzewo);
                  },
                ),
                DataCell(
                  SizedBox(width: colOdlWidth, child: Text(drzewo.odl > 0 ? drzewo.odl.toStringAsFixed(2) : '-')),
                  onTap: () {
                    if (globalIndex >= 0) _showDrzewoDialog(mode: DialogMode.edit, globalIndex: globalIndex, existingTree: drzewo);
                  },
                ),
                DataCell(
                  SizedBox(width: colSredWidth, child: Text(drzewo.srednica > 0 ? drzewo.srednica.toStringAsFixed(1) : '-')),
                  onTap: () {
                    if (globalIndex >= 0) _showDrzewoDialog(mode: DialogMode.edit, globalIndex: globalIndex, existingTree: drzewo);
                  },
                ),
                DataCell(
                  SizedBox(width: colWysWidth, child: Text(drzewo.wysokosc > 0 ? drzewo.wysokosc.toStringAsFixed(1) : '-')),
                  onTap: () {
                    if (globalIndex >= 0) _showDrzewoDialog(mode: DialogMode.edit, globalIndex: globalIndex, existingTree: drzewo);
                  },
                ),
                DataCell(
                  SizedBox(
                    width: colAkcjeWidth,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () {
                        if (globalIndex >= 0) {
                          setState(() {
                            widget.powierzchnia.drzewa.removeAt(globalIndex);
                          });
                          widget.onUpdate();
                        }
                      },
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  void _showDrzewoDialog({
    required DialogMode mode,
    int? globalIndex,
    DrzewoModel? existingTree,
  }) {
    // --- Check the slope (nachylenie) before opening the dialog ---
    if (widget.powierzchnia.nachylenie == 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Brak nachylenia. Wybierz wartość nachylenia przed dodaniem drzewa.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 3),
        ),
      );
      return; // Exit the function here - the dialog will not open
    }

    // --- NEW: Block adding a tree if "Wszyst." is selected ---
    if (_selectedWarstwa == 'Wszyst.') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wybierz konkretną warstwę przed dodaniem drzewa.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 3),
        ),
      );
      return; // Exit the function here - the dialog will not open
    }

    _isDrzewoDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: mode != DialogMode.addBatch,
      builder: (context) {
        return DrzewoDialog(
          powierzchnia: widget.powierzchnia,
          maxRadiusSurface: _maxRadiusSurface, // Pass it here
          initialMode: mode,
          initialGlobalIndex: globalIndex,
          existingTree: existingTree,
          initialDynamicGatunki: _getDynamicGatunki(),
          selectedWarstwa: _selectedWarstwa, // <-- PASS THE SELECTED LAYER HERE
          onUpdate: () {
            setState(() {});
            widget.onUpdate();
          },
        );
      },
    ).then((_) {
      _isDrzewoDialogOpen = false;
      if (mode == DialogMode.addBatch) {
        setState(() => _isBatchDialogOpen = false);
      }
    });
  }



  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;

      // Assuming you want to sort the underlying data list
      widget.powierzchnia.drzewa.sort((a, b) {
        int result;
        switch (columnIndex) {
          case 0: // Nr.
            result = a.numer.compareTo(b.numer);
            break;
          case 1: // Gat.
            result = a.gatunek.compareTo(b.gatunek);
            break;
          case 2: // Odl. [m]  <-- This is now index 2
            result = a.odl.compareTo(b.odl);
            break;
          case 3: // Śred. [cm] <-- This is now index 3
            result = a.srednica.compareTo(b.srednica);
            break;
          case 4: // Wys. [m]   <-- This is now index 4
            result = a.wysokosc.compareTo(b.wysokosc);
            break;
          default:
            result = 0;
        }
        return ascending ? result : -result; // Reverse if descending
      });

      widget.onUpdate(); // Call your update callback if needed
    });
  }

  void placeholderFunction() {
    {} // Does nothing
  }

  void _handleIncomingBleMeasurement(double diameter) {
    if (_isMeasurementModeActive) {
      List<DrzewoModel> localDrzewa = _currentDrzewa;
      if (_currentMeasurementIndex == -1) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please tap a tree on the list first!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (_currentMeasurementIndex >= 0 && _currentMeasurementIndex < localDrzewa.length) {
        setState(() {
          localDrzewa[_currentMeasurementIndex].srednica = diameter;
        });

        String treeNumber = 'DRZ${(_currentMeasurementIndex + 1).toString().padLeft(3, '0')}';

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$treeNumber | Diameter: ${diameter.toStringAsFixed(1)} cm'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );

        widget.onUpdate();
        _currentMeasurementIndex++;

        if (_currentMeasurementIndex >= localDrzewa.length) {
          setState(() {
            _isMeasurementModeActive = false;
            _currentMeasurementIndex = -1;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All trees in the list have been measured.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      // NEW LOGIC HERE: Check if the cursor is in the field OR if the batch dialog is open
    } else if (_srednicaFocusNode.hasFocus || _isBatchDialogOpen) {
      setState(() {
        _srednicaController.text = diameter.toStringAsFixed(1);
        // Move cursor to the end of the newly inserted text
        _srednicaController.selection = TextSelection.fromPosition(
          TextPosition(offset: _srednicaController.text.length),
        );
      });
      _log('-> Filled diameter field: $diameter cm');
    // CHANGED LOGIC: Check if the dialog is open OR if the field has focus
    } else if (_isDrzewoDialogOpen || _srednicaFocusNode.hasFocus) {
      // No setState needed! The controller updates the UI automatically.
      _srednicaController.text = diameter.toStringAsFixed(1);

      // Safely move the cursor to the end
      _srednicaController.selection = TextSelection.fromPosition(
        TextPosition(offset: _srednicaController.text.length),
      );

      _log('-> Filled diameter field: $diameter cm');
    } else {
      // Default background adding logic (only runs if dialog is CLOSED)
      final int nextIndex = _currentDrzewa.length + 1;
      final String generatedNumer = 'DRZ${nextIndex.toString().padLeft(3, '0')}';

      setState(() {
        widget.powierzchnia.drzewa.add(
          DrzewoModel(
            numer: widget.powierzchnia.drzewa.length + 1, // <-- ADDED: Automatic next number
            powierzchniaNumer: widget.powierzchnia.numer,
            gatunek: _selectedDrzewoGatunek,
            typ: 'zywe',
            srednica: diameter,
            wysokosc: 0.0,
          ),
        );
      });

      widget.onUpdate();
      _log('-> Received diameter: $diameter cm. Saved to surface ${widget.powierzchnia.numer}.');
    }
  }

  void _log(String text) {
    setState(() {
      _logs.add(text);
    });
    print(text);
  }

  // --- HELPER FUNCTIONS ---

  void _syncGatunkiFromWydzData() {
    if (widget.wydzData == null || widget.wydzData!.listOfTrees.isEmpty) return;

    bool hasChanges = false;

    for (var treeGatunek in widget.wydzData!.listOfTrees) {
      String nazwa = treeGatunek.nazwa.trim().toUpperCase();
      int wiek = treeGatunek.wiek;

      if (nazwa.isNotEmpty) {
        // Check if this species already exists in powierzchnia.gatunki
        bool exists = widget.powierzchnia.gatunki.any(
              (g) => g.nazwa.trim().toUpperCase() == nazwa,
        );

        // If it doesn't exist, add it
        if (!exists) {
          widget.powierzchnia.gatunki.add(Gatunek(nazwa: nazwa, wiek: wiek));
          hasChanges = true;
        }
      }
    }

    // Save and refresh UI only if new species were actually added
    if (hasChanges) {
      setState(() {});
      widget.onUpdate(); // Triggers the save function passed from the parent widget
    }
  }


  List<Gatunek> _getDynamicGatunki() {
    List<Gatunek> dynamicGatunki = [];
    if (widget.powierzchnia.gatunki.isNotEmpty) {
      final seen = <String>{};
      dynamicGatunki = widget.powierzchnia.gatunki.where((g) {
        final key = '${g.nazwa.trim().toUpperCase()}_${g.wiek}';
        return seen.add(key);
      }).toList();
    }

    if (dynamicGatunki.isEmpty) {
      dynamicGatunki = [
        Gatunek(nazwa: 'SO', wiek: 0),
        Gatunek(nazwa: 'MD', wiek: 0),
        Gatunek(nazwa: 'ŚW', wiek: 0),
        Gatunek(nazwa: 'JD', wiek: 0),
        Gatunek(nazwa: 'BK', wiek: 0),
      ];
    }
    return dynamicGatunki;
  }


}

class AutoDecimalFormatter extends TextInputFormatter {
  final int decimalDigits;

  AutoDecimalFormatter({required this.decimalDigits});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Strip out everything except numbers
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.isEmpty) {
      return const TextEditingValue(text: '');
    }

    // Shift the decimal place automatically
    double value = int.parse(digitsOnly) / math.pow(10, decimalDigits);
    String formatted = value.toStringAsFixed(decimalDigits);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}