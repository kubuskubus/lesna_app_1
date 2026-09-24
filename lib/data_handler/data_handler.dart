import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';



// Ensure this file contains PowierzchniaModel, DrzewoModel, and DrzewoMartweModel
import '../screens/powierzchnia_model.dart';

class DataHandler {

  // --- FILE PATH DEFINITIONS ---


  // Ensure these are imported in data_handler.dart
// import 'dart:convert';
// import 'dart:io';
// import 'package:path_provider/path_provider.dart';
// import 'package:flutter/foundation.dart';

  Future<List<Map<String, dynamic>>> loadNumPpFromJson() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/trees_data.json');

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final dynamic jsonData = jsonDecode(jsonString);

        List<Map<String, dynamic>> result = [];

        if (jsonData is List) {
          for (var item in jsonData) {
            if (item is Map) {
              // Convert the dynamic map to strongly typed Map<String, dynamic>
              result.add(Map<String, dynamic>.from(item));
            }
          }
        }

        debugPrint('Loaded ${result.length} entries from JSON.');
        return result;
      } else {
        debugPrint('JSON file not found.');
        return [];
      }
    } catch (e) {
      debugPrint('Error reading or parsing JSON: $e');
      return [];
    }
  }




  Future<bool> pickAndImportJson() async {
    try {
      // In file_picker v12+, pickFile returns a PlatformFile directly.
      PlatformFile? result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      // Access .path and .name directly on the PlatformFile
      if (result != null && result.path != null) {
        final sourcePath = result.path!;
        final fileName = result.name;

        // Get the app's internal documents directory
        final appDir = await getApplicationDocumentsDirectory();

        // Construct the target file path
        final targetFile = File('${appDir.path}/$fileName');

        // Copy the file from the picked location to the internal directory
        await File(sourcePath).copy(targetFile.path);

        return true; // Success
      }

      return false; // User canceled
    } catch (e) {
      // Handle error quietly or log it properly using a logging framework
      return false;
    }
  }




  /// Opens the file picker, selects a zip archive, and extracts it to internal storage.
  Future<bool> pickAndImportDatabase() async {
    try {
      // Pick the ZIP file using file_picker
      PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (file != null && file.path != null) {
        final filePath = file.path!;
        final bytes = File(filePath).readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(bytes);
        final appDir = await getApplicationDocumentsDirectory();

        // Extract each file found in the zip to the app's internal documents folder
        for (final entry in archive) {
          final filename = entry.name;
          if (entry.isFile) {
            final data = entry.content as List<int>;

            // Construct the target file path in the app's internal documents directory
            final targetFile = File('${appDir.path}/$filename');

            // Ensure parent directories exist if the zip contains nested paths
            targetFile.parent.createSync(recursive: true);

            // Write the raw bytes directly with the exact same name
            targetFile.writeAsBytesSync(data);

            print('Zapisano plik w folderze wewnętrznym: ${targetFile.path}');
          }
        }
        return true; // Success
      }
      return false; // User canceled
    } catch (e) {
      print('Error picking or extracting zip: $e');
      return false;
    }
  }

  Future<File> _getPowierzchnieFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/powierzchnie.json');
  }

  Future<File> _getDrzewaFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/drzewa.json');
  }

  Future<File> _getDrzewaMartweFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/drzewa_martwe.json');
  }

  // --- LOADING METHODS ---

  Future<List<PowierzchniaModel>> loadPowierzchnie() async {
    try {
      final file = await _getPowierzchnieFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> decodedData = jsonDecode(contents);
        return decodedData
            .map((item) => PowierzchniaModel.fromJson(item))
            .toList();
      }
    } catch (e) {
      print('Error loading powierzchnie: $e');
    }
    return [];
  }



  // --- SAVING METHODS ---


  Future<void> savePowierzchnie(List<PowierzchniaModel> powierzchnie) async {
    try {
      final file = await _getPowierzchnieFile();

      // This automatically calls toJson() on PowierzchniaModel,
      // which in turn calls toJson() on every DrzewoModel inside it.
      final jsonList = powierzchnie.map((item) => item.toJson()).toList();

      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print('Error saving powierzchnie: $e');
    }
  }


  Future<bool> importDatabaseZip(String zipFilePath) async {
    try {
      final bytes = File(zipFilePath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      final appDir = await getApplicationDocumentsDirectory();

      // Extract each file found in the zip to the app's documents folder
// Extract each file found in the zip to the app's documents folder
      for (final entry in archive) {
        // Extract just the file name, ignoring any folders
        String filename = entry.name.split('/').last;

        // Skip folder entries which have empty filenames after the split
        if (filename.isEmpty || !entry.isFile) continue;

        // --- RENAME LOGIC ---
        // Map the zip filenames to the names your app expects
        if (filename == 'f_ref_surfaces.json') {
          filename = 'powierzchnie.json';
        } else if (filename == 'f_ref_trees.json') {
          filename = 'drzewa.json';
        } else if (filename == 'f_ref_dead_wood.json') {
          filename = 'drzewa_martwe.json';
        }
        // --------------------

        final data = entry.content as List<int>;

        // This will now overwrite your app's existing files with the mapped names
        File('${appDir.path}/$filename')
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      }
      return true; // Success
    } catch (e) {
      print('Error extracting zip: $e');
      return false;
    }
  }
}