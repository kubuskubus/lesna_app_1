import 'package:flutter/material.dart';
import 'package:lesna_app_1/screens/powierzchnia_screen/powierzchnia_model.dart';
// Upewnij się, że ścieżka do modelu jest poprawna

class PowierzchniaInfoDialog extends StatelessWidget {
  final PowierzchniaModel powierzchnia;

  const PowierzchniaInfoDialog({
    Key? key,
    required this.powierzchnia,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
  // 1. Group the data by species and age.
  // Replace your current grouping logic with something similar to this:
    Map<String, int> treesBySpeciesAndAge = {};
    for (var tree in powierzchnia.drzewa) {
      // Assuming your tree model has 'gatunek' and 'wiek' properties
      String key = '${tree.gatunek}${tree.wiek}'; // Creates a key like "SO25" or "SO45"
      treesBySpeciesAndAge[key] = (treesBySpeciesAndAge[key] ?? 0) + 1;
    }

  // 2. Calculate the overall total number of trees
    int totalTrees = treesBySpeciesAndAge.values.fold(0, (sum, count) => sum + count);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Informacje o powierzchni'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Numer powierzchni:', powierzchnia.numer.toString()),

            // Zaktualizowany wiersz: Numer wydzielenia wyliczany na podstawie adresu
            _buildInfoRow(
              'Numer wydzielenia:',
              (powierzchnia.adres != null && powierzchnia.adres!.length > 12)
                  ? powierzchnia.adres!.substring(10, powierzchnia.adres!.length - 3).trim()
                  : (powierzchnia.adres ?? 'Brak'),
            ),

            _buildInfoRow('Adres leśny:', powierzchnia.adres ?? 'Brak'),

            const Divider(height: 30, thickness: 1),

            Text(
              'Statystyki gatunków (Razem: $totalTrees)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),

            if (treesBySpeciesAndAge.isEmpty)
              const Text('Brak zdefiniowanych drzew na tej powierzchni.')
            else ...[
              // Map through the grouped species + age entries
              ...treesBySpeciesAndAge.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // entry.key will display as "SO25", "SO45", etc.
                      Text('- ${entry.key}:', style: const TextStyle(fontSize: 15)),
                      Text(
                        '${entry.value} szt.',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                );
              }),

              const Divider(height: 24, thickness: 1),

              // Total sum row at the bottom
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                        'Suma drzew:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                    Text(
                      '$totalTrees szt.',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Zamknij', style: TextStyle(color: Colors.black87)),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 15),
          children: [
            TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}