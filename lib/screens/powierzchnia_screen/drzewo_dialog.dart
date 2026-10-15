import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lesna_app_1/screens/powierzchnia_screen/powierzchnia_details.dart';
import 'package:lesna_app_1/screens/powierzchnia_screen/powierzchnia_model.dart';

import '../../connector/bluetooth_service.dart';

class DrzewoDialog extends StatefulWidget {
  final PowierzchniaModel powierzchnia;
  final DialogMode initialMode;
  final int? initialGlobalIndex;
  final DrzewoModel? existingTree;
  final List<Gatunek> initialDynamicGatunki;
  final String selectedWarstwa; // <-- Changed from int to String
  final VoidCallback onUpdate;
  final double maxRadiusSurface; // Add this parameter

  const DrzewoDialog({
    Key? key,
    required this.powierzchnia,
    required this.initialMode,
    required this.initialDynamicGatunki,
    required this.selectedWarstwa,
    required this.onUpdate,
    required this.maxRadiusSurface, // <-- Added here
    this.initialGlobalIndex,
    this.existingTree,
  }) : super(key: key);

  @override
  State<DrzewoDialog> createState() => _DrzewoDialogState();
}

class _DrzewoDialogState extends State<DrzewoDialog> {
  late DialogMode currentMode;
  late int? currentGlobalIndex;
  late List<Gatunek> _localGatunki;
  String? numerError;
  String? odlError; // <-- Add this new one
  String? srednicaError;
  String? wysokoscError;
  String? azymutError;

  StreamSubscription<double>? _treeSubscription;

  final TextEditingController _numerDrzewaController = TextEditingController();
  final TextEditingController _srednicaController = TextEditingController();
  final TextEditingController _wysokoscController = TextEditingController();
  // final TextEditingController _azymutController = TextEditingController();
  final TextEditingController _odlController = TextEditingController();
  final TextEditingController _wiekController = TextEditingController();
  late final TextEditingController _azymutController;
  final FocusNode _srednicaFocusNode = FocusNode();
  final TextEditingController _notatkaController = TextEditingController();

  String _selectedDrzewoTyp = 'zywe';
  String _selectedDrzewoGatunek = '';


