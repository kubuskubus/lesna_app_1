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
    _syncGatunkiFromWydzData(); // Synchronizes and saves missing species on open
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


  void _showDrzewoDialog({
    required DialogMode mode,
    int? globalIndex,
    DrzewoModel? existingTree,
  }) {
    // Determine the default species name fallback if needed
    String defaultGatunek = 'SO';

    // 3. Initialize initial species and fields depending on mode (we'll use a temporary lookup or let StatefulBuilder handle it,
    // but let's keep the initialization safe by reading widget.powierzchnia.gatunki directly here too)
    List<Gatunek> initialGatunki = widget.powierzchnia.gatunki;
    if (initialGatunki.isNotEmpty) {
      defaultGatunek = initialGatunki.first.nazwa;
    }

    int getInitialAge(String requestedGatunek) {
      final match = widget.powierzchnia.gatunki.firstWhere(
            (g) => g.nazwa.trim().toUpperCase() == requestedGatunek.trim().toUpperCase(),
        orElse: () => Gatunek(nazwa: requestedGatunek, wiek: 0),
      );
      return match.wiek;
    }

    if (mode == DialogMode.edit && existingTree != null) {
      _srednicaController.text = existingTree.srednica > 0 ? existingTree.srednica.toString() : '';
      _wysokoscController.text = existingTree.wysokosc > 0 ? existingTree.wysokosc.toString() : '';
      _azymutController.text = existingTree.azymut > 0 ? existingTree.azymut.toString() : '';
      _odlController.text = existingTree.odl > 0 ? existingTree.odl.toString() : '';
      _wiekController.text = existingTree.wiek > 0 ? existingTree.wiek.toString() : getInitialAge(existingTree.gatunek).toString();
      setState(() => _selectedDrzewoGatunek = existingTree.gatunek);
    } else {
      _srednicaController.clear();
      _wysokoscController.clear();
      _azymutController.clear();
      _odlController.clear();
      setState(() => _selectedDrzewoGatunek = defaultGatunek);

      int initialAge = getInitialAge(defaultGatunek);
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
            // --- MOVED INSIDE SO IT RE-EVALUATES ON EVERY SET_DIALOG_STATE ---
            List<Gatunek> dynamicGatunki = [];
            if (widget.powierzchnia.gatunki.isNotEmpty) {
              final seen = <String>{};
              dynamicGatunki = widget.powierzchnia.gatunki.where((g) {
                // Combine name and age so SO25 and SO45 are treated as distinct entries
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

            int getAgeForSpecies(String requestedGatunek) {
              final match = dynamicGatunki.firstWhere(
                    (g) => g.nazwa.trim().toUpperCase() == requestedGatunek.trim().toUpperCase(),
                orElse: () => Gatunek(nazwa: requestedGatunek, wiek: 0),
              );
              return match.wiek;
            }
            // -----------------------------------------------------------------

            // Count user-added trees to determine the next ID
            final int nextIndex = widget.powierzchnia.drzewa.length + 1;
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

            // 4. Main object saving logic
            void handleSave(bool isBatchNext) {
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
                int nextBatchAge = getAgeForSpecies(dynamicGatunki.first.nazwa);
                _wiekController.text = nextBatchAge > 0 ? nextBatchAge.toString() : '';

                setDialogState(() {});
              } else {
                Navigator.pop(context);
              }
            }

            // 5. Build Dialog UI
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