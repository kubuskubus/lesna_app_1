import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../data_handler/data_handler.dart';
import 'kontrola_powierzchni.dart';
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
        Padding(
          padding: const EdgeInsets.only(right: 16.0), // Adds a little breathing room on the right edge
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade100,
              foregroundColor: Colors.black87,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => _showDrzewoDialog(mode: DialogMode.addSingle),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Drz.'),
          ),
        ),
      ],
    );
  }

  // Widget _buildHeaderTitle() {
  //   return const Text(
  //     'Panel drzew i martwego drewna',
  //     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  //   );
  // }

  // Widget _buildActionButtonsRow() {
  //   return SingleChildScrollView(
  //     scrollDirection: Axis.horizontal,
  //     child: Row(
  //       children: [
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
          // const SizedBox(width: 12),
          // ElevatedButton.icon(
          //   style: ElevatedButton.styleFrom(
          //     backgroundColor: Colors.green.shade100,
          //     foregroundColor: Colors.black87,
          //     elevation: 0,
          //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          //   ),
          //   onPressed: () => _showDrzewoDialog(mode: DialogMode.addSingle),
          //   icon: const Icon(Icons.add, size: 18),
          //   label: const Text('Tree'),
          // ),
          // const SizedBox(width: 12),
          // ElevatedButton.icon(
          //   style: ElevatedButton.styleFrom(
          //     backgroundColor: _isMeasurementModeActive ? Colors.red.shade100 : Colors.blue.shade100,
          //     foregroundColor: _isMeasurementModeActive ? Colors.red.shade900 : Colors.blue.shade900,
          //     elevation: 0,
          //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          //   ),
          //   onPressed: () {
          //     setState(() {
          //       if (_isMeasurementModeActive) {
          //         _isMeasurementModeActive = false;
          //         _currentMeasurementIndex = -1;
          //         ScaffoldMessenger.of(context).showSnackBar(
          //           const SnackBar(
          //             content: Text('Measurement mode stopped.'),
          //             behavior: SnackBarBehavior.floating,
          //           ),
          //         );
          //       } else {
          //         if (_currentDrzewa.isEmpty) {
          //           ScaffoldMessenger.of(context).showSnackBar(
          //             const SnackBar(
          //               content: Text('List is empty. Add trees first.'),
          //               behavior: SnackBarBehavior.floating,
          //             ),
          //           );
          //           return;
          //         }
          //
          //         _isMeasurementModeActive = true;
          //         _currentMeasurementIndex = -1;
          //
          //         ScaffoldMessenger.of(context).showSnackBar(
          //           const SnackBar(
          //             content: Text('Tap a tree on the list to select where to start.'),
          //             behavior: SnackBarBehavior.floating,
          //           ),
          //         );
          //       }
          //     });
          //   },
          //   icon: Icon(
          //     _isMeasurementModeActive ? Icons.stop : Icons.straighten,
          //     size: 18,
          //   ),
          //   label: Text(_isMeasurementModeActive ? 'Stop' : 'Measurements'),
          // ),
  //       ],
  //     ),
  //   );
  // }



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
    _initializeDialogFields(mode, existingTree);
    _isDrzewoDialogOpen = true;

    DialogMode currentMode = mode;
    int? currentGlobalIndex = globalIndex;

    // --- NEW: Variable to hold the error text for the tree number
    String? numerError;

    // Generate integer number safely based on the highest existing number + 1
    if (currentMode == DialogMode.edit && currentGlobalIndex != null) {
      _numerDrzewaController.text = (currentGlobalIndex + 1).toString();
    } else {
      // Find the maximum 'numer' currently used, default to 0 if list is empty
      int maxNumer = widget.powierzchnia.drzewa.isNotEmpty
          ? widget.powierzchnia.drzewa.map((e) => e.numer).reduce((a, b) => a > b ? a : b)
          : 0;

      _numerDrzewaController.text = (maxNumer + 1).toString();
    }

    showDialog(
      context: context,
      barrierDismissible: currentMode != DialogMode.addBatch,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final List<Gatunek> dynamicGatunki = _getDynamicGatunki();

            if ((_selectedDrzewoGatunek.isEmpty || !dynamicGatunki.any((g) => g.nazwa == _selectedDrzewoGatunek)) && dynamicGatunki.isNotEmpty) {
              _selectedDrzewoGatunek = dynamicGatunki.first.nazwa;
              _wiekController.text = dynamicGatunki.first.wiek > 0 ? dynamicGatunki.first.wiek.toString() : '';
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(currentMode == DialogMode.edit ? 'Edycja drzewa' : 'Nowe drzewo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // --- UPDATED: Numer Drzewa Field with Real-Time Validation
                    TextField(
                      controller: _numerDrzewaController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (val) {
                        setDialogState(() {
                          numerError = _checkNumerExists(val, currentMode, currentGlobalIndex);
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Numer drzewa',
                        errorText: numerError,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: _selectedDrzewoTyp.isNotEmpty ? _selectedDrzewoTyp : 'zywe',
                      decoration: InputDecoration(
                        labelText: 'Stan drzewa',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'zywe', child: Text('Żywe')),
                        DropdownMenuItem(value: 'martwe', child: Text('Martwe')),
                      ],
                      onChanged: (String? val) {
                        if (val != null) {
                          setDialogState(() => _selectedDrzewoTyp = val);
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedDrzewoGatunek,
                            decoration: InputDecoration(
                              labelText: 'Gatunek',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: dynamicGatunki.map((gatunekObj) {
                              final String combinedLabel = '${gatunekObj.nazwa}${gatunekObj.wiek}';
                              return DropdownMenuItem<String>(
                                value: gatunekObj.nazwa,
                                child: Text(combinedLabel),
                              );
                            }).toList(),
                            onChanged: (String? val) {
                              if (val != null) {
                                setDialogState(() {
                                  _selectedDrzewoGatunek = val;
                                  final selectedGatunekObj = dynamicGatunki.firstWhere((g) => g.nazwa == val);
                                  _wiekController.text = selectedGatunekObj.wiek > 0
                                      ? selectedGatunekObj.wiek.toString()
                                      : '';
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add, color: Colors.black87),
                            tooltip: 'Dodaj nowy gatunek',
                            onPressed: () {
                              _showAddGatunekDialog(setDialogState);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: _srednicaController,
                      focusNode: _srednicaFocusNode,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [AutoDecimalFormatter(decimalDigits: 1)],
                      decoration: InputDecoration(
                        labelText: 'Średnica (cm)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: _wysokoscController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [AutoDecimalFormatter(decimalDigits: 1)],
                      decoration: InputDecoration(
                        labelText: 'Wysokość (m)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: _azymutController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Azymut (°)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: _odlController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [AutoDecimalFormatter(decimalDigits: 2)],
                      decoration: InputDecoration(
                        labelText: 'Odległość (m)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: _wiekController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Wiek (lata)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  // Disable button if there is an error
                  onPressed: numerError != null ? null : () => _handleSaveTree(
                    isBatchNext: false,
                    mode: currentMode,
                    globalIndex: currentGlobalIndex,
                    dynamicGatunki: dynamicGatunki,
                    setDialogState: setDialogState,
                    dialogContext: context,
                  ),
                  child: const Text('Koniec', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: numerError != null ? Colors.grey.shade300 : Colors.green.shade200,
                    foregroundColor: Colors.black87,
                  ),
                  // Disable button if there is an error
                  onPressed: numerError != null ? null : () {
                    _handleSaveTree(
                      isBatchNext: true,
                      mode: currentMode,
                      globalIndex: currentGlobalIndex,
                      dynamicGatunki: dynamicGatunki,
                      setDialogState: setDialogState,
                      dialogContext: context,
                    );
                    setDialogState(() {
                      currentMode = DialogMode.addBatch;
                      currentGlobalIndex = null;
                      // Clear any leftover errors when switching to next tree
                      numerError = null;
                    });
                  },
                  child: const Text('Następne'),
                ),
              ],
            );
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

  String? _checkNumerExists(String val, DialogMode currentMode, int? currentGlobalIndex) {
    String inputtedNumer = val.trim();
    for (int i = 0; i < widget.powierzchnia.drzewa.length; i++) {
      // Skip checking the current tree if editing
      if (currentMode == DialogMode.edit && i == currentGlobalIndex) continue;

      String existingNumer = widget.powierzchnia.drzewa[i].numer.toString();
      if (inputtedNumer == existingNumer) {
        return 'Numer drzewa już zdefiniowano';
      }
    }
    return null;
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
    int? globalIndex,
    required List<Gatunek> dynamicGatunki,
    required void Function(void Function()) setDialogState,
    required BuildContext dialogContext,
  }) {
    // 1. Safety check
    if (_selectedDrzewoGatunek.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wybierz gatunek przed zapisaniem!')),
      );
      return;
    }

    // 2. Validate Integer Number using our helper function
    String inputtedNumer = _numerDrzewaController.text.trim();

    // This checks if the number exists (respecting edit mode and globalIndex)
    bool numberExists = _checkNumerExists(inputtedNumer, mode, globalIndex) != null;

    if (numberExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ten numer drzewa już istnieje! Wpisz inny.')),
      );
      return;
    }

    if (numberExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ten numer drzewa już istnieje! Wpisz inny.')),
      );
      return;
    }

    // 3. Form new tree
    final newTree = DrzewoModel(
      numer: int.tryParse(_numerDrzewaController.text) ?? 0, // <-- ADD THIS
      powierzchniaNumer: widget.powierzchnia.numer,
      gatunek: _selectedDrzewoGatunek,
      typ: _selectedDrzewoTyp,
      srednica: double.tryParse(_srednicaController.text.replaceAll(',', '.')) ?? 0.0,
      wysokosc: double.tryParse(_wysokoscController.text.replaceAll(',', '.')) ?? 0.0,
      azymut: double.tryParse(_azymutController.text.replaceAll(',', '.')) ?? 0.0,
      odl: double.tryParse(_odlController.text.replaceAll(',', '.')) ?? 0.0,
      wiek: int.tryParse(_wiekController.text) ?? 0,
    );

    // 4. Save to the list and SORT automatically by tree number
    setState(() {
      if (mode == DialogMode.edit && globalIndex != null) {
        widget.powierzchnia.drzewa[globalIndex] = newTree;
      } else {
        widget.powierzchnia.drzewa.add(newTree);
      }

      // --- NEW: Sort trees numerically from lowest to highest ---
      widget.powierzchnia.drzewa.sort((a, b) => a.numer.compareTo(b.numer));
    });

    widget.onUpdate();

    // 5. Next Tree logic
    if (isBatchNext) {
      setDialogState(() {
        _srednicaController.clear();
        _wysokoscController.clear();
        _azymutController.clear();
        _odlController.clear();

        // --- Generate next integer for the new tree
        final int nextIndex = widget.powierzchnia.drzewa.length + 1;
        _numerDrzewaController.text = nextIndex.toString();
      });
    } else {
      Navigator.pop(dialogContext);
    }
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