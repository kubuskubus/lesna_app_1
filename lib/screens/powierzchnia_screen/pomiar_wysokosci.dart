import 'powierzchnia_model.dart'; // Make sure the path matches your project structure

class PomiarWysokosci {
  final PowierzchniaModel powierzchnia;

  // Map that holds our grouped lists
  Map<String, List<DrzewoModel>> groupedTrees = {};

  PomiarWysokosci({required this.powierzchnia}) {
    _groupTrees();
  }

  /// HELPER: Determines if a tree's specific type belongs to the general category ('zywe' or 'martwe')
  bool _isMatchingCategory(String treeTyp, String category) {
    if (category == 'zywe') {
      return treeTyp == 'zywe';
    } else if (category == 'martwe') {
      return ['martwe', 'posusz', 'zlomy', 'wywroty', 'fragmenty'].contains(treeTyp);
    }
    return treeTyp == category; // Fallback
  }

  /// Groups the trees from the surface based on species, age, and general category (zywe/martwe)
  void _groupTrees() {
    groupedTrees.clear();

    for (var drzewo in powierzchnia.drzewa) {
      // Read the general category ('zywe' or 'martwe') directly from the new Map
      String category = drzewo.typ['state'] ?? 'zywe';

      final String key = '${drzewo.gatunek}_${drzewo.wiek}_$category';

      if (!groupedTrees.containsKey(key)) {
        groupedTrees[key] = [];
      }

      groupedTrees[key]!.add(drzewo);
    }
  }

  /// Helper method to retrieve a specific list of trees
  List<DrzewoModel> getTreesFor({
    required String gatunek,
    required int wiek,
    required String typ, // 'zywe' or 'martwe' category
  }) {
    final String key = '${gatunek}_${wiek}_${typ}';
    return groupedTrees[key] ?? [];
  }

  /// Main entry point: Routes to the appropriate function based on the active mode
  List<DrzewoModel> getPreparedTreesForBuilder({
    required List<DrzewoModel> allTrees,
    required String typDrzewa,
    required String selectedWarstwa,
    required bool isWysokoscPomiarActive,
    required String defaultGatunekWysokosc,
    required int defaultWiekWysokosc,
  }) {


    List<DrzewoModel> allTreesHeight = allTrees.where((tree) {
      bool isMartwe = tree.typ['state'] == 'martwe';
      bool isZyweStandard = tree.typ['state'] == 'zywe' && tree.typ['type'] == '';

      return isMartwe || isZyweStandard;
    }).toList();

    if (isWysokoscPomiarActive) {
      return getTreesForHeightMeasurement(
        allTrees: allTreesHeight,
        typDrzewa: typDrzewa,
        selectedWarstwa: selectedWarstwa,
        defaultGatunekWysokosc: defaultGatunekWysokosc,
        defaultWiekWysokosc: defaultWiekWysokosc,
      );
    } else {
      return _getStandardTrees(
        allTrees: allTrees,
        typDrzewa: typDrzewa,
        selectedWarstwa: selectedWarstwa,
      );
    }
  }

  /// FUNCTION 1: Executed when isWysokoscPomiarActive == FALSE
  /// Only filters by layer and type, and ensures all height flags are turned off.
  List<DrzewoModel> _getStandardTrees({
    required List<DrzewoModel> allTrees,
    required String typDrzewa,
    required String selectedWarstwa,
  }) {
    List<DrzewoModel> targetTrees = allTrees.where((tree) {
      bool matchesWarstwa = (selectedWarstwa == 'Wszyst.') ||
          (tree.warstwa.toString() == selectedWarstwa || tree.warstwa.toString().isEmpty);

      // --- UPDATED: Handle 3 distinct cases for tree types ---
      bool matchesTyp;
      if (typDrzewa == 'gwozdz') {
        matchesTyp = tree.typ['state'] == 'zywe' && tree.typ['type'] == 'gwozdz';
      } else if (typDrzewa == 'zywe') {
        matchesTyp = tree.typ['state'] == 'zywe' && tree.typ['type'] == '';
      } else {
        matchesTyp = tree.typ['state'] == typDrzewa;
      }

      return matchesWarstwa && matchesTyp;
    }).toList();

    // Reset the height required flag so old flags disappear when mode is turned off
    for (var tree in targetTrees) {
      tree.wysRequired = false;
    }

    return targetTrees;
  }

  /// FUNCTION 2: Executed when isWysokoscPomiarActive == TRUE
  /// Routes all trees to the specific handler based on the selected mode.
  List<DrzewoModel> getTreesForHeightMeasurement({
    required List<DrzewoModel> allTrees,
    required String typDrzewa,
    required String selectedWarstwa,
    required String defaultGatunekWysokosc,
    required int defaultWiekWysokosc,
  }) {
    // --- NEW: Handle dead trees separately ---
    // if (typDrzewa == 'martwe' && defaultGatunekWysokosc != 'Najgrubsze') {
    if (typDrzewa == 'martwe') {
      return _assignDeadTrees(
        allTrees: allTrees,
        selectedWarstwa: selectedWarstwa,
        gatunek: defaultGatunekWysokosc,
        wiek: defaultWiekWysokosc,
      );
    }

    // --- EXISTING LOGIC for live trees ---
    if (defaultGatunekWysokosc == 'Najgrubsze') {
      return _assignThickestTrees(
        allTrees: allTrees,
        selectedWarstwa: selectedWarstwa,
      );
    } else {
      return _assignProportionalTrees(
        allTrees: allTrees,
        typDrzewa: typDrzewa, // 'zywe'
        selectedWarstwa: selectedWarstwa,
        gatunek: defaultGatunekWysokosc,
        wiek: defaultWiekWysokosc,
      );
    }
  }

// --- NEW HELPER FUNCTION ---
  List<DrzewoModel> _assignDeadTrees({
    required List<DrzewoModel> allTrees,
    required String selectedWarstwa,
    required String gatunek,
    required int wiek,
  }) {
    List<DrzewoModel> targetTrees = allTrees.where((tree) {
      bool matchesWarstwa = (selectedWarstwa == 'Wszyst.') ||
          (tree.warstwa.toString() == selectedWarstwa || tree.warstwa.toString().isEmpty);

      // Strictly match only dead trees
      bool isDead = tree.typ['state'] == 'martwe';

      // Match the requested species and age
      bool matchesGatunek = (tree.gatunek == gatunek && tree.wiek == wiek);

      return matchesWarstwa && isDead && matchesGatunek;
    }).toList();

    // --- NEW: Set height as required for all filtered dead trees ---
    for (var tree in targetTrees) {
      tree.wysRequired = true;
    }

    return targetTrees;
  }

  /// CASE 1: Filters by layer and strictly selects ONLY live trees for "Najgrubsze"
  List<DrzewoModel> _assignThickestTrees({
    required List<DrzewoModel> allTrees,
    required String selectedWarstwa,
  }) {
    // 1. Filter by layer and strictly enforce that the tree type is 'zywe' (live)
    List<DrzewoModel> targetTrees = allTrees.where((tree) {
      bool matchesWarstwa = (selectedWarstwa == 'Wszyst.') ||
          (tree.warstwa.toString() == selectedWarstwa || tree.warstwa.toString().isEmpty);

      // --- UPDATED: Strictly force 'zywe' using the new Map structure ---
      // --- UPDATED: Strictly force 'zywe' (excluding gwozdz) using the new Map structure ---
      bool matchesTyp = tree.typ['state'] == 'zywe' && tree.typ['type'] == '';

      return matchesWarstwa && matchesTyp;
    }).toList();

    // 2. Reset flags for a clean slate
    for (var tree in targetTrees) {
      tree.wysRequired = false;
    }

    if (targetTrees.isEmpty) return targetTrees;

    // 3. Assign height measurement flags
    List<DrzewoModel> sortedByDiameterDesc = List.from(targetTrees);
    sortedByDiameterDesc.sort((a, b) => b.srednica.compareTo(a.srednica));

    int count = sortedByDiameterDesc.length < 4 ? sortedByDiameterDesc.length : 4;
    for (int i = 0; i < count; i++) {
      sortedByDiameterDesc[i].wysRequired = true;
    }

    return targetTrees;
  }

  /// CASE 2: Filters by layer/type AND species/age, then applies the 70% rule
  List<DrzewoModel> _assignProportionalTrees({
    required List<DrzewoModel> allTrees,
    required String typDrzewa,
    required String selectedWarstwa,
    required String gatunek,
    required int wiek,
  }) {

    // 1. Filter trees to get all trees of specific type, gatunek, and wiek (excluding 'gwozdz')
    List<DrzewoModel> targetTrees = allTrees.where((tree) {
      bool matchesWarstwa = (selectedWarstwa == 'Wszyst.') ||
          (tree.warstwa.toString() == selectedWarstwa || tree.warstwa.toString().isEmpty);

      // Explicitly check 'zywe' (excluding gwozdz) and 'martwe'
      bool matchesTyp;
      if (typDrzewa == 'zywe') {
        matchesTyp = tree.typ['state'] == 'zywe' && tree.typ['type'] == '';
      } else if (typDrzewa == 'martwe') {
        matchesTyp = tree.typ['state'] == 'martwe';
      } else {
        matchesTyp = false;
      }

      bool matchesGatunek = (tree.gatunek == gatunek && tree.wiek == wiek);

      return matchesWarstwa && matchesTyp && matchesGatunek;
    }).toList();

    // 2. Reset flags for a clean slate
    for (var tree in targetTrees) {
      tree.wysRequired = false;
    }

    if (targetTrees.isEmpty) return targetTrees;

    // 3. Count trees filtered specifically to this selectedWarstwa and typDrzewa (ignoring species/age)
    int baseTreesCount = allTrees.where((tree) {
      bool matchesWarstwa = (selectedWarstwa == 'Wszyst.') ||
          (tree.warstwa.toString() == selectedWarstwa || tree.warstwa.toString().isEmpty);

      // --- UPDATED: Explicitly check 'zywe' (excluding gwozdz) and 'martwe' ---
      bool matchesTyp;
      if (typDrzewa == 'zywe') {
        matchesTyp = tree.typ['state'] == 'zywe' && tree.typ['type'] == '';
      } else if (typDrzewa == 'martwe') {
        matchesTyp = tree.typ['state'] == 'martwe';
      } else {
        matchesTyp = false;
      }

      return matchesWarstwa && matchesTyp;
    }).length;

    // 4. Calculate the 70% threshold based on this specific layer/type pool
    bool isMoreThan70Percent = baseTreesCount > 0 && (targetTrees.length / baseTreesCount) > 0.7;

    // 5. Assign height measurement flags based on proportion
    List<DrzewoModel> sortedByDistance = List.from(targetTrees);
    sortedByDistance.sort((a, b) => a.odl.compareTo(b.odl));

    if (isMoreThan70Percent) {
      // --- CONDITION A: > 70% -> 6 closest, 2 middle trees ---
      int end = sortedByDistance.length < 6 ? sortedByDistance.length : 6;
      List<DrzewoModel> closestSubgroup = sortedByDistance.sublist(0, end);
      closestSubgroup.sort((a, b) => a.srednica.compareTo(b.srednica));

      int n = closestSubgroup.length;
      if (n <= 2) {
        for (var tree in closestSubgroup) {
          tree.wysRequired = true;
        }
      } else {
        int midRight = n ~/ 2;
        int midLeft = midRight - 1; // Fixed the syntax error here

        closestSubgroup[midLeft].wysRequired = true;
        closestSubgroup[midRight].wysRequired = true;
      }
    } else {
      // --- CONDITION B: <= 70% -> 5 closest, 1 middle tree ---
      int end = sortedByDistance.length < 5 ? sortedByDistance.length : 5;
      List<DrzewoModel> closestSubgroup = sortedByDistance.sublist(0, end);
      closestSubgroup.sort((a, b) => a.srednica.compareTo(b.srednica));

      int n = closestSubgroup.length;
      if (n > 0) {
        int mid = n ~/ 2;
        closestSubgroup[mid].wysRequired = true;
      }
    }

    return targetTrees;
  }

  /// Refresh data
  void refreshData() {
    _groupTrees();
  }
}