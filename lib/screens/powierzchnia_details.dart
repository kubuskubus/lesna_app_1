import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';


import '../data_handler/data_handler.dart';
import 'powierzchnia_model.dart';
import '../connector/bluetooth_service.dart'; // Ensure this points to your BluetoothServiceManager file

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

class _PowierzchniaDetailScreenState extends State<PowierzchniaDetailScreen> {
  // --- Data Handler for Saving ---
  final DataHandler _dataHandler = DataHandler();
  bool _isBatchDialogOpen = false; // Add this line

  // --- Bluetooth State & UUIDs ---
  final List<String> _logs = [];
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<double>? _treeSubscription;

  // Haglöf Digitech BT UUIDs (Nordic UART Service)
  final Guid serviceUuid = Guid("6e400001-b5a3-f393-e0a9-e50e24dcca9e");
  final Guid txUuid = Guid("6e400002-b5a3-f393-e0a9-e50e24dcca9e");
  final Guid rxUuid = Guid("6e400003-b5a3-f393-e0a9-e50e24dcca9e");

  // --- Controllers & State for Grupa ---
  String _selectedGatunek = 'SO';
  final TextEditingController _wiekController = TextEditingController();

  // --- Controllers & State for Drzewo ---
  String _selectedDrzewoGatunek = 'SO';
  final TextEditingController _srednicaController = TextEditingController();
  final TextEditingController _wysokoscController = TextEditingController();

  final List<String> _gatunki = ['SO', 'MD', 'ŚW', 'JD', 'BK'];


  // ==========================================
  // PUT initState() RIGHT HERE
  // ==========================================
  @override
  void initState() {
    super.initState();
    // Listen to global stream and pass incoming diameters to our handler function
    _treeSubscription = BluetoothServiceManager().onTreeMeasured.listen(_handleIncomingBleMeasurement);
  }

  // ==========================================
  // PUT YOUR NEW HANDLER RIGHT AFTER IT
  // ==========================================
  void _handleIncomingBleMeasurement(double diameter) {
    if (_isBatchDialogOpen) {
      // 1. DIALOG IS OPEN: Just push the value into the text box
      _srednicaController.text = diameter.toStringAsFixed(1);
      _log('-> Wypełniono pole średnicy z klupy: $diameter cm');
    } else {
      // 2. DIALOG IS CLOSED: Auto-add directly to the list
      final int nextIndex = widget.powierzchnia.drzewa.length + 1;
      final String generatedNumer = 'DRZ${nextIndex.toString().padLeft(3, '0')}';

      setState(() {
        widget.powierzchnia.drzewa.add({
          'numer': generatedNumer,
          'gatunek': _selectedDrzewoGatunek,
          'srednica': diameter.toStringAsFixed(1),
          'wysokosc': '',
        });
      });

      widget.onUpdate();
      _log('-> Odebrano pomiar z klupy: $diameter cm. Zapisano jako $generatedNumer.');
    }
  }



