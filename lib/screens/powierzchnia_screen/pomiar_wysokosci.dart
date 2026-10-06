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

  /// Funkcja do wyznaczania drzew, dla których wymagany jest pomiar wysokości
  void wyznaczDrzewaDoWysokosci(List<DrzewoModel> filteredTrees) {
    // 1. Zresetuj flagę wysRequired dla wszystkich drzew na liście (czysty start)
    for (var tree in filteredTrees) {
      tree.wysRequired = false;
    }

    if (filteredTrees.isEmpty) return;

    // 2. Tworzymy kopię listy, aby móc ją swobodnie sortować po 'odl'
    List<DrzewoModel> sortedByOdl = List.from(filteredTrees);
    sortedByOdl.sort((a, b) => a.odl.compareTo(b.odl));

    // 3. Take ONLY the first subgroup (max 6 closest trees)
    // Instead of a for loop, we just check if there are fewer than 6 trees, or take exactly 6.
    int end = sortedByOdl.length < 6 ? sortedByOdl.length : 6;
    List<DrzewoModel> closestSubgroup = sortedByOdl.sublist(0, end);

    // 4. Sort this single subgroup by 'srednica' (ascending)
    closestSubgroup.sort((a, b) => a.srednica.compareTo(b.srednica));

    // 5. Change the flag for the 2 middle trees (only from this 6-tree group)
    int n = closestSubgroup.length;
    if (n <= 2) {
      // If there are only 1 or 2 trees in total, mark all of them
      for (var tree in closestSubgroup) {
        tree.wysRequired = true;
      }
    } else {
      // Calculate the middle indices strictly for this single group of max 6 trees
      int midRight = n ~/ 2;
      int midLeft = midRight - 1;

      closestSubgroup[midLeft].wysRequired = true;
      closestSubgroup[midRight].wysRequired = true;
    }
  }



  /// Helper method to manually refresh the lists if trees are added/removed
  /// in the original powierzchnia after this class was created.
  void refreshData() {
    _groupTrees();
  }
}