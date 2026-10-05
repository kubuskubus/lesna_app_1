import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
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

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<double>? _treeSubscription;


  // --- Controllers & State for Drzewo ---
  String _selectedDrzewoGatunek = 'SO';
  String _selectedDrzewoTyp = 'zywe';
  final TextEditingController _srednicaController = TextEditingController();
  final TextEditingController _wysokoscController = TextEditingController();
  final TextEditingController _azymutController = TextEditingController();
  final TextEditingController _odlController = TextEditingController();
  final TextEditingController _wiekController = TextEditingController(); // Added
  final TextEditingController _numerDrzewaController = TextEditingController();

  // Add this near your TextEditingControllers
  final FocusNode _srednicaFocusNode = FocusNode();

  final List<String> _gatunki = ['SO', 'MD', 'ŚW', 'JD', 'BK'];

  // Filtered lists belonging strictly to this specific Powierzchnia
// Filtered lists belonging strictly to this specific Powierzchnia
  List<DrzewoModel> get _currentDrzewa => widget.powierzchnia.drzewa
      .where((d) => d.typ == 'zywe')
      .toList();

  List<DrzewoModel> get _currentDrzewaMartwe => widget.powierzchnia.drzewa
      .where((d) => d.typ == 'martwe')
      .toList();

  // Add this variable
  late TabController _tabController;

  int _selectedWarstwa = 1;

  @override
  void initState() {
    super.initState();
    // Initialize the controller with 3 tabs
    _tabController = TabController(length: 3, vsync: this);
    _treeSubscription = BluetoothServiceManager().onTreeMeasured.listen(_handleIncomingBleMeasurement);
    placeholderFunction();
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
            // _buildHeaderTitle(),
            // const SizedBox(height: 12),
            // _buildActionButtonsRow(),

            // REMOVED: const SizedBox(height: 20), <-- This was causing the huge gap

            _buildContentArea(),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text('Powierzchnia nr. ${widget.powierzchnia.numer}'),
      actions: [
        // --- NOWE: Rozwijana lista (Dropdown) dla warstw ---
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              color: Colors.blue.shade100, // Inny kolor, aby odróżnić od przycisku dodawania
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedWarstwa,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                // Tworzenie elementów listy na podstawie listy warstw w powierzchni
                items: widget.powierzchnia.warstwa.map((int warstwaNum) {
                  return DropdownMenuItem<int>(
                    value: warstwaNum,
                    child: Text('Warstwa $warstwaNum'),
                  );
                }).toList(),
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedWarstwa = newValue; // Aktualizacja zmiennej śledzącej
                    });
                  }
                },
              ),
            ),
          ),
        ),
        // --- ISTNIEJĄCE: Przycisk dodawania drzewa ---
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade100,
              foregroundColor: Colors.black87,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => _showDrzewoDialog(
              mode: DialogMode.addSingle,
              // Możesz teraz przekazać _selectedWarstwa do dialogu, jeśli drzewo ma dziedziczyć tę warstwę
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Drz.'),
          ),
        ),
      ],
    );
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
                  child: KontrolaPowierzchni.buildKontrolaTable(_currentDrzewa),
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
    // --- NEW: Filter the list to show only trees matching the selected warstwa ---
    final List<DrzewoModel> filteredTrees = treesList
        .where((tree) => tree.warstwa == _selectedWarstwa)
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        // Pass the filtered list instead of the full list
        _buildDrzewaTable(filteredTrees),
      ],
    );
  }


  Widget _buildDrzewaTable(List<DrzewoModel> drzewaList) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                columnSpacing: 24,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 48,
                columns: const [
                  DataColumn(label: Text('Nr.', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Gat.', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Śred. [cm]', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Wys. [m]', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Akcje', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: List.generate(drzewaList.length, (index) {
                  final drzewo = drzewaList[index];
                  final globalIndex = widget.powierzchnia.drzewa.indexOf(drzewo);

                  // 1. Nr: Use the permanent number from the model, NOT the list index!
                  final String numerStr = drzewo.numer.toString();

                  // 2. Gat: Species + Age (e.g., SO45)
                  final String gatunekStr = '${drzewo.gatunek}${drzewo.wiek}';

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(numerStr, style: const TextStyle(fontWeight: FontWeight.w500)),
                        onTap: () {
                          if (globalIndex >= 0) {
                            _showDrzewoDialog(mode: DialogMode.edit, globalIndex: globalIndex, existingTree: drzewo);
                          }
                        },
                      ),
                      DataCell(
                        Text(gatunekStr),
                        onTap: () {
                          if (globalIndex >= 0) {
                            _showDrzewoDialog(mode: DialogMode.edit, globalIndex: globalIndex, existingTree: drzewo);
                          }
                        },
                      ),
                      DataCell(
                        Text(drzewo.srednica > 0 ? drzewo.srednica.toStringAsFixed(1) : '-'),
                        onTap: () {
                          if (globalIndex >= 0) {
                            _showDrzewoDialog(mode: DialogMode.edit, globalIndex: globalIndex, existingTree: drzewo);
                          }
                        },
                      ),
                      DataCell(
                        Text(drzewo.wysokosc > 0 ? drzewo.wysokosc.toStringAsFixed(1) : '-'),
                        onTap: () {
                          if (globalIndex >= 0) {
                            _showDrzewoDialog(mode: DialogMode.edit, globalIndex: globalIndex, existingTree: drzewo);
                          }
                        },
                      ),
                      DataCell(
                        IconButton(
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
                    ],
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }



  void _showDrzewoDialog({
    required DialogMode mode,
    int? globalIndex,
    DrzewoModel? existingTree,
  }) {
    _isDrzewoDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: mode != DialogMode.addBatch,
      builder: (context) {
        return DrzewoDialog(
          powierzchnia: widget.powierzchnia,
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