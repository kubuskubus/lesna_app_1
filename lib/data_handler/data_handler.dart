import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

import '../screens/powierzchnia_model.dart';

class DataHandler {

  Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/powierzchnie_store.json');
  }

  // Returns the list of models instead of calling setState
  Future<List<PowierzchniaModel>> loadSavedData() async {
    try {
      final file = await _getLocalFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> decodedData = jsonDecode(contents);

        return decodedData
            .map((item) => PowierzchniaModel.fromJson(item))
            .toList();
      }
    } catch (e) {
      print('Error loading data: $e');
    }
    return []; // Return empty list if file doesn't exist or errors out
  }

  // Takes the list as a parameter instead of accessing a global/state variable
  Future<void> saveDataLocally(List<PowierzchniaModel> powierzchnie) async {
    try {
      final file = await _getLocalFile();
      final jsonList = powierzchnie.map((item) => item.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print('Error saving data: $e');
    }
  }
}