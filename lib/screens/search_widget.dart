import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class NumPpSearchWidget extends StatefulWidget {
  const NumPpSearchWidget({Key? key}) : super(key: key);

  @override
  State<NumPpSearchWidget> createState() => _NumPpSearchWidgetState();
}

class _NumPpSearchWidgetState extends State<NumPpSearchWidget> {
  List<String> _allNumPp = [];
  List<String> _filteredNumPp = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadJsonData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 1. Read and extract num_pp from the internal JSON file
  Future<void> _loadJsonData() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/trees_data.json');

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final dynamic jsonData = jsonDecode(jsonString);

        Set<String> extractedNums = {};

        // Adjust this depending on your JSON structure.
        // Assumes a List of objects: [{"num_pp": "1", ...}, {"num_pp": "10", ...}]
        if (jsonData is List) {
          for (var item in jsonData) {
            if (item is Map && item.containsKey('num_pp')) {
              extractedNums.add(item['num_pp'].toString());
            }
          }
        }

        setState(() {
          _allNumPp = extractedNums.toList()..sort();
        });
      }
    } catch (e) {
      debugPrint('Error loading JSON: $e');
    }
  }

  // 2. Filter logic triggered on typing
  void _filterList(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredNumPp = [];
      } else {
        _filteredNumPp = _allNumPp
            .where((num) => num.startsWith(query)) // Matches 1 -> 1, 10, 110, etc.
            .toList();
      }
    });
  }

  // 3. Open Dialog upon selection
  void _showAddDialog(String selectedNumPp) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nowa powierzchnia próbna'),
          content: Text('Czy chcesz dodać nową powierzchnię dla num_pp: $selectedNumPp?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: Add your logic to create the new 'powierzchnia pp'
                Navigator.pop(context);

                // Optional: Clear search after adding
                _searchController.clear();
                _filterList('');
              },
              child: const Text('Dodaj'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Input Field
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: _filterList,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Szukaj num_pp...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _filterList('');
                },
              )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        // Dynamic Results List
        Expanded(
          child: _filteredNumPp.isEmpty && _searchController.text.isNotEmpty
              ? const Center(child: Text('Brak wyników'))
              : ListView.builder(
            itemCount: _filteredNumPp.length,
            itemBuilder: (context, index) {
              final numPp = _filteredNumPp[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(
                    'num_pp: $numPp',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.add_circle_outline, color: Colors.deepPurple),
                  onTap: () => _showAddDialog(numPp),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}