import 'powierzchnia_model.dart'; // Make sure this path matches your project structure

class PomiarWysokosci {
  final PowierzchniaModel powierzchnia;

  // The map that will hold our separated lists
  // Key format: "Gatunek_Wiek_Typ" (e.g., "SO_60_zywe")
  // Value: List of trees matching that criteria
  Map<String, List<DrzewoModel>> groupedTrees = {};

  PomiarWysokosci({required this.powierzchnia}) {
    // Automatically group the trees when the class is initialized
    _groupTrees();
  }

  /// Groups the trees from the powierzchnia into separate lists
  /// based on Gatunek, Wiek, and Typ (zywe/martwe).
  void _groupTrees() {
    // Clear the map in case this is called again to refresh data
    groupedTrees.clear();

    for (var drzewo in powierzchnia.drzewa) {
      // Create a unique key for this specific combination
      final String key = '${drzewo.gatunek}_${drzewo.wiek}_${drzewo.typ}';

      // If the list for this combination doesn't exist yet, create it
      if (!groupedTrees.containsKey(key)) {
        groupedTrees[key] = [];
      }

      // Add the tree to its respective list
      groupedTrees[key]!.add(drzewo);
    }
  }

  /// Helper method to easily retrieve a specific list of trees
  List<DrzewoModel> getTreesFor({
    required String gatunek,
    required int wiek,
    required String typ, // 'zywe' or 'martwe'
  }) {
    final String key = '${gatunek}_${wiek}_${typ}';
    return groupedTrees[key] ?? []; // Returns empty list if no trees match
  }

  /// Function to designate trees for which height measurement is required
  /// Function to designate trees for which height measurement is required
  void assignTreesForHeight(List<DrzewoModel> filteredTrees, String defaultHeightMode) {
    // 1. Reset the wysRequired flag for all trees in the list (clean start)
    for (var tree in filteredTrees) {
      tree.wysRequired = false;
    }

    if (filteredTrees.isEmpty) return;

    // 2. Check which mode is selected
    if (defaultHeightMode == 'Najgrubsze') {
      // MODE: "Najgrubsze" (The Thickest)
      List<DrzewoModel> sortedByDiameterDesc = List.from(filteredTrees);
      sortedByDiameterDesc.sort((a, b) => b.srednica.compareTo(a.srednica));

      int count = sortedByDiameterDesc.length < 4 ? sortedByDiameterDesc.length : 4;
      for (int i = 0; i < count; i++) {
        sortedByDiameterDesc[i].wysRequired = true;
      }
    } else {
      // DEFAULT MODE: Check percentage against all trees in powierzchnia.drzewa
      int totalTreesCount = powierzchnia.drzewa.length;
      bool isMoreThan70Percent = totalTreesCount > 0 && (filteredTrees.length / totalTreesCount) > 0.7;

      // Create a copy of the list to sort freely by 'odl' (distance) in ASCENDING order
      List<DrzewoModel> sortedByDistance = List.from(filteredTrees);
      sortedByDistance.sort((a, b) => a.odl.compareTo(b.odl));

      if (isMoreThan70Percent) {
        // --- CONDITION A: > 70% of total trees -> Use 6 closest, pick 2 middle trees ---
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
        // --- CONDITION B: <= 70% of total trees -> Use 5 closest, pick 1 middle tree ---
        int end = sortedByDistance.length < 5 ? sortedByDistance.length : 5;
        List<DrzewoModel> closestSubgroup = sortedByDistance.sublist(0, end);
        closestSubgroup.sort((a, b) => a.srednica.compareTo(b.srednica));

        int n = closestSubgroup.length;
        if (n > 0) {
          int mid = n ~/ 2;
          closestSubgroup[mid].wysRequired = true;
        }
      }
    }
  }



  /// Helper method to manually refresh the lists if trees are added/removed
  /// in the original powierzchnia after this class was created.
  void refreshData() {
    _groupTrees();
  }
}