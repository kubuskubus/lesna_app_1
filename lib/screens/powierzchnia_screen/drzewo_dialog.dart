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
    super.dispose();
  }

  void _generateNextNumber() {
    int maxNumer = widget.powierzchnia.drzewa.isNotEmpty
        ? widget.powierzchnia.drzewa.map((e) => e.numer).reduce((a, b) => a > b ? a : b)
        : 0;
    _numerDrzewaController.text = (maxNumer + 1).toString();
  }

  void _initializeDialogFields(DialogMode mode, DrzewoModel? tree) {
    if (mode == DialogMode.edit && tree != null) {
      _selectedDrzewoGatunek = tree.gatunek;
      _selectedDrzewoTyp = tree.typ;
      _srednicaController.text = tree.srednica > 0 ? tree.srednica.toString().replaceAll('.', ',') : '';
      _wysokoscController.text = tree.wysokosc > 0 ? tree.wysokosc.toString().replaceAll('.', ',') : '';

      // --- UPDATED: Safely handle nullable double? azymut ---
      _azymutController.text = (tree.azymut != null && tree.azymut! > 0)
          ? tree.azymut!.toStringAsFixed(0)
          : '';

      _odlController.text = tree.odl > 0 ? tree.odl.toString().replaceAll('.', ',') : '';
      _wiekController.text = tree.wiek > 0 ? tree.wiek.toString() : '';
    } else {
      _srednicaController.clear();
      _wysokoscController.clear();
      _azymutController.clear();
      _odlController.clear();
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
      List<int> allNumbers = _getExistingTreeNumbers();

      if (currentMode == DialogMode.edit && currentGlobalIndex != null) {
        int originalNumber = widget.powierzchnia.drzewa[currentGlobalIndex!].numer;
        allNumbers.remove(originalNumber);
      }

      if (allNumbers.contains(inputtedNumer)) {
        return 'Numer drzewa już zdefiniowano';
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
                TextField(
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
                    labelText: 'Numer drzewa',
                    errorText: numerError,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),

                SizedBox(height: verticalSpacing),

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
                    if (val != null) setState(() => _selectedDrzewoTyp = val);
                  },
                ),

                SizedBox(height: verticalSpacing),

                Row(
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
                ),

                SizedBox(height: verticalSpacing),

                TextField(
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
                ),

                SizedBox(height: verticalSpacing),

                TextField(
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
                    labelText: 'Wysokość (m)',
                    errorText: wysokoscError,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),

                SizedBox(height: verticalSpacing),

                TextField(
                  controller: _azymutController, // Make sure this is initialized as TextEditingController(text: '')
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (val) {
                    setState(() {
                      azymutError = _checkAzymutLimit(val);
                      // Update the existingTree model if it exists
                      if (widget.existingTree != null) {
                        // If empty/whitespace -> null, otherwise parse to double (so '0' becomes 0.0)
                        widget.existingTree!.azymut = val.trim().isEmpty ? null : double.tryParse(val);
                      }
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Azymut (°)',
                    errorText: azymutError, // Will show 'Wymagane' if empty
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),

                SizedBox(height: verticalSpacing),

                TextField(
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
                ),
              ],
            ),
          ),
        ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
      actions: [
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
      ],
    );
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

    // If the text field is empty, inputtedAzymut becomes null naturally
    final double? inputtedAzymut = double.tryParse(_azymutController.text.replaceAll(',', '.'));

    // 2. OPTION 1: Parse the azimuth text. If the field is empty, it defaults to 999.0
    // Attempt to read the text. If it is empty, it assigns 999.0
    String inputtedNumerText = _numerDrzewaController.text.trim();
    bool numberExists = _checkNumerExists(inputtedNumerText) != null;

    if (numberExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ten numer drzewa już istnieje! Wpisz inny.')),
      );
      return;
    }

    int inputtedNumer = int.tryParse(inputtedNumerText) ?? 0;
    final newTree = DrzewoModel(
      numer: inputtedNumer,
      powierzchniaNumer: widget.powierzchnia.numer,
      gatunek: _selectedDrzewoGatunek,
      typ: _selectedDrzewoTyp,
      // --- CHANGED: Passing the String directly instead of using int.tryParse ---
      warstwa: (currentMode == DialogMode.edit && widget.existingTree != null)
          ? widget.existingTree!.warstwa
          : widget.selectedWarstwa,
      srednica: double.tryParse(_srednicaController.text.replaceAll(',', '.')) ?? 0.0,
      wysokosc: double.tryParse(_wysokoscController.text.replaceAll(',', '.')) ?? 0.0,
      azymut: inputtedAzymut, // <-- Passes null if the user left it blank
      odl: double.tryParse(_odlController.text.replaceAll(',', '.')) ?? 0.0,
      wiek: int.tryParse(_wiekController.text) ?? 0,
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