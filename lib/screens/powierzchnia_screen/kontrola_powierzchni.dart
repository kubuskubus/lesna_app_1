import 'package:flutter/material.dart';
import 'package:lesna_app_1/screens/powierzchnia_screen/pomiar_wysokosci.dart';
import 'powierzchnia_model.dart'; // Make sure the path to DrzewoModel is correct



/// A data class to hold the results of all control tests.
class WynikiKontroli {
  final bool testSrednice;
  final bool testAzymut;
  final bool testOdl;
  final bool testNajgrubsze;
  final Map<String, bool> testyWysokosciZywe;
  final Map<String, bool> testyWysokosciMartwe;

  WynikiKontroli({
    required this.testSrednice,
    required this.testAzymut,
    required this.testOdl,
    required this.testNajgrubsze,
    required this.testyWysokosciZywe,
    required this.testyWysokosciMartwe,
  });
}



class KontrolaPowierzchni {


  /// Executes all logical checks and returns the results.
  static WynikiKontroli wykonajTestyKontrolne({
    required PowierzchniaModel powierzchnia,
    required String selectedWarstwa,
  }) {
    final List<DrzewoModel> allTrees = powierzchnia.drzewa;

    // --- 1. Filter trees only for the selected layer (for general tests) ---
    final List<DrzewoModel> treesInLayer = allTrees.where((tree) {
      return selectedWarstwa == 'Wszyst.' ||
          tree.warstwa.toString() == selectedWarstwa ||
          tree.warstwa.toString().isEmpty;
    }).toList();

    // General tests (Diameter, Azimuth, Distance) are performed on the selected layer
    bool testSrednice = checkWszystkieMajaSrednice(treesInLayer);
    bool testAzymut = checkWszystkieMajaAzymut(treesInLayer);
    bool testOdl = checkWszystkieMajaOdl(treesInLayer);

    // --- 2. Save the original state of the wysRequired flags ---
    Map<DrzewoModel, bool> originalFlags = {
      for (var tree in allTrees) tree: tree.wysRequired
    };

    final pomiarManager = PomiarWysokosci(powierzchnia: powierzchnia);

    // --- 3. Test: "Najgrubsze" (Thickest Trees) ---
    bool testNajgrubsze = _checkNajgrubsze(
      pomiarManager: pomiarManager,
      allTrees: allTrees,
      selectedWarstwa: selectedWarstwa,
    );

    // --- 4. Group Tests: 70% Proportion for Live and Dead Trees ---

    // Evaluate Live Trees
    Map<String, bool> testyWysokosciZywe = _checkGrupyWysokosci(
      pomiarManager: pomiarManager,
      allTrees: allTrees,
      treesInLayer: treesInLayer,
      typDrzewa: 'zywe',
      selectedWarstwa: selectedWarstwa,
    );

    // Evaluate Dead Trees
    Map<String, bool> testyWysokosciMartwe = _checkGrupyWysokosci(
      pomiarManager: pomiarManager,
      allTrees: allTrees,
      treesInLayer: treesInLayer,
      typDrzewa: 'martwe',
      selectedWarstwa: selectedWarstwa,
    );

    // --- 5. Restore flags to their original state ---
    for (var tree in allTrees) {
      tree.wysRequired = originalFlags[tree] ?? false;
    }

    return WynikiKontroli(
      testSrednice: testSrednice,
      testAzymut: testAzymut,
      testOdl: testOdl,
      testNajgrubsze: testNajgrubsze,
      testyWysokosciZywe: testyWysokosciZywe,
      testyWysokosciMartwe: testyWysokosciMartwe,
    );
  }

  /// Evaluates the height requirements for individual groups (species + age)
  static Map<String, bool> _checkGrupyWysokosci({
    required PomiarWysokosci pomiarManager,
    required List<DrzewoModel> allTrees,
    required List<DrzewoModel> treesInLayer,
    required String typDrzewa,
    required String selectedWarstwa,
  }) {
    Map<String, bool> testyWysokosci = {};
    Set<String> unikalneGrupy = {};

    // 1. Collect unique groups (species + age) from the selected layer for the given type
    for (var tree in treesInLayer) {
      if (tree.typ == typDrzewa) {
        unikalneGrupy.add('${tree.gatunek}|${tree.wiek}');
      }
    }

    // 2. Evaluate each group
    for (var group in unikalneGrupy) {
      var parts = group.split('|');
      String gatunek = parts[0];
      int wiek = int.parse(parts[1]);

      List<DrzewoModel> groupTrees = pomiarManager.getTreesForHeightMeasurement(
        allTrees: allTrees,
        typDrzewa: typDrzewa,
        selectedWarstwa: selectedWarstwa,
        defaultGatunekWysokosc: gatunek,
        defaultWiekWysokosc: wiek,
      );

      bool maWymagane = false;
      bool wszystkieZmierzone = true;

      for (var tree in groupTrees) {
        if (tree.wysRequired) {
          maWymagane = true;
          if (tree.wysokosc <= 0) {
            wszystkieZmierzone = false;
            break; // Break the loop early for optimization once a missing measurement is found
          }
        }
      }

      if (maWymagane) {
        testyWysokosci['$gatunek $wiek'] = wszystkieZmierzone;
      }
    }

    return testyWysokosci;
  }

  /// Evaluates the height measurement requirement for the thickest trees ("Najgrubsze").
  static bool _checkNajgrubsze({
    required PomiarWysokosci pomiarManager,
    required List<DrzewoModel> allTrees,
    required String selectedWarstwa,
  }) {
    List<DrzewoModel> najgrubszeDrzewa = pomiarManager.getTreesForHeightMeasurement(
      allTrees: allTrees,
      typDrzewa: 'zywe', // The 'thickest' rule usually applies to live trees
      selectedWarstwa: selectedWarstwa,
      defaultGatunekWysokosc: 'Najgrubsze',
      defaultWiekWysokosc: 0,
    );

    for (var tree in najgrubszeDrzewa) {
      if (tree.wysRequired && tree.wysokosc <= 0) {
        return false; // Returns false immediately if any required tree lacks a height measurement
      }
    }

    return true; // Returns true if all required trees have their height measured or if none were required
  }




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

  /// Checks if all trees in the list have a valid azimuth (0 - 360 degrees).
  static bool checkWszystkieMajaAzymut(List<DrzewoModel> drzewa) {
    if (drzewa.isEmpty) return false;
    for (var drzewo in drzewa) {
      // If it's null (was left empty/spaces) or out of range, it fails
      if (drzewo.azymut == null || drzewo.azymut! < 0 || drzewo.azymut! > 360) {
        return false;
      }
    }
    return true;
  }

  /// Checks if all trees in the list have a valid distance (> 0).
  static bool checkWszystkieMajaOdl(List<DrzewoModel> drzewa) {
    if (drzewa.isEmpty) return false;
    for (var drzewo in drzewa) {
      // Add an upper limit like "|| drzewo.odl > 50" if needed
      if (drzewo.odl <= 0) {
        return false;
      }
    }
    return true;
  }



  // --- 2. UI DISPLAY METHOD ---

  /// Builds the table view for the "Kontrola" tab.
  static Widget buildKontrolaTable({
    required PowierzchniaModel powierzchnia,
    required String selectedWarstwa,
  }) {
    // Execute the separated logic
    final wyniki = wykonajTestyKontrolne(
      powierzchnia: powierzchnia,
      selectedWarstwa: selectedWarstwa,
    );

    // --- 6. Build UI ---
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 16.0),
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

            // --- CHECK 1: Średnica ---
            _buildKontrolaRow(
              nazwaKontroli: 'Wszystkie drzewa mają średnicę',
              wynik: wyniki.testSrednice,
            ),
            const Divider(height: 1, color: Colors.black12),

            // --- CHECK 1A: Azymut ---
            _buildKontrolaRow(
              nazwaKontroli: 'Wszystkie drzewa mają azymut',
              wynik: wyniki.testAzymut,
            ),
            const Divider(height: 1, color: Colors.black12),

            // --- CHECK 1B: Odległość ---
            _buildKontrolaRow(
              nazwaKontroli: 'Wszystkie drzewa mają odległość',
              wynik: wyniki.testOdl,
            ),
            const Divider(height: 1, color: Colors.black12),

            // --- CHECK 2: Najgrubsze ---
            _buildKontrolaRow(
              nazwaKontroli: '4 najgrubsze drzewa mają wysokość',
              wynik: wyniki.testNajgrubsze,
            ),

            // --- SECTION: DRZEWA ŻYWE ---
            if (wyniki.testyWysokosciZywe.isNotEmpty) ...[
              _buildSectionHeader('Drzewa żywe'),
              ...wyniki.testyWysokosciZywe.entries.map((entry) {
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
            if (wyniki.testyWysokosciMartwe.isNotEmpty) ...[
              _buildSectionHeader('Drzewa martwe'),
              ...wyniki.testyWysokosciMartwe.entries.map((entry) {
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