  @override
  void initState() {
    super.initState();
    currentMode = widget.initialMode;
    currentGlobalIndex = widget.initialGlobalIndex;
    _localGatunki = List.from(widget.initialDynamicGatunki);
    _azymutController = TextEditingController(
      text: widget.existingTree?.azymut != null
          ? widget.existingTree!.azymut.toString()
          : '',
    );

    _initializeDialogFields(currentMode, widget.existingTree);
// Initialize it once when the widget is created
    if (currentMode == DialogMode.edit && currentGlobalIndex != null) {
      _numerDrzewaController.text = widget.powierzchnia.drzewa[currentGlobalIndex!].numer.toString();
    } else {
      _generateNextNumber();
    }

    _treeSubscription = BluetoothServiceManager().onTreeMeasured.listen((diameter) {
      if (mounted) {
        setState(() {
          _srednicaController.text = diameter.toStringAsFixed(1);
          _srednicaController.selection = TextSelection.fromPosition(
            TextPosition(offset: _srednicaController.text.length),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _treeSubscription?.cancel();
    _numerDrzewaController.dispose();
    _srednicaController.dispose();
    _wysokoscController.dispose();
    _azymutController.dispose();
    _odlController.dispose();
    _wiekController.dispose();
    _srednicaFocusNode.dispose();
    _notatkaController.dispose(); // <--
    super.dispose();
  }

  void _generateNextNumber() {
    bool isGwozdz = _selectedDrzewoTyp == 'zywe_gwozdz';

    // 1. Filter the trees to match the current numbering sequence
    var relevantTrees = widget.powierzchnia.drzewa.where((tree) {
      bool isTreeGwozdz = tree.typ['state'] == 'zywe' && tree.typ['type'] == 'gwozdz';

      // If we are adding a gwozdz, only look at gwozdz numbers.
      // Otherwise, look at all regular trees (dead, alive, broken, etc.)
      return isGwozdz ? isTreeGwozdz : !isTreeGwozdz;
    }).toList();

    // 2. Find the highest number in that specific filtered list
    int maxNumer = relevantTrees.isNotEmpty
        ? relevantTrees.map((e) => e.numer).reduce((a, b) => a > b ? a : b)
        : 0;

    _numerDrzewaController.text = (maxNumer + 1).toString();
  }

  void _initializeDialogFields(DialogMode mode, DrzewoModel? tree) {
    if (mode == DialogMode.edit && tree != null) {
      _selectedDrzewoGatunek = tree.gatunek;

      // Inside _initializeDialogFields:
      if (tree.typ['state'] == 'zywe') {
        if (tree.typ['type'] == 'gwozdz') {
          _selectedDrzewoTyp = 'zywe_gwozdz'; // <-- Checks for the gwozdz type
        } else {
          _selectedDrzewoTyp = 'zywe';
        }
      } else {
        _selectedDrzewoTyp = (tree.typ['type'] != null && tree.typ['type']!.isNotEmpty)
            ? tree.typ['type']!
            : 'posusz';
      }

      _srednicaController.text = tree.srednica > 0 ? tree.srednica.toString().replaceAll('.', ',') : '';
      _wysokoscController.text = tree.wysokosc > 0 ? tree.wysokosc.toString().replaceAll('.', ',') : '';

      // Safely handle nullable double? azymut
      _azymutController.text = (tree.azymut != null && tree.azymut! > 0)
          ? tree.azymut!.toStringAsFixed(0)
          : '';

      _odlController.text = tree.odl > 0 ? tree.odl.toString().replaceAll('.', ',') : '';
      _wiekController.text = tree.wiek > 0 ? tree.wiek.toString() : '';

      // --- NEW: Load existing note ---
      _notatkaController.text = tree.notes;
    } else {
      _srednicaController.clear();
      _wysokoscController.clear();
      _azymutController.clear();
      _odlController.clear();

      // --- NEW: Clear the note for a fresh dialog ---
      _notatkaController.clear();

      _selectedDrzewoTyp = 'zywe';

      if (_localGatunki.isNotEmpty) {
        _selectedDrzewoGatunek = _localGatunki.first.nazwa;
        _wiekController.text = _localGatunki.first.wiek > 0 ? _localGatunki.first.wiek.toString() : '';
      }
    }
  }

  String? _checkNumerExists(String val) {
    int? inputtedNumer = int.tryParse(val.trim());

    if (inputtedNumer != null) {
      bool isGwozdz = _selectedDrzewoTyp == 'zywe_gwozdz';

      // 1. Get numbers ONLY for the relevant sequence (gwozdz vs standard tree)
      List<int> relevantNumbers = widget.powierzchnia.drzewa.where((tree) {
        bool isTreeGwozdz = tree.typ['state'] == 'zywe' && tree.typ['type'] == 'gwozdz';
        return isGwozdz ? isTreeGwozdz : !isTreeGwozdz;
      }).map((tree) => tree.numer).toList();

      // 2. If editing, remove the tree's original number so it doesn't collide with itself
      if (currentMode == DialogMode.edit && currentGlobalIndex != null) {
        int originalNumber = widget.powierzchnia.drzewa[currentGlobalIndex!].numer;
        relevantNumbers.remove(originalNumber);
      }

      // 3. Check for duplicates and return a context-aware error message
      if (relevantNumbers.contains(inputtedNumer)) {
        return isGwozdz ? 'Numer gwoździa już istnieje' : 'Numer drzewa już zdefiniowano';
      }
    }

    return null;
  }

  String? _checkOdlegloscLimit(String val) {
    // Replace comma with dot to handle Polish decimal inputs (e.g., "11,2")
    double? inputtedOdl = double.tryParse(val.trim().replaceAll(',', '.'));

    if (inputtedOdl != null) {
      if (inputtedOdl > widget.maxRadiusSurface) {
        return 'Odległość przekracza promień (${widget.maxRadiusSurface} m)';
      }
    }

    return null;
  }

  String? _checkSrednicaLimit(String val) {
    if (val.trim().isEmpty) return null; // Optional: change to error string if you also want to block empty values here
    double? parsedVal = double.tryParse(val.trim().replaceAll(',', '.'));
    if (parsedVal != null && parsedVal < 7) {
      return 'Średnica musi wynosić min. 7 cm';
    }
    return null;
  }

  String? _checkWysokoscLimit(String val) {
    if (val.trim().isEmpty) return null;
    double? parsedVal = double.tryParse(val.trim().replaceAll(',', '.'));
    if (parsedVal != null && parsedVal > 99) {
      return 'Wysokość maks. 99 m';
    }
    return null;
  }

  String? _checkAzymutLimit(String val) {
    // If the user leaves it empty, return null so no red error appears
    if (val.trim().isEmpty) {
      return null;
    }

    // Use double.tryParse to support both integers (0, 360) and decimals (e.g., 12.5)
    final double? azymut = double.tryParse(val);
    if (azymut == null) {
      return 'Błędny format';
    }

    // Check the valid range for azimuth (0 to 360 degrees)
    if (azymut < 0 || azymut > 360) {
      return 'Wartość 0-360';
    }

    return null;
  }

  List<int> _getExistingTreeNumbers() {
    return widget.powierzchnia.drzewa.map((drzewo) => drzewo.numer).toList();
  }

  @override
  Widget build(BuildContext context) {
    final double verticalSpacing = 10.0;
    final double horizontalSpacing = 8.0;

    if ((_selectedDrzewoGatunek.isEmpty || !_localGatunki.any((g) => g.nazwa == _selectedDrzewoGatunek)) && _localGatunki.isNotEmpty) {
      _selectedDrzewoGatunek = _localGatunki.first.nazwa;
      _wiekController.text = _localGatunki.first.wiek > 0 ? _localGatunki.first.wiek.toString() : '';
    }

    // --- NEW: Check if 'gwozdz' is selected ---
    bool isGwozdz = _selectedDrzewoTyp == 'zywe_gwozdz';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNumerInput(),
              SizedBox(height: verticalSpacing),

              _buildStanDrzewaDropdown(),
              SizedBox(height: verticalSpacing),

              // --- HIDE IF GWOZDZ ---
              if (!isGwozdz) ...[
                _buildGatunekRow(horizontalSpacing),
                SizedBox(height: verticalSpacing),

                _buildSrednicaInput(),
                SizedBox(height: verticalSpacing),
              ],

              _buildOdlegloscInput(),
              SizedBox(height: verticalSpacing),

              _buildAzymutInput(),
              SizedBox(height: verticalSpacing),

              // --- HIDE IF GWOZDZ ---
              if (!isGwozdz) ...[
                _buildWysokoscInput(),
                SizedBox(height: verticalSpacing),
              ],

              _buildNotatkaInput(),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
      actions: _buildActionButtons(),
    );
  }

// --- EXTRACTED WIDGET METHODS ---

  Widget _buildNumerInput() {
    bool isGwozdz = _selectedDrzewoTyp == 'zywe_gwozdz';

    return TextField(
      controller: _numerDrzewaController,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (val) {
        setState(() {
          numerError = _checkNumerExists(val);
        });
      },
      decoration: InputDecoration(
        labelText: isGwozdz ? 'Numer gwoździa' : 'Numer drzewa',
        errorText: numerError,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildStanDrzewaDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedDrzewoTyp.isNotEmpty ? _selectedDrzewoTyp : 'zywe',
      decoration: InputDecoration(
        labelText: 'Stan drzewa',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: const [
        DropdownMenuItem(value: 'zywe', child: Text('Żywe')),
        DropdownMenuItem(value: 'posusz', child: Text('Posusz (martwe stojące)')),
        DropdownMenuItem(value: 'zlomy', child: Text('Złomy (stojące złamane)')),
        DropdownMenuItem(value: 'wywroty', child: Text('Wywroty i ścięte (leżące)')),
        DropdownMenuItem(value: 'fragmenty', child: Text('Fragmenty (kłody, gałęzie)')),
        DropdownMenuItem(value: 'zywe_gwozdz', child: Text('Gwoździe')),
      ],
      // Inside _buildStanDrzewaDropdown()
      onChanged: (String? val) {
        if (val != null) {
          setState(() {
            _selectedDrzewoTyp = val;

            // Auto-update the number sequence when switching between tree/gwozdz
            if (currentMode != DialogMode.edit) {
              _generateNextNumber();
              numerError = _checkNumerExists(_numerDrzewaController.text);
            }
          });
        }
      },
    );
  }

  Widget _buildGatunekRow(double horizontalSpacing) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            value: _localGatunki.any((g) => '${g.nazwa}_${g.wiek}' == '${_selectedDrzewoGatunek}_${_wiekController.text.isEmpty ? '0' : _wiekController.text}')
                ? '${_selectedDrzewoGatunek}_${_wiekController.text.isEmpty ? '0' : _wiekController.text}'
                : null,
            decoration: InputDecoration(
              labelText: 'Gatunek',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: _localGatunki.map((gatunekObj) {
              final String combinedLabel = '${gatunekObj.nazwa}${gatunekObj.wiek}';
              final String uniqueKey = '${gatunekObj.nazwa}_${gatunekObj.wiek}';
              return DropdownMenuItem<String>(
                value: uniqueKey,
                child: Text(combinedLabel),
              );
            }).toList(),
            onChanged: (String? val) {
              if (val != null) {
                setState(() {
                  final selectedGatunekObj = _localGatunki.firstWhere(
                        (g) => '${g.nazwa}_${g.wiek}' == val,
                  );
                  _selectedDrzewoGatunek = selectedGatunekObj.nazwa;
                  _wiekController.text = selectedGatunekObj.wiek > 0
                      ? selectedGatunekObj.wiek.toString()
                      : '';
                });
              }
            },
          ),
        ),
        SizedBox(width: horizontalSpacing),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: IconButton(
            icon: const Icon(Icons.add, color: Colors.black87),
            tooltip: 'Dodaj nowy gatunek',
            onPressed: _showAddGatunekDialog,
          ),
        ),
      ],
    );
  }

  Widget _buildSrednicaInput() {
    return TextField(
      controller: _srednicaController,
      focusNode: _srednicaFocusNode,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: [AutoDecimalFormatter(decimalDigits: 1)],
      onChanged: (val) {
        setState(() {
          srednicaError = _checkSrednicaLimit(val);
        });
      },
      decoration: InputDecoration(
        labelText: 'Średnica (cm)',
        errorText: srednicaError,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildOdlegloscInput() {
    return TextField(
      controller: _odlController,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: [AutoDecimalFormatter(decimalDigits: 2)],
      onChanged: (val) {
        setState(() {
          odlError = _checkOdlegloscLimit(val);
        });
      },
      decoration: InputDecoration(
        labelText: 'Odległość (m)',
        errorText: odlError,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildAzymutInput() {
    return TextField(
      controller: _azymutController,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (val) {
        setState(() {
          azymutError = _checkAzymutLimit(val);
          if (widget.existingTree != null) {
            widget.existingTree!.azymut = val.trim().isEmpty ? null : double.tryParse(val);
          }
        });
      },
      decoration: InputDecoration(
        labelText: 'Azymut (°)',
        errorText: azymutError,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildWysokoscInput() {
    bool isMartwe = ['posusz', 'zlomy', 'wywroty', 'fragmenty'].contains(_selectedDrzewoTyp);

    return TextField(
      controller: _wysokoscController,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: [AutoDecimalFormatter(decimalDigits: 1)],
      onChanged: (val) {
        setState(() {
          wysokoscError = _checkWysokoscLimit(val);
        });
      },
      decoration: InputDecoration(
        labelText: isMartwe ? 'Wysokość / Długość (m)' : 'Wysokość (m)',
        errorText: wysokoscError,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildNotatkaInput() {
    return TextField(
      controller: _notatkaController,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.sentences,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'Notatka',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  List<Widget> _buildActionButtons() {
    return [
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: numerError != null ? Colors.grey.shade300 : Colors.green.shade200,
          foregroundColor: Colors.black87,
          alignment: Alignment.center,
        ),
        onPressed: numerError != null ? null : () => _handleSaveTree(false),
        child: const Text('Zakończ edycję', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: numerError != null ? Colors.grey.shade300 : Colors.green.shade200,
          foregroundColor: Colors.black87,
          alignment: Alignment.center,
        ),
        onPressed: numerError != null ? null : () => _handleSaveTree(true),
        child: const Text('Dodaj następne', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    ];
  }

  void _showAddGatunekDialog() {
    final TextEditingController nazwaGatunkuController = TextEditingController();
    final TextEditingController wiekGatunkuController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
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
                textCapitalization: TextCapitalization.characters,
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
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () {
                final String novaNazwa = nazwaGatunkuController.text.trim().toUpperCase();
                final int nowyWiek = int.tryParse(wiekGatunkuController.text.trim()) ?? 0;

                if (novaNazwa.isNotEmpty) {
                  bool alreadyExists = widget.powierzchnia.gatunki.any(
                        (g) => g.nazwa.trim().toUpperCase() == novaNazwa && g.wiek == nowyWiek,
                  );

                  if (!alreadyExists) {
                    final newGatunek = Gatunek(nazwa: novaNazwa, wiek: nowyWiek);

                    widget.powierzchnia.gatunki.add(newGatunek);
                    widget.onUpdate();

                    setState(() {
                      _localGatunki.add(newGatunek);
                      _selectedDrzewoGatunek = novaNazwa;
                      _wiekController.text = nowyWiek > 0 ? nowyWiek.toString() : '';
                    });
                  }
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Dodaj'),
            ),
          ],
        );
      },
    );
  }

  void _handleSaveTree(bool isBatchNext) {
    if (_selectedDrzewoGatunek.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wybierz gatunek przed zapisaniem!')),
      );
      return;
    }

    // 1. Copy prior dates if editing, or start empty if new
    List<String> updatedDates = (currentMode == DialogMode.edit && widget.existingTree != null)
        ? List<String>.from(widget.existingTree!.listDates)
        : [];

    // 2. Append the current timestamp
    final String currentDate = DateTime.now().toIso8601String();
    updatedDates.add(currentDate);

    // If the text field is empty, inputtedAzymut becomes null naturally
    final double? inputtedAzymut = double.tryParse(_azymutController.text.replaceAll(',', '.'));

    String inputtedNumerText = _numerDrzewaController.text.trim();
    bool numberExists = _checkNumerExists(inputtedNumerText) != null;

    if (numberExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ten numer drzewa już istnieje! Wpisz inny.')),
      );
      return;
    }

    int inputtedNumer = int.tryParse(inputtedNumerText) ?? 0;

    // --- UPDATED: Convert the String dropdown value to the new Map structure ---
    // it will save as zywe gwozdz -but it is treated as just gwozdz
    Map<String, String> parsedTypMap;
    if (_selectedDrzewoTyp == 'zywe') {
      parsedTypMap = {'state': 'zywe', 'type': ''};
    } else if (_selectedDrzewoTyp == 'zywe_gwozdz') {
      parsedTypMap = {'state': 'zywe', 'type': 'gwozdz'};
    } else {
      parsedTypMap = {'state': 'martwe', 'type': _selectedDrzewoTyp};
    }

    final newTree = DrzewoModel(
      numer: inputtedNumer,
      powierzchniaNumer: widget.powierzchnia.numer,
      gatunek: _selectedDrzewoGatunek,
      typ: parsedTypMap,
      warstwa: (currentMode == DialogMode.edit && widget.existingTree != null)
          ? widget.existingTree!.warstwa
          : widget.selectedWarstwa,
      srednica: double.tryParse(_srednicaController.text.replaceAll(',', '.')) ?? 0.0,
      wysokosc: double.tryParse(_wysokoscController.text.replaceAll(',', '.')) ?? 0.0,
      azymut: inputtedAzymut,
      odl: double.tryParse(_odlController.text.replaceAll(',', '.')) ?? 0.0,
      wiek: int.tryParse(_wiekController.text) ?? 0,
      klasaRozkladu: (currentMode == DialogMode.edit && widget.existingTree != null)
          ? widget.existingTree!.klasaRozkladu
          : 0,
      notes: _notatkaController.text.trim(),
      listDates: updatedDates, // <-- PASS THE UPDATED LIST HERE
    );

    setState(() {
      if (currentMode == DialogMode.edit && currentGlobalIndex != null) {
        widget.powierzchnia.drzewa[currentGlobalIndex!] = newTree;
      } else {
        widget.powierzchnia.drzewa.add(newTree);
      }
      widget.powierzchnia.drzewa.sort((a, b) => a.numer.compareTo(b.numer));
    });

    widget.onUpdate();

    if (isBatchNext) {
      setState(() {
        _srednicaController.clear();
        _wysokoscController.clear();
        _azymutController.clear();
        _odlController.clear();

        // --- UPDATED: Clear the note for the next tree ---
        _notatkaController.clear();

        _generateNextNumber();

        currentMode = DialogMode.addBatch;
        currentGlobalIndex = null;
        numerError = null;

        _srednicaFocusNode.requestFocus();
      });
    } else {
      Navigator.pop(context);
    }
  }
}