  @override
  void dispose() {
    _wiekController.dispose();
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


  // --- SIMULATOR FOR TESTING ---
  void _simulateMeasurement() {
    final simulatedValues = [35.2, 28.4, 41.0, 19.7];
    simulatedValues.shuffle();
    double fakeDiameter = simulatedValues.first;

    _log('--- SYMULACJA POMIARU ---');
    final int nextIndex = widget.powierzchnia.drzewa.length + 1;
    final String generatedNumer = 'DRZ${nextIndex.toString().padLeft(3, '0')}';

    setState(() {
      widget.powierzchnia.drzewa.add({
        'numer': generatedNumer,
        'gatunek': _selectedDrzewoGatunek,
        'srednica': fakeDiameter.toStringAsFixed(1),
        'wysokosc': '',
      });
    });
    widget.onUpdate();
    _log('-> Dodano drzewo symulowane: $fakeDiameter cm');
  }

  void _showAddDrzewoDialog() {
    _srednicaController.clear();
    _wysokoscController.clear();
    setState(() {
      _selectedDrzewoGatunek = 'SO';
    });

    final int nextIndex = widget.powierzchnia.drzewa.length + 1;
    final String generatedNumer = 'DRZ${nextIndex.toString().padLeft(3, '0')}';

    void handleSave() async {
      setState(() {
        widget.powierzchnia.drzewa.add({
          'numer': generatedNumer,
          'gatunek': _selectedDrzewoGatunek,
          'srednica': _srednicaController.text.trim(),
          'wysokosc': _wysokoscController.text.trim(),
        });
      });

      widget.onUpdate();
      Navigator.pop(context);
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Nowe drzewo ($generatedNumer)'),
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
                  ],
                ),
              ),
              actions: [
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
                  onPressed: handleSave,
                  child: const Text('Dodaj'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditDrzewoDialog(int index, Map<String, dynamic> existingTree) {
    final String currentNumer = existingTree['numer'] ?? 'DRZ001';
    _srednicaController.text = existingTree['srednica'] ?? '';
    _wysokoscController.text = existingTree['wysokosc'] ?? '';

    setState(() {
      _selectedDrzewoGatunek = existingTree['gatunek'] ?? 'SO';
    });

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Edytuj drzewo ($currentNumer)'),
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
                  ],
                ),
              ),
              actions: [
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
                  onPressed: () async {
                    setState(() {
                      widget.powierzchnia.drzewa[index] = {
                        'numer': currentNumer,
                        'gatunek': _selectedDrzewoGatunek,
                        'srednica': _srednicaController.text.trim(),
                        'wysokosc': _wysokoscController.text.trim(),
                      };
                    });
                    widget.onUpdate();
                    Navigator.pop(context);
                  },
                  child: const Text('Zapisz'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // building one drzewo card
  void _showBatchAddDrzewoDialog() {
    _srednicaController.clear();
    _wysokoscController.clear();

    setState(() {
      _selectedDrzewoGatunek = 'SO';
      _isBatchDialogOpen = true; // Tell the app the dialog is now OPEN
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final int nextIndex = widget.powierzchnia.drzewa.length + 1;
            final String generatedNumer = 'DRZ${nextIndex.toString().padLeft(3, '0')}';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Szybkie dodawanie ($generatedNumer)'),
              content: _buildBatchFormContent(setDialogState),
              actions: _buildBatchDialogActions(generatedNumer, setDialogState),
            );
          },
        );
      },
    ).then((_) {
      // Tell the app the dialog is now CLOSED once popped
      setState(() {
        _isBatchDialogOpen = false;
      });
    });
  }

  // --- 1. FORM CONTENT ---
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

  // --- 2. SPECIES CHIPS ---
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

  // --- 3. REUSABLE TEXT FIELD ---
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

  // --- 4. ACTION BUTTONS ---
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

  // --- 5. SAVE LOGIC ---
  void _handleBatchAddNext(String generatedNumer, StateSetter setDialogState) {
    setState(() {
      widget.powierzchnia.drzewa.add({
        'numer': generatedNumer,
        'gatunek': _selectedDrzewoGatunek,
        'srednica': _srednicaController.text.trim(),
        'wysokosc': _wysokoscController.text.trim(),
      });
    });

    // Save locally and refresh parent screen
    widget.onUpdate();

    // Clear inputs for the next tree
    _srednicaController.clear();
    _wysokoscController.clear();

    // Force the dialog to rebuild with the new sequence number
    setDialogState(() {});
  }

  // build powierzchnie screen
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
      actions: [
        IconButton(
          icon: const Icon(Icons.science, color: Colors.amber),
          tooltip: 'Simulate caliper measurement',
          onPressed: _simulateMeasurement,
        ),
      ],
    );
  }

  Widget _buildHeaderTitle() {
    return const Text(
      'Panel gatunków i drzew',
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }


  //
  Widget _buildActionButtonsRow() {
    return Row(
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade200,
            foregroundColor: Colors.black87,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: _showBatchAddDrzewoDialog,
          icon: const Icon(Icons.playlist_add, size: 18),
          label: const Text('dodaj wiele'),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade100,
            foregroundColor: Colors.black87,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: _showAddDrzewoDialog,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('drzewo'),
        ),
      ],
    );
  }

  Widget _buildContentArea() {
    final bool isEmpty = widget.powierzchnia.grupy.isEmpty && widget.powierzchnia.drzewa.isEmpty;

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
        if (widget.powierzchnia.grupy.isNotEmpty) ...[
          _buildSectionHeader('Grupy'),
          ...widget.powierzchnia.grupy.map(_buildGrupaCard),
          const SizedBox(height: 12),
        ],
        if (widget.powierzchnia.drzewa.isNotEmpty) ...[
          _buildSectionHeader('Drzewa'),
          ...widget.powierzchnia.drzewa.asMap().entries.map((entry) {
            int index = entry.key;
            Map<String, dynamic> drzewo = entry.value;
            return _buildDrzewoCard(drzewo, index);
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

  Widget _buildGrupaCard(Map<String, dynamic> grupa) {
    return Card(
      child: ListTile(
        title: Text('Gatunek: ${grupa['gatunek']}'),
        subtitle: Text('Wiek: ${grupa['wiek']} lat'),
      ),
    );
  }

  Widget _buildDrzewoCard(Map<String, dynamic> drzewo, int index) {
    final String numer = drzewo['numer'] ?? 'DRZ';
    final String gatunek = drzewo['gatunek'] ?? 'SO';
    final String srednica = drzewo['srednica'] ?? '';
    final String wysokosc = drzewo['wysokosc'] ?? '';

    String subtitleText = 'Gatunek: $gatunek';
    if (srednica.isNotEmpty) subtitleText += ' | Średnica: $srednica cm';
    if (wysokosc.isNotEmpty) subtitleText += ' | Wysokość: $wysokosc m';

    return Card(
      child: ListTile(
        onTap: () => _showEditDrzewoDialog(index, drzewo),
        title: Text(numer, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitleText),
        trailing: IconButton(
          icon: const Icon(Icons.delete, size: 18, color: Colors.red),
          onPressed: () async {
            setState(() {
              widget.powierzchnia.drzewa.removeAt(index);
            });
            widget.onUpdate();
          },
        ),
      ),
    );
  }
}