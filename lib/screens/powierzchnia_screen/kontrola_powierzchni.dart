import 'package:flutter/material.dart';
import 'powierzchnia_model.dart'; // Make sure the path to DrzewoModel is correct

class KontrolaPowierzchni {

  // --- 1. LOGICAL CHECKS ---

  /// Checks if all trees in the list have a diameter > 0.
  static bool checkWszystkieMajaSrednice(List<DrzewoModel> drzewa) {
    if (drzewa.isEmpty) return false;
    for (var drzewo in drzewa) {
      if (drzewo.srednica <= 0 || drzewo.srednica > 200) {
        return false;
      }
    }
    return true;
  }

  /// Groups trees and checks if for each group (Gatunek + Wiek),
  /// the required trees (based on the pomiar_wysokosci algorithm) have their height measured.
  static Map<String, bool> checkWysokosciDlaGrup(List<DrzewoModel> drzewa) {
    Map<String, List<DrzewoModel>> groupedTrees = {};
    Map<String, bool> wynikiGrup = {};

    // 1. Group the trees
    for (var drzewo in drzewa) {
      final String key = '${drzewo.gatunek} ${drzewo.wiek}';
      if (!groupedTrees.containsKey(key)) {
        groupedTrees[key] = [];
      }
      groupedTrees[key]!.add(drzewo);
    }

    // 2. Analyze each group
    groupedTrees.forEach((grupaKey, treesInGroup) {
      List<DrzewoModel> sortedByOdl = List.from(treesInGroup);
      sortedByOdl.sort((a, b) => a.odl.compareTo(b.odl));

      int end = sortedByOdl.length < 6 ? sortedByOdl.length : 6;
      List<DrzewoModel> closestSubgroup = sortedByOdl.sublist(0, end);

      closestSubgroup.sort((a, b) => a.srednica.compareTo(b.srednica));

      bool wszystkieWymaganeZmierzone = true;
      int n = closestSubgroup.length;

      if (n <= 2) {
        for (var tree in closestSubgroup) {
          if (tree.wysokosc <= 0) wszystkieWymaganeZmierzone = false;
        }
      } else {
        int midRight = n ~/ 2;
        int midLeft = midRight - 1;

        if (closestSubgroup[midLeft].wysokosc <= 0) wszystkieWymaganeZmierzone = false;
        if (closestSubgroup[midRight].wysokosc <= 0) wszystkieWymaganeZmierzone = false;
      }

      wynikiGrup[grupaKey] = wszystkieWymaganeZmierzone;
    });

    return wynikiGrup;
  }

  // --- 2. UI DISPLAY METHOD ---

  /// Builds the table view for the "Kontrola" tab.
  static Widget buildKontrolaTable(List<DrzewoModel> drzewa) {

    // --- NEW: Split the trees into living and dead ---
    final List<DrzewoModel> zywe = drzewa.where((d) => d.typ == 'zywe').toList();
    final List<DrzewoModel> martwe = drzewa.where((d) => d.typ == 'martwe').toList();

    // Run the logical checks
    bool testSrednice = checkWszystkieMajaSrednice(drzewa); // We check diameter for ALL trees

    // Check heights separately for living and dead groups
    Map<String, bool> testyWysokosciZywe = checkWysokosciDlaGrup(zywe);
    Map<String, bool> testyWysokosciMartwe = checkWysokosciDlaGrup(martwe);

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- MAIN TABLE HEADER ---
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

            // --- CHECK 1: Średnica (General check) ---
            _buildKontrolaRow(
              nazwaKontroli: 'Wszystkie drzewa mają średnicę',
              wynik: testSrednice,
            ),

            // --- SECTION: DRZEWA ŻYWE ---
            if (testyWysokosciZywe.isNotEmpty) ...[
              _buildSectionHeader('Drzewa żywe'),
              ...testyWysokosciZywe.entries.map((entry) {
                return Column(
                  children: [
                    _buildKontrolaRow(
                      nazwaKontroli: 'Wymagane wysokości: ${entry.key}',
                      wynik: entry.value,
                    ),
                    const Divider(height: 1, color: Colors.black12),
                  ],
                );
              }).toList(),
            ],

            // --- SECTION: DRZEWA MARTWE ---
            if (testyWysokosciMartwe.isNotEmpty) ...[
              _buildSectionHeader('Drzewa martwe'),
              ...testyWysokosciMartwe.entries.map((entry) {
                return Column(
                  children: [
                    _buildKontrolaRow(
                      nazwaKontroli: 'Wymagane wysokości: ${entry.key}',
                      wynik: entry.value,
                    ),
                    const Divider(height: 1, color: Colors.black12),
                  ],
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  // --- HELPER METHODS ---

  // --- NEW: Sub-header for grouping sections ---
  static Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200, // Slightly darker than white, lighter than header
        border: const Border(
            top: BorderSide(color: Colors.black12),
            bottom: BorderSide(color: Colors.black12)
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade800,
          fontSize: 13,
        ),
      ),
    );
  }

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