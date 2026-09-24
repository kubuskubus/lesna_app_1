import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../data_handler/data_handler.dart';
import 'powierzchnia_model.dart';
import '../connector/bluetooth_service.dart';

class PowierzchniaDetailScreen extends StatefulWidget {
  const PowierzchniaDetailScreen({
    super.key,
    required this.powierzchnia,
    required this.onUpdate,
  });

  final PowierzchniaModel powierzchnia;
  final VoidCallback onUpdate;

  @override
  State<PowierzchniaDetailScreen> createState() => _PowierzchniaDetailScreenState();
}

enum DialogMode { addSingle, edit, addBatch }

class _PowierzchniaDetailScreenState extends State<PowierzchniaDetailScreen> {
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

  void placeholderFunction() {
    {} // Does nothing
  }

  @override
  void initState() {
    super.initState();
    _treeSubscription = BluetoothServiceManager().onTreeMeasured.listen(_handleIncomingBleMeasurement);
    placeholderFunction();

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

  @override
  void dispose() {
    _srednicaController.dispose();
    _wysokoscController.dispose();
    _scanSubscription?.cancel();
    _treeSubscription?.cancel();
    super.dispose();
  }

  void _log(String text) {
    setState(() {
      _logs.add(text);
    });
    print(text);
  }



  void _showDrzewoDialog({
    required DialogMode mode,
    int? globalIndex,
    DrzewoModel? existingTree,
  }) {
    List<dynamic> rawTreeList = widget.powierzchnia.wydz_data['list_of_trees'] ?? [];

    // Helper function to dynamically look up age from the list_of_trees
    int getAgeForSpecies(String requestedGatunek) {
      if (rawTreeList.isEmpty) return 0;

      for (var tree in rawTreeList) {
        if (tree is Map<String, dynamic> || tree is Map) {
          // Look for the species under a few possible keys and clean up the string
          String treeSpecies = (tree['name'] ?? tree['Gatunek'] ?? tree['species'] ?? tree['gat'] ?? '')
              .toString()
              .trim()
              .toUpperCase();

          // Clean up the requested species string just in case
          String requested = requestedGatunek.trim().toUpperCase();

          if (treeSpecies == requested && tree['age'] != null) {
            return int.tryParse(tree['age'].toString()) ?? 0;
          }
        }
      }

      return 0;
    }

    // 1. Initialize initial species and fields depending on mode
    if (mode == DialogMode.edit && existingTree != null) {
      _srednicaController.text = existingTree.srednica > 0 ? existingTree.srednica.toString() : '';
      _wysokoscController.text = existingTree.wysokosc > 0 ? existingTree.wysokosc.toString() : '';
      _azymutController.text = existingTree.azymut > 0 ? existingTree.azymut.toString() : '';
      _odlController.text = existingTree.odl > 0 ? existingTree.odl.toString() : '';
      _wiekController.text = existingTree.wiek > 0 ? existingTree.wiek.toString() : getAgeForSpecies(existingTree.gatunek).toString();
      setState(() => _selectedDrzewoGatunek = existingTree.gatunek);
    } else {
      _srednicaController.clear();
      _wysokoscController.clear();
      _azymutController.clear();
      _odlController.clear();
      setState(() => _selectedDrzewoGatunek = 'SO'); // Default species

      // Set initial age for default species ('SO') by reading from list_of_trees
      int initialAge = getAgeForSpecies('SO');
      _wiekController.text = initialAge > 0 ? initialAge.toString() : '';
    }

    if (mode == DialogMode.addBatch) {
      setState(() => _isBatchDialogOpen = true);
    }

    showDialog(
      context: context,
      barrierDismissible: mode != DialogMode.addBatch,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final int nextIndex = rawTreeList.length + 1;
            String currentNumer = '';
            String title = '';

            if (mode == DialogMode.edit && globalIndex != null) {
              currentNumer = 'DRZ${(globalIndex + 1).toString().padLeft(3, '0')}';
              title = 'Edytuj drzewo ($currentNumer)';
            } else {
              currentNumer = 'DRZ${nextIndex.toString().padLeft(3, '0')}';
              title = mode == DialogMode.addBatch
                  ? 'Szybkie dodawanie ($currentNumer)'
                  : 'Nowe drzewo ($currentNumer)';
            }

            void placeholderFunction() {
              {}
            }

            // 3. Main object saving logic
            void handleSave(bool isBatchNext) {
              // Create the Dart object for the UI
              final newTree = DrzewoModel(
                powierzchniaNumer: widget.powierzchnia.numer,
                gatunek: _selectedDrzewoGatunek,
                typ: 'zywe',
                srednica: double.tryParse(_srednicaController.text.trim()) ?? 0.0,
                wysokosc: double.tryParse(_wysokoscController.text.trim()) ?? 0.0,
                azymut: double.tryParse(_azymutController.text.trim()) ?? 0.0,
                odl: double.tryParse(_odlController.text.trim()) ?? 0.0,
                wiek: int.tryParse(_wiekController.text.trim()) ?? getAgeForSpecies(_selectedDrzewoGatunek),
              );

              setState(() {
                // Ensure JSON list is initialized
                if (widget.powierzchnia.wydz_data['list_of_trees'] == null) {
                  widget.powierzchnia.wydz_data['list_of_trees'] = <dynamic>[];
                }
                List jsonTreesList = widget.powierzchnia.wydz_data['list_of_trees'];

                if (mode == DialogMode.edit && globalIndex != null) {
                  // Update BOTH UI list and JSON map
                  widget.powierzchnia.drzewa[globalIndex] = newTree;
                  jsonTreesList[globalIndex] = newTree.toJson();
                } else {
                  // Add to BOTH UI list and JSON map
                  widget.powierzchnia.drzewa.add(newTree);
                  jsonTreesList.add(newTree.toJson());
                }
              });

              widget.onUpdate();

              if (isBatchNext) {
                _srednicaController.clear();
                _wysokoscController.clear();
                _azymutController.clear();
                _odlController.clear();

                setState(() => _selectedDrzewoGatunek = 'SO');
                int nextBatchAge = getAgeForSpecies('SO');
                _wiekController.text = nextBatchAge > 0 ? nextBatchAge.toString() : '';

                setDialogState(() {});
              } else {
                Navigator.pop(context);
              }
            }

            // 4. Build Dialog UI
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gatunek', style: TextStyle(color: Colors.black54, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _gatunki.map((gatunek) {
                        return ChoiceChip(
                          label: Text(gatunek),
                          selected: _selectedDrzewoGatunek == gatunek,
                          selectedColor: Colors.deepPurple.shade100,
                          onSelected: (selected) {
                            setDialogState(() {
                              _selectedDrzewoGatunek = gatunek;

                              // AUTOMATICALLY UPDATE AGE WHEN SPECIES CHANGES:
                              int suggestedAge = getAgeForSpecies(gatunek);
                              _wiekController.text = suggestedAge > 0 ? suggestedAge.toString() : '';
                            });
                          },
                        );
                      }).toList(),
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
                  onPressed: () => handleSave(true),
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
                  onPressed: () => handleSave(false),
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



  Widget _buildBatchFormContent(StateSetter setDialogState) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gatunek', style: TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 8),
          _buildSpeciesSelector(setDialogState),
          const SizedBox(height: 20),
          _buildMeasurementField(_srednicaController, 'Średnica (cm) [opcjonalnie]'),
          const SizedBox(height: 16),
          _buildMeasurementField(_wysokoscController, 'Wysokość (m) [opcjonalnie]'),
        ],
      ),
    );
  }

  Widget _buildSpeciesSelector(StateSetter setDialogState) {
    return Wrap(
      spacing: 8,
      children: _gatunki.map((gatunek) {
        final isSelected = _selectedDrzewoGatunek == gatunek;
        return ChoiceChip(
          label: Text(gatunek),
          selected: isSelected,
          selectedColor: Colors.deepPurple.shade100,
          onSelected: (selected) {
            setDialogState(() {
              _selectedDrzewoGatunek = gatunek;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildMeasurementField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  List<Widget> _buildBatchDialogActions(String generatedNumer, StateSetter setDialogState) {
    return [
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
        onPressed: () => _handleBatchAddNext(generatedNumer, setDialogState),
        child: const Text('Dodaj kolejne'),
      ),
    ];
  }

  void _handleBatchAddNext(String generatedNumer, StateSetter setDialogState) {
    setState(() {
      // Zmienione z widget.drzewaList na widget.powierzchnia.drzewa
      widget.powierzchnia.drzewa.add(
        DrzewoModel(
          powierzchniaNumer: widget.powierzchnia.numer,
          gatunek: _selectedDrzewoGatunek,
          typ: 'zywe', // Dodany typ dla żywego drzewa
          srednica: double.tryParse(_srednicaController.text.trim()) ?? 0.0,
          wysokosc: double.tryParse(_wysokoscController.text.trim()) ?? 0.0,
        ),
      );
    });

    widget.onUpdate();

    _srednicaController.clear();
    _wysokoscController.clear();

    setDialogState(() {});
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
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade200,
              foregroundColor: Colors.black87,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => _showDrzewoDialog(mode: DialogMode.addBatch),
            icon: const Icon(Icons.playlist_add, size: 18),
            label: const Text('Add many'),
          ),
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
    final bool isEmpty = _currentDrzewa.isEmpty && _currentDrzewaMartwe.isEmpty;

    return Expanded(
      child: isEmpty ? _buildEmptyState() : _buildDataList(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        'Brak danych. Kliknij "+ dodaj wiele" lub "+ drzewo" aby dodać.',
        style: TextStyle(color: Colors.grey),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDataList() {
    return ListView(
      children: [
        if (_currentDrzewa.isNotEmpty) ...[
          _buildSectionHeader('Drzewa'),
          ..._currentDrzewa.asMap().entries.map((entry) {
            int localIndex = entry.key;
            DrzewoModel drzewo = entry.value;
            // Find the exact index in the unified list to allow editing/deleting
            int globalIndex = widget.powierzchnia.drzewa.indexOf(drzewo);
            return _buildDrzewoCard(drzewo, localIndex, globalIndex);
          }),
          const SizedBox(height: 16),
        ],
        if (_currentDrzewaMartwe.isNotEmpty) ...[
          _buildSectionHeader('Drzewa Martwe'),
          ..._currentDrzewaMartwe.asMap().entries.map((entry) {
            int localIndex = entry.key;
            // Use the unified DrzewoModel
            DrzewoModel drzewoMartwe = entry.value;
            // Find the exact index in the unified list
            int globalIndex = widget.powierzchnia.drzewa.indexOf(drzewoMartwe);
            return _buildDrzewoMartweCard(drzewoMartwe, localIndex, globalIndex);
          }),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
    );
  }

  Widget _buildDrzewoCard(DrzewoModel drzewo, int localIndex, int globalIndex) {
    final String numer = 'DRZ${(localIndex + 1).toString().padLeft(3, '0')}';

    String subtitleText = 'Gatunek: ${drzewo.gatunek}';
    if (drzewo.srednica > 0) subtitleText += ' | Średnica: ${drzewo.srednica} cm';
    if (drzewo.wysokosc > 0) subtitleText += ' | Wysokość: ${drzewo.wysokosc} m';

    bool isActiveTree = _isMeasurementModeActive && _currentMeasurementIndex == localIndex;

    return Card(
      color: isActiveTree ? Colors.blue.shade50 : null,
      shape: isActiveTree
          ? RoundedRectangleBorder(
        side: const BorderSide(color: Colors.blue, width: 2),
        borderRadius: BorderRadius.circular(12),
      )
          : null,
      child: ListTile(
        onTap: () {
          setState(() {
            _isMeasurementModeActive = true;
            _currentMeasurementIndex = localIndex;
          });

          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Measurement mode started at $numer'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        onLongPress: () {
          _showDrzewoDialog(
            mode: DialogMode.edit,
            globalIndex: globalIndex,
            existingTree: drzewo,
          );
        },
        title: Text(numer, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitleText),
        trailing: IconButton(
          icon: const Icon(Icons.delete, size: 18, color: Colors.red),
          onPressed: () async {
            setState(() {
              // Changed from widget.drzewaList to widget.powierzchnia.drzewa
              widget.powierzchnia.drzewa.removeAt(globalIndex);
              if (isActiveTree) _isMeasurementModeActive = false;
            });
            widget.onUpdate();
          },
        ),
      ),
    );
  }

  Widget _buildDrzewoMartweCard(DrzewoModel drzewoMartwe, int localIndex, int globalIndex) {
    final String numer = 'DM${(localIndex + 1).toString().padLeft(3, '0')}';
    String subtitleText = 'Gatunek: ${drzewoMartwe.gatunek} | Klasa rozkładu: ${drzewoMartwe.klasaRozkladu}';

    return Card(
      child: ListTile(
        title: Text(numer, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitleText),
        trailing: IconButton(
          icon: const Icon(Icons.delete, size: 18, color: Colors.red),
          onPressed: () async {
            setState(() {
              // Changed from widget.drzewaMartweList to widget.powierzchnia.drzewa
              widget.powierzchnia.drzewa.removeAt(globalIndex);
            });
            widget.onUpdate();
          },
        ),
      ),
    );
  }
}