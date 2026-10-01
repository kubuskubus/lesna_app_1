import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../data_handler/data_handler.dart';
import 'powierzchnia_model.dart';
import '../connector/bluetooth_service.dart';

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

  @override
  void initState() {
    super.initState();
    // Initialize the controller with 3 tabs
    _tabController = TabController(length: 3, vsync: this);
    _treeSubscription = BluetoothServiceManager().onTreeMeasured.listen(_handleIncomingBleMeasurement);
    placeholderFunction();
    _syncGatunkiFromWydzData(); // Synchronizes and saves missing species on open
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
    // Add this line
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderTitle(),
            const SizedBox(height: 12),
            _buildActionButtonsRow(),
            const SizedBox(height: 20),
            _buildContentArea(),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      leading: TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back', style: TextStyle(color: Colors.deepPurple)),
      ),
      leadingWidth: 70,
      title: Text('Surface ${widget.powierzchnia.numer}'),
      // actions removed entirely since simulation is gone
    );
  }

  Widget _buildHeaderTitle() {
    return const Text(
      'Panel drzew i martwego drewna',
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildActionButtonsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // ElevatedButton.icon(
          //   style: ElevatedButton.styleFrom(
          //     backgroundColor: Colors.grey.shade200,
          //     foregroundColor: Colors.black87,
          //     elevation: 0,
          //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          //   ),
          //   onPressed: () => _showDrzewoDialog(mode: DialogMode.addBatch),
          //   icon: const Icon(Icons.playlist_add, size: 18),
          //   label: const Text('Add many'),
          // ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade100,
              foregroundColor: Colors.black87,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => _showDrzewoDialog(mode: DialogMode.addSingle),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tree'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isMeasurementModeActive ? Colors.red.shade100 : Colors.blue.shade100,
              foregroundColor: _isMeasurementModeActive ? Colors.red.shade900 : Colors.blue.shade900,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () {
              setState(() {
                if (_isMeasurementModeActive) {
                  _isMeasurementModeActive = false;
                  _currentMeasurementIndex = -1;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Measurement mode stopped.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  if (_currentDrzewa.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('List is empty. Add trees first.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  _isMeasurementModeActive = true;
                  _currentMeasurementIndex = -1;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tap a tree on the list to select where to start.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              });
            },
            icon: Icon(
              _isMeasurementModeActive ? Icons.stop : Icons.straighten,
              size: 18,
            ),
            label: Text(_isMeasurementModeActive ? 'Stop' : 'Measurements'),
          ),
        ],
      ),
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
                _buildEmptyState('Brak danych kontrolnych.'),
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
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        _buildDrzewaTable(treesList),
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
                columnSpacing: 24, // Increase this value if you want the columns spread further apart
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

                  // 1. Nr: Just the pure number
                  final String numerStr = '${(globalIndex >= 0 ? globalIndex : index) + 1}';

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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
    );
  }

  void _showDrzewoDialog({
    required DialogMode mode,
    int? globalIndex,
    DrzewoModel? existingTree,
  }) {
    // 1. All the state clearing/setting happens here!
    _initializeDialogFields(mode, existingTree);

    showDialog(
      context: context,
      barrierDismissible: mode != DialogMode.addBatch,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {

            final List<Gatunek> dynamicGatunki = _getDynamicGatunki();

            final int nextIndex = widget.powierzchnia.drzewa.length + 1;
            String currentNumer = '';
            String title = '';

            // 2. Set the title based on mode
            if (mode == DialogMode.edit && globalIndex != null) {
              currentNumer = 'DRZ${(globalIndex + 1).toString().padLeft(3, '0')}';
              title = 'Edytuj drzewo ($currentNumer)';
            } else {
              currentNumer = 'DRZ${nextIndex.toString().padLeft(3, '0')}';
              title = mode == DialogMode.addBatch
                  ? 'Szybkie dodawanie ($currentNumer)'
                  : 'Nowe drzewo ($currentNumer)';
            }

            // 3. Return the dialog UI
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Stan drzewa (Żywe / Martwe) ---
                    const Text('Stan drzewa', style: TextStyle(color: Colors.black54, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Żywe'),
                          selected: _selectedDrzewoTyp == 'zywe',
                          selectedColor: Colors.green.shade100,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() => _selectedDrzewoTyp = 'zywe');
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Martwe'),
                          selected: _selectedDrzewoTyp == 'martwe',
                          selectedColor: Colors.brown.shade100,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() => _selectedDrzewoTyp = 'martwe');
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ... the rest of your UI (Gatunek, Średnica, etc.) ...
// ----------------------------------------
                    const Text('Gatunek', style: TextStyle(color: Colors.black54, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...dynamicGatunki.map((gatunekObj) {
                          final String combinedLabel = '${gatunekObj.nazwa}${gatunekObj.wiek}';

                          return ChoiceChip(
                            label: Text(combinedLabel),
                            selected: _selectedDrzewoGatunek == gatunekObj.nazwa,
                            selectedColor: Colors.deepPurple.shade100,
                            onSelected: (selected) {
                              setDialogState(() {
                                _selectedDrzewoGatunek = gatunekObj.nazwa;
                                _wiekController.text = gatunekObj.wiek > 0 ? gatunekObj.wiek.toString() : '';
                              });
                            },
                          );
                        }),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 16),
                          label: const Text('Dodaj'),
                          backgroundColor: Colors.grey.shade200,
                          onPressed: () {
                            _showAddGatunekDialog(setDialogState);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _srednicaController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Średnica (cm) [opcjonalnie]',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _wysokoscController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Wysokość (m) [opcjonalnie]',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _azymutController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Azymut (°) [opcjonalnie]',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _odlController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Odległość (m) [opcjonalnie]',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _wiekController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Wiek (lata)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: mode == DialogMode.addBatch
                  ? [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Zakończenie', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: Colors.green.shade200,
                    foregroundColor: Colors.black87,
                  ),
                  onPressed: () => _handleSaveTree(
                    isBatchNext: true,
                    mode: mode,
                    globalIndex: globalIndex,
                    dynamicGatunki: dynamicGatunki,
                    setDialogState: setDialogState,
                    dialogContext: context,
                  ),
                  child: const Text('Dodaj kolejne'),
                ),
              ]
                  : [
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
                  onPressed: () => _handleSaveTree(
                    isBatchNext: false,
                    mode: mode,
                    globalIndex: globalIndex,
                    dynamicGatunki: dynamicGatunki,
                    setDialogState: setDialogState,
                    dialogContext: context,
                  ),
                  child: Text(mode == DialogMode.edit ? 'Zapisz' : 'Dodaj'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      if (mode == DialogMode.addBatch) {
        setState(() => _isBatchDialogOpen = false);
      }
    });
  }

  void _showAddGatunekDialog(StateSetter setDialogState) {
    final TextEditingController nazwaGatunkuController = TextEditingController();
    final TextEditingController wiekGatunkuController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Nowy gatunek'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nazwaGatunkuController,
                decoration: const InputDecoration(
                  labelText: 'Nazwa (np. SO, BRZ)',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters, // Forces uppercase keyboard layout
              ),
              const SizedBox(height: 16),
              TextField(
                controller: wiekGatunkuController,
                decoration: const InputDecoration(
                  labelText: 'Wiek (lata)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () {
                // Automatically convert name to uppercase
                final String novaNazwa = nazwaGatunkuController.text.trim().toUpperCase();
                final int nowyWiek = int.tryParse(wiekGatunkuController.text.trim()) ?? 0;

                if (novaNazwa.isNotEmpty) {
                  // Check if this exact species + age combination already exists
                  bool alreadyExists = widget.powierzchnia.gatunki.any(
                        (g) => g.nazwa.trim().toUpperCase() == novaNazwa && g.wiek == nowyWiek,
                  );

                  if (!alreadyExists) {
                    setState(() {
                      widget.powierzchnia.gatunki.add(Gatunek(nazwa: novaNazwa, wiek: nowyWiek));
                    });
                    widget.onUpdate();
                  }
                }

                Navigator.of(context).pop();
                setDialogState(() {}); // Refresh dialog UI instantly
              },
              child: const Text('Dodaj'),
            ),
          ],
        );
      },
    );
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
    } else if (_isBatchDialogOpen) {
      _srednicaController.text = diameter.toStringAsFixed(1);
      _log('-> Filled diameter field: $diameter cm');
    } else {
      final int nextIndex = _currentDrzewa.length + 1;
      final String generatedNumer = 'DRZ${nextIndex.toString().padLeft(3, '0')}';

      setState(() {
        // Zmienione z widget.drzewaList na widget.powierzchnia.drzewa
        widget.powierzchnia.drzewa.add(
          DrzewoModel(
            powierzchniaNumer: widget.powierzchnia.numer,
            gatunek: _selectedDrzewoGatunek,
            typ: 'zywe', // Dodany typ dla żywego drzewa
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




// --- UI BUILDER ---

  // --- HELPER FUNCTIONS ---

  int _getInitialAge(String requestedGatunek) {
    final match = widget.powierzchnia.gatunki.firstWhere(
          (g) => g.nazwa.trim().toUpperCase() == requestedGatunek.trim().toUpperCase(),
      orElse: () => Gatunek(nazwa: requestedGatunek, wiek: 0),
    );
    return match.wiek;
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

  int _getAgeForSpecies(String requestedGatunek, List<Gatunek> dynamicGatunki) {
    final match = dynamicGatunki.firstWhere(
          (g) => g.nazwa.trim().toUpperCase() == requestedGatunek.trim().toUpperCase(),
      orElse: () => Gatunek(nazwa: requestedGatunek, wiek: 0),
    );
    return match.wiek;
  }

  void _initializeDialogFields(DialogMode mode, DrzewoModel? existingTree) {
    String defaultGatunek = 'SO';
    if (widget.powierzchnia.gatunki.isNotEmpty) {
      defaultGatunek = widget.powierzchnia.gatunki.first.nazwa;
    }

    if (mode == DialogMode.edit && existingTree != null) {
      _srednicaController.text = existingTree.srednica > 0 ? existingTree.srednica.toString() : '';
      _wysokoscController.text = existingTree.wysokosc > 0 ? existingTree.wysokosc.toString() : '';
      _azymutController.text = existingTree.azymut > 0 ? existingTree.azymut.toString() : '';
      _odlController.text = existingTree.odl > 0 ? existingTree.odl.toString() : '';
      _wiekController.text = existingTree.wiek > 0 ? existingTree.wiek.toString() : _getInitialAge(existingTree.gatunek).toString();

      setState(() {
        _selectedDrzewoGatunek = existingTree.gatunek;
        _selectedDrzewoTyp = existingTree.typ; // <-- Loaded from existing tree
      });
    } else {
      _srednicaController.clear();
      _wysokoscController.clear();
      _azymutController.clear();
      _odlController.clear();

      setState(() {
        _selectedDrzewoGatunek = defaultGatunek;
        _selectedDrzewoTyp = 'zywe'; // <-- Default for new tree
      });

      int initialAge = _getInitialAge(defaultGatunek);
      _wiekController.text = initialAge > 0 ? initialAge.toString() : '';
    }

    if (mode == DialogMode.addBatch) {
      setState(() => _isBatchDialogOpen = true);
    }
  }

  void _handleSaveTree({
    required bool isBatchNext,
    required DialogMode mode,
    required int? globalIndex,
    required List<Gatunek> dynamicGatunki,
    required StateSetter setDialogState,
    required BuildContext dialogContext,
  }) {
    final newTree = DrzewoModel(
      powierzchniaNumer: widget.powierzchnia.numer,
      gatunek: _selectedDrzewoGatunek,
      typ: _selectedDrzewoTyp, // <-- CHANGE THIS LINE
      srednica: double.tryParse(_srednicaController.text.trim()) ?? 0.0,
      // ...
      wysokosc: double.tryParse(_wysokoscController.text.trim()) ?? 0.0,
      azymut: double.tryParse(_azymutController.text.trim()) ?? 0.0,
      odl: double.tryParse(_odlController.text.trim()) ?? 0.0,
      wiek: int.tryParse(_wiekController.text.trim()) ?? _getAgeForSpecies(_selectedDrzewoGatunek, dynamicGatunki),
    );

    setState(() {
      if (mode == DialogMode.edit && globalIndex != null) {
        widget.powierzchnia.drzewa[globalIndex] = newTree;
      } else {
        widget.powierzchnia.drzewa.add(newTree);
      }
    });

    widget.onUpdate();

    if (isBatchNext) {
      _srednicaController.clear();
      _wysokoscController.clear();
      _azymutController.clear();
      _odlController.clear();

      setState(() => _selectedDrzewoGatunek = dynamicGatunki.first.nazwa);
      int nextBatchAge = _getAgeForSpecies(dynamicGatunki.first.nazwa, dynamicGatunki);
      _wiekController.text = nextBatchAge > 0 ? nextBatchAge.toString() : '';

      setDialogState(() {});
    } else {
      Navigator.pop(dialogContext);
    }
  }



}