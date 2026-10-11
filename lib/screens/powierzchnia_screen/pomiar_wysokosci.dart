import 'powierzchnia_model.dart'; // Make sure the path matches your project structure

class PomiarWysokosci {
  final PowierzchniaModel powierzchnia;

  // Map that holds our grouped lists
  Map<String, List<DrzewoModel>> groupedTrees = {};

  PomiarWysokosci({required this.powierzchnia}) {
    _groupTrees();
  }

  /// Groups the trees from the surface based on species, age, and type (zywe/martwe)
  void _groupTrees() {
    groupedTrees.clear();

    for (var drzewo in powierzchnia.drzewa) {
      final String key = '${drzewo.gatunek}_${drzewo.wiek}_${drzewo.typ}';

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
    required String typ, // 'zywe' or 'martwe'
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
    if (isWysokoscPomiarActive) {
      return getTreesForHeightMeasurement(
        allTrees: allTrees,
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
      bool matchesTyp = tree.typ == typDrzewa;

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
  /// FUNCTION 2: Executed when isWysokoscPomiarActive == TRUE
  /// Routes all trees to the specific handler based on the selected mode.
  List<DrzewoModel> getTreesForHeightMeasurement({
    required List<DrzewoModel> allTrees,
    required String typDrzewa,
    required String selectedWarstwa,
    required String defaultGatunekWysokosc,
    required int defaultWiekWysokosc,
  }) {
    if (defaultGatunekWysokosc == 'Najgrubsze') {
      return _assignThickestTrees(
        allTrees: allTrees,
        selectedWarstwa: selectedWarstwa,
      );
    } else {
      return _assignProportionalTrees(
        allTrees: allTrees,
        typDrzewa: typDrzewa,
        selectedWarstwa: selectedWarstwa,
        gatunek: defaultGatunekWysokosc,
        wiek: defaultWiekWysokosc,
      );
    }
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

      // Strictly force 'zywe' regardless of the tab parameter
      bool matchesTyp = tree.typ == 'zywe';

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
    // 1. Filter strictly by layer, type, and specific species/age (for target trees to evaluate)
    List<DrzewoModel> targetTrees = allTrees.where((tree) {
      bool matchesWarstwa = (selectedWarstwa == 'Wszyst.') ||
          (tree.warstwa.toString() == selectedWarstwa || tree.warstwa.toString().isEmpty);
      bool matchesTyp = tree.typ == typDrzewa;
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
      bool matchesTyp = tree.typ == typDrzewa;

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
        int midLeft = midRight - 1;

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