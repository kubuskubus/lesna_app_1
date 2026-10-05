import 'package:flutter/material.dart';
// TODO: Import your tree model here, e.g.:
// import 'package:lesna_app_1/screens/drzewo_model.dart';

class KontrolaPowierzchni {

  // --- 1. LOGICAL CHECKS ---
  /// Checks if all trees in the provided list have a diameter (średnica) assigned.
  /// Returns false if the list is empty or if any tree is missing a diameter.
  static bool checkWszystkieMajaSrednice(List<dynamic> drzewa) {
    if (drzewa.isEmpty) return false;
    for (var drzewo in drzewa) {
      // Safely convert the value to a string first
      String stringValue = drzewo.srednica?.toString().trim() ?? '';

      // Try to parse the string into a decimal number
      double? numericValue = double.tryParse(stringValue);
      // The test FAILS (returns false) if:
      // 1. It is not a valid number (numericValue is null)
      // 2. The number is less than 1
      // 3. The number is greater than 200
      if (numericValue == null || numericValue < 1 || numericValue > 200) {
        return false;
      }
    }
    // If the loop finishes and all trees are valid, the test PASSES
    return true;
  }

  // --- 2. UI DISPLAY METHOD ---

  /// Builds the table view for the "Kontrola" tab.
  static Widget buildKontrolaTable(List<dynamic> drzewa) { // Change 'dynamic' to your actual tree class

    // Run the checks
    bool testSrednice = checkWszystkieMajaSrednice(drzewa);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- TABLE HEADER ---
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: const Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: Text('Kontrola', style: TextStyle(fontWeight: FontWeight.bold))
                  ),
                  Expanded(
                      flex: 1,
                      child: Text('Wynik', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)
                  ),
                ],
              ),
            ),

            // --- CHECK 1: Średnica ---
            _buildKontrolaRow(
              nazwaKontroli: 'Wszystkie drzewa mają średnicę',
              wynik: testSrednice,
            ),

            // You can add more rows here in the future:
            // const Divider(height: 1, color: Colors.grey),
            // _buildKontrolaRow(nazwaKontroli: 'Kolejny test...', wynik: innyTest),
          ],
        ),
      ),
    );
  }

  // Helper method to build individual rows
  static Widget _buildKontrolaRow({required String nazwaKontroli, required bool wynik}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(nazwaKontroli, style: const TextStyle(fontSize: 15)),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                  color: wynik ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: wynik ? Colors.green.shade200 : Colors.red.shade200)
              ),
              child: Text(
                wynik ? 'TAK' : 'NIE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: wynik ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}