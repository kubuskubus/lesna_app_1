import 'package:flutter/material.dart';
import 'package:lesna_app_1/screens/powierzchnia_screen/pomiar_wysokosci.dart';
import 'powierzchnia_model.dart';
import 'dart:math' as math;

/// A data class to hold the results of all control tests, divided by category.
class WynikiKontroli {
  // --- 1. DRZEWA ŻYWE ---
  final bool testZyweSrednice;
  final bool testZyweAzymut;
  final bool testZyweOdl;
  final bool testZywePromien;
  final bool testNajgrubsze;
  final Map<String, bool> testyWysokosciZywe;

  // --- 2. DRZEWA MARTWE ---
  final bool testMartweSrednice;
  final bool testMartweWysokosc;

  // --- 3. GWOŹDZIE ---
  final bool testGwozdzAzymut;
  final bool testGwozdzOdl;
  final bool testGwozdzPromien;
  final bool testGwozdzIlosc; // <--- ADDED NEW TEST

  WynikiKontroli({
    required this.testZyweSrednice,
    required this.testZyweAzymut,
    required this.testZyweOdl,
    required this.testZywePromien,
    required this.testNajgrubsze,
    required this.testyWysokosciZywe,

    required this.testMartweSrednice,
    required this.testMartweWysokosc,

    required this.testGwozdzAzymut,
    required this.testGwozdzOdl,
    required this.testGwozdzPromien,
    required this.testGwozdzIlosc, // <--- ADDED TO CONSTRUCTOR
  });
}

class KontrolaPowierzchni {
  /// Executes all logical checks separated into Live, Dead, and Gwoździe.
  static WynikiKontroli wykonajTestyKontrolne({
    required PowierzchniaModel powierzchnia,
    required String selectedWarstwa,
    required double maxRadius,
  }) {
    final List<DrzewoModel> allTrees = powierzchnia.drzewa;

    // --- 1. Filter all items for the selected layer ---
    final List<DrzewoModel> allItemsInLayer = allTrees.where((tree) {
      return selectedWarstwa == 'Wszyst.' ||
          tree.warstwa.toString() == selectedWarstwa ||
          tree.warstwa.toString().isEmpty;
    }).toList();

    // =========================================================================
    // 2. SEPARATION INTO 3 DISTINCT GROUPS
    // =========================================================================

    // A. DRZEWA ŻYWE (Live trees, excluding gwoździe)
    final List<DrzewoModel> zyweInLayer = allItemsInLayer.where((tree) {
      return tree.typ['state'] == 'zywe' && tree.typ['type'] != 'gwozdz';
    }).toList();

    // B. DRZEWA MARTWE (Dead trees)
    final List<DrzewoModel> martweInLayer = allItemsInLayer.where((tree) {
      return tree.typ['state'] == 'martwe';
    }).toList();

    // C. GWOŹDZIE (Live gwoździe)
    final List<DrzewoModel> gwozdzieInLayer = allItemsInLayer.where((tree) {
      return tree.typ['state'] == 'zywe' && tree.typ['type'] == 'gwozdz';
    }).toList();

    // Save the original state of the wysRequired flags before height checks
    Map<DrzewoModel, bool> originalFlags = {
      for (var tree in allTrees) tree: tree.wysRequired
    };
    final pomiarManager = PomiarWysokosci(powierzchnia: powierzchnia);

    // =========================================================================
    // 3. CHECKS FOR DRZEWA ŻYWE (All fields required)
    // =========================================================================
    bool testZyweSrednice = checkWszystkieMajaSrednice(zyweInLayer);
    bool testZyweAzymut = checkWszystkieMajaAzymut(zyweInLayer);
    bool testZyweOdl = checkWszystkieMajaOdl(zyweInLayer);
    bool testZywePromien = checkWszystkieWPromieniu(zyweInLayer, maxRadius, powierzchnia);

    bool testNajgrubsze = _checkNajgrubszeWysokosc(
      pomiarManager: pomiarManager,
      allTrees: allTrees,
      selectedWarstwa: selectedWarstwa,
    );

    Map<String, bool> testyWysokosciZywe = _checkGrupyWysokosci(
      pomiarManager: pomiarManager,
      allTrees: allTrees,
      treesInLayer: zyweInLayer,
      kategoriaDrzewa: 'zywe',
      selectedWarstwa: selectedWarstwa,
    );

    // =========================================================================
    // 4. CHECKS FOR DRZEWA MARTWE (All must have średnica & wysokość)
    // =========================================================================
    bool testMartweSrednice = checkWszystkieMajaSrednice(martweInLayer);
    bool testMartweWysokosc = checkWszystkieMajaWysokosc(martweInLayer);


    // =========================================================================
    // 5. CHECKS FOR GWOŹDZIE (Only azymut & odl — no średnica/wysokość)
    // =========================================================================
    bool testGwozdzAzymut = checkWszystkieMajaAzymut(gwozdzieInLayer);
    bool testGwozdzOdl = checkWszystkieMajaOdl(gwozdzieInLayer);
    bool testGwozdzPromien = checkWszystkieWPromieniu(gwozdzieInLayer, maxRadius, powierzchnia);

    // NEW TEST: Checks if there are exactly 3 gwoździe defined
    bool testGwozdzIlosc = gwozdzieInLayer.length == 3;

    // --- Restore flags to their original state ---
    for (var tree in allTrees) {
      tree.wysRequired = originalFlags[tree] ?? false;
    }

    return WynikiKontroli(
      // Drzewa żywe
      testZyweSrednice: testZyweSrednice,
      testZyweAzymut: testZyweAzymut,
      testZyweOdl: testZyweOdl,
      testZywePromien: testZywePromien,
      testNajgrubsze: testNajgrubsze,
      testyWysokosciZywe: testyWysokosciZywe,

      // Drzewa martwe
      testMartweSrednice: testMartweSrednice,
      testMartweWysokosc: testMartweWysokosc,

      // Gwoździe
      testGwozdzAzymut: testGwozdzAzymut,
      testGwozdzOdl: testGwozdzOdl,
      testGwozdzPromien: testGwozdzPromien,
      testGwozdzIlosc: testGwozdzIlosc, // Pass the new test
    );
  }


  /// Evaluates and updates the completion state for a list of surfaces.
  static void checkControlForAllSurfaces(List<PowierzchniaModel> powierzchnie) {
    for (var powierzchnia in powierzchnie) {
      updateSingleSurfaceCompletion(powierzchnia);
    }
  }

  /// Evaluates a single surface and updates its completion map.
  static void updateSingleSurfaceCompletion(PowierzchniaModel powierzchnia) {
    // 1. If there are no trees, it's not edited.
    if (powierzchnia.drzewa.isEmpty) {
      powierzchnia.completion['completion'] = 'notEdited';
      return;
    }

    // 2. Check which categories exist on this surface
    final bool hasZywe = powierzchnia.drzewa.any(
          (t) => t.typ['state'] == 'zywe' && t.typ['type'] != 'gwozdz',
    );
    final bool hasMartwe = powierzchnia.drzewa.any((t) => t.typ['state'] == 'martwe');

    // hasGwozdzie is no longer needed here since testGwozdzIlosc strictly enforces the presence of exactly 3.

    // 3. Run the validation checks
    final wyniki = wykonajTestyKontrolne(
      powierzchnia: powierzchnia,
      selectedWarstwa: 'Wszyst.',
      maxRadius: 11.28, // Using your standard radius
    );

    bool isComplete = true;

    // --- Validate Żywe ---
    if (hasZywe) {
      if (!wyniki.testZyweSrednice ||
          !wyniki.testZyweAzymut ||
          !wyniki.testZyweOdl ||
          !wyniki.testZywePromien ||
          !wyniki.testNajgrubsze) {
        isComplete = false;
      } else {
        for (bool result in wyniki.testyWysokosciZywe.values) {
          if (!result) {
            isComplete = false;
            break;
          }
        }
      }
    }

    // --- Validate Martwe ---
    if (isComplete && hasMartwe) {
      if (!wyniki.testMartweSrednice || !wyniki.testMartweWysokosc) {
        isComplete = false;
      }
    }

    // --- Validate Gwoździe ---
    // We evaluate this regardless of whether any gwozdz is currently added,
    // because testGwozdzIlosc will fail if there aren't exactly 3.
    if (isComplete) {
      if (!wyniki.testGwozdzIlosc ||
          !wyniki.testGwozdzAzymut ||
          !wyniki.testGwozdzOdl ||
          !wyniki.testGwozdzPromien) {
        isComplete = false;
      }
    }

    // 4. Update the map with the final result
    powierzchnia.completion['completion'] = isComplete ? 'Completed' : 'notCompleted';
  }

  /// Evaluates the height requirements for individual groups (species + age)
  static Map<String, bool> _checkGrupyWysokosci({
    required PomiarWysokosci pomiarManager,
    required List<DrzewoModel> allTrees,
    required List<DrzewoModel> treesInLayer,
    required String kategoriaDrzewa,
    required String selectedWarstwa,
  }) {
    Map<String, bool> testyWysokosci = {};
    Set<String> unikalneGrupy = {};

    // Since treesInLayer is already pre-filtered for the category, collect unique groups directly
    for (var tree in treesInLayer) {
      unikalneGrupy.add('${tree.gatunek}|${tree.wiek}');
    }

    for (var group in unikalneGrupy) {
      var parts = group.split('|');
      String gatunek = parts[0];
      int wiek = int.tryParse(parts[1]) ?? 0;

      List<DrzewoModel> groupTrees = pomiarManager.getTreesForHeightMeasurement(
        allTrees: allTrees,
        typDrzewa: kategoriaDrzewa,
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
            break;
          }
        }
      }

      if (maWymagane) {
        testyWysokosci['$gatunek $wiek'] = wszystkieZmierzone;
      }
    }

    return testyWysokosci;
  }

  /// Evaluates the height measurement requirement for the thickest live trees ("Najgrubsze").
  static bool _checkNajgrubszeWysokosc({
    required PomiarWysokosci pomiarManager,
    required List<DrzewoModel> allTrees,
    required String selectedWarstwa,
  }) {
    List<DrzewoModel> najgrubszeDrzewa = pomiarManager.getTreesForHeightMeasurement(
      allTrees: allTrees,
      typDrzewa: 'zywe',
      selectedWarstwa: selectedWarstwa,
      defaultGatunekWysokosc: 'Najgrubsze',
      defaultWiekWysokosc: 0,
    );

    for (var tree in najgrubszeDrzewa) {
      if (tree.wysRequired && tree.wysokosc <= 0) {
        return false;
      }
    }

    return true;
  }

  // ===========================================================================
  // LOGICAL CHECK HELPERS
  // ===========================================================================



  /// Checks if ALL trees in the provided layer list have a valid height (wysokosc) at once.
  static bool checkWszystkieMajaWysokosc(List<DrzewoModel> treesInLayer) {
    if (treesInLayer.isEmpty) return false;

    // Returns true ONLY if every tree in the list has wysokosc > 0
    return treesInLayer.every((tree) => tree.wysokosc > 0);
  }

  /// Checks if all trees in the list have a diameter > 0 and <= 200.
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
      if (drzewo.odl <= 0) {
        return false;
      }
    }
    return true;
  }

  /// Checks if all trees are within the maximum allowed radius.
  /// Checks if all trees are within the maximum allowed radius (or rotated ellipse if slope exists).
  static bool checkWszystkieWPromieniu(
      List<DrzewoModel> drzewa,
      double maxRadius,
      PowierzchniaModel powierzchnia,
      ) {
    if (drzewa.isEmpty) return false;

    for (var tree in drzewa) {
      if (tree.azymut == null) return false;

      // If there is no slope or maxRadius is not defined, use a standard circle
      if (powierzchnia.nachylenie == 100 || maxRadius <= 0) {
        if (tree.odl > maxRadius) return false;
      } else {
        // Ellipse check (matching geometry in drawPowElipse)
        const double realRadius = 11.28; // Standard perpendicular radius
        final double d = tree.odl;
        final double treeAzimuthRad = tree.azymut! * (math.pi / 180.0);
        final double slopeAzimuthRad = powierzchnia.azymutNachylenia * (math.pi / 180.0);

        final double deltaRad = treeAzimuthRad - slopeAzimuthRad;

        // Convert to local ellipse axes
        final double xPrime = d * math.sin(deltaRad);
        final double yPrime = d * math.cos(deltaRad);

        final double r1 = realRadius; // Short axis (perpendicular to slope)
        final double r2 = maxRadius;   // Long axis (along the slope)

        // Ellipse equation: (x' / r1)^2 + (y' / r2)^2 <= 1
        final double ellipseValue = (xPrime * xPrime) / (r1 * r1) + (yPrime * yPrime) / (r2 * r2);

        // Add a small epsilon tolerance for floating-point errors
        if (ellipseValue > 1.0001) {
          return false;
        }
      }
    }
    return true;
  }

  // ===========================================================================
  // UI DISPLAY METHOD
  // ===========================================================================

  /// Builds the table view for the "Kontrola" tab, grouped into 3 sections.
  /// Builds the table view for the "Kontrola" tab, grouped into 3 sections.
  static Widget buildKontrolaTable({
    required PowierzchniaModel powierzchnia,
    required String selectedWarstwa,
    required double maxRadius,
  }) {
    final bool hasZywe = powierzchnia.drzewa.any(
          (t) => t.typ['state'] == 'zywe' && t.typ['type'] != 'gwozdz',
    );
    final bool hasMartwe = powierzchnia.drzewa.any(
          (t) => t.typ['state'] == 'martwe',
    );
    final bool hasGwozdzie = powierzchnia.drzewa.any(
          (t) => t.typ['state'] == 'zywe' && t.typ['type'] == 'gwozdz',
    );

    // CHANGED: Calculate exact count instead of just a boolean
    final int gwozdzieCount = powierzchnia.drzewa.where(
          (t) => t.typ['state'] == 'zywe' && t.typ['type'] == 'gwozdz',
    ).length;


    final wyniki = wykonajTestyKontrolne(
      powierzchnia: powierzchnia,
      selectedWarstwa: selectedWarstwa,
      maxRadius: maxRadius,
    );

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
            _buildTableHeader(),
            ..._buildZyweSection(hasZywe, wyniki, powierzchnia, maxRadius), // <-- Pass powierzchnia here
            ..._buildMartweSection(hasMartwe, wyniki),
            ..._buildGwozdzieSection(gwozdzieCount, wyniki, maxRadius),
          ],
        ),
      ),
    );
  }

  static Widget _buildTableHeader() {
    return Container(
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
            child: Text('Kontrola', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 1,
            child: Text('Wynik', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  static List<Widget> _buildZyweSection(bool hasZywe, WynikiKontroli wyniki, PowierzchniaModel powierzchnia, double maxRadius) {
    final List<Widget> rows = [
      _buildSectionHeader('Drzewa żywe'),
    ];

    if (hasZywe) {
      // Dynamic description depending on whether the surface has a slope (ellipse) or a standard circle
      final bool hasSlope = powierzchnia.nachylenie != 100 && maxRadius > 0;
      final String promienLabel = hasSlope
          ? 'Drzewa żywe mieszczą się w elipsie (R = 11.28 / ${maxRadius.toStringAsFixed(2)}m)'
          : 'Drzewa żywe mieszczą się w promieniu (${maxRadius.toStringAsFixed(2)}m)';

      rows.addAll([
        _buildKontrolaRow(nazwaKontroli: 'Wszystkie drzewa żywe mają średnicę', wynik: wyniki.testZyweSrednice),
        const Divider(height: 1, color: Colors.black12),
        _buildKontrolaRow(nazwaKontroli: 'Wszystkie drzewa żywe mają azymut', wynik: wyniki.testZyweAzymut),
        const Divider(height: 1, color: Colors.black12),
        _buildKontrolaRow(nazwaKontroli: 'Wszystkie drzewa żywe mają odległość', wynik: wyniki.testZyweOdl),
        const Divider(height: 1, color: Colors.black12),
        _buildKontrolaRow(nazwaKontroli: promienLabel, wynik: wyniki.testZywePromien), // <-- Updated description in Polish
        const Divider(height: 1, color: Colors.black12),
        _buildKontrolaRow(nazwaKontroli: '4 najgrubsze drzewa mają wysokość', wynik: wyniki.testNajgrubsze),
      ]);

      if (wyniki.testyWysokosciZywe.isNotEmpty) {
        rows.add(const Divider(height: 1, color: Colors.black12));
        for (var entry in wyniki.testyWysokosciZywe.entries) {
          rows.addAll([
            _buildKontrolaRow(nazwaKontroli: 'Wymagane wysokości: ${entry.key}', wynik: entry.value),
            const Divider(height: 1, color: Colors.black12),
          ]);
        }
      }
    } else {
      rows.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Text('Brak zdefiniowanych drzew żywych', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
        ),
      );
    }
    return rows;
  }

  static List<Widget> _buildMartweSection(bool hasMartwe, WynikiKontroli wyniki) {
    final List<Widget> rows = [
      _buildSectionHeader('Drzewa martwe (w tym posusz, wywrot, złom, ścięte, fragment)'),
    ];

    if (hasMartwe) {
      rows.addAll([
        _buildKontrolaRow(nazwaKontroli: 'Wszystkie drzewa martwe mają średnicę', wynik: wyniki.testMartweSrednice),
        const Divider(height: 1, color: Colors.black12),
        _buildKontrolaRow(nazwaKontroli: 'Wszystkie drzewa martwe mają wysokość', wynik: wyniki.testMartweWysokosc),
      ]);
    } else {
      rows.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Text('Brak zdefiniowanych drzew martwych', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
        ),
      );
    }
    return rows;
  }

  static List<Widget> _buildGwozdzieSection(int gwozdzieCount, WynikiKontroli wyniki, double maxRadius) {
    final bool hasGwozdzie = gwozdzieCount > 0;
    final List<Widget> rows = [
      _buildSectionHeader('Gwoździe'),
    ];

    if (hasGwozdzie) {
      // 1. Dynamic quantity check message (only shown if there is at least 1 nail)
      if (gwozdzieCount == 3) {
        rows.addAll([
          _buildKontrolaRow(nazwaKontroli: 'Na powierzchni zdefiniowano dokładnie 3 gwoździe', wynik: true),
          const Divider(height: 1, color: Colors.black12),
        ]);
      } else {
        rows.addAll([
          _buildKontrolaRow(nazwaKontroli: 'Wymagane są 3 gwoździe (zdefiniowano: $gwozdzieCount)', wynik: false),
          const Divider(height: 1, color: Colors.black12),
        ]);
      }

      // 2. Show azymut/odl checks since there is at least one nail to check
      rows.addAll([
        _buildKontrolaRow(nazwaKontroli: 'Wszystkie gwoździe mają azymut', wynik: wyniki.testGwozdzAzymut),
        const Divider(height: 1, color: Colors.black12),
        _buildKontrolaRow(nazwaKontroli: 'Wszystkie gwoździe mają odległość', wynik: wyniki.testGwozdzOdl),
        const Divider(height: 1, color: Colors.black12),
        _buildKontrolaRow(nazwaKontroli: 'Gwoździe mieszczą się w promieniu (${maxRadius.toStringAsFixed(2)}m)', wynik: wyniki.testGwozdzPromien),
      ]);

    } else {
      // 3. If there are exactly 0 nails, just show one general error message
      rows.add(
        _buildKontrolaRow(nazwaKontroli: 'Brak zdefiniowanych gwoździ (wymagane 3 na powierzchni)', wynik: false),
      );
    }

    return rows;
  }

  // --- HELPER METHODS ---

  static Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        border: const Border(
          top: BorderSide(color: Colors.black12),
          bottom: BorderSide(color: Colors.black12),
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
                border: Border.all(color: wynik ? Colors.green.shade200 : Colors.red.shade200),
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



