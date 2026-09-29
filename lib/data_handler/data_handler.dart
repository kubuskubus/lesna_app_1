import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

// Ensure these imports match your project structure
import '../screens/powierzchnia_model.dart';

class DataHandler {
  // --- IN-MEMORY DATA STORAGE ---

  List<WydzielenieModel> wydzList = [];
  List<PowierzchniaModel> powierzchnie = [];

  // --- FILE PATH DEFINITIONS ---

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

  Future<void> loadData() async {
    try {
      final file = await _getPowierzchnieFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        final dynamic decodedData = jsonDecode(contents);

        if (decodedData is Map<String, dynamic>) {
          // 1. Load the read-only 'wydz_list_only_read' list
          if (decodedData.containsKey('wydz_list_only_read')) {
            wydzList = (decodedData['wydz_list_only_read'] as List)
                .map((item) => WydzielenieModel.fromJson(item))
                .toList();
          }

          // 2. Load the mutable 'powierzchnie' list
          if (decodedData.containsKey('powierzchnie')) {
            powierzchnie = (decodedData['powierzchnie'] as List)
                .map((item) => PowierzchniaModel.fromJson(item))
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  // --- SAVING METHODS ---

  Future<void> savePowierzchnie() async {
    try {
      final file = await _getPowierzchnieFile();

      // Reconstruct the dictionary with both keys
      final Map<String, dynamic> dataToSave = {
        'wydz_list_only_read': wydzList.map((item) => item.toJson()).toList(),
        'powierzchnie': powierzchnie.map((item) => item.toJson()).toList(),
      };

      await file.writeAsString(jsonEncode(dataToSave));
    } catch (e) {
      debugPrint('Error saving data: $e');
    }
  }

  // --- IMPORTING METHODS ---

  Future<bool> pickAndImportJson() async {
    try {
      PlatformFile? result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.path != null) {
        final sourcePath = result.path!;
        final file = File(sourcePath);

        final jsonString = await file.readAsString();
        final dynamic decodedData = jsonDecode(jsonString);

        // Clear current lists
        wydzList.clear();
        powierzchnie.clear();

        if (decodedData is Map<String, dynamic>) {
          if (decodedData.containsKey('wydz_list_only_read')) {
            wydzList = (decodedData['wydz_list_only_read'] as List)
                .map((item) => WydzielenieModel.fromJson(item))
                .toList();
          }

          if (decodedData.containsKey('powierzchnie')) {
            powierzchnie = (decodedData['powierzchnie'] as List)
                .map((item) => PowierzchniaModel.fromJson(item))
                .toList();
          }
        }

        // Save the parsed data to internal memory
        await savePowierzchnie();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error importing and parsing JSON: $e');
      return false;
    }
  }

  // this fun will copy file if doesnt exist
  // if exist - it will take powierzchnie and try to match all empty powierzchnie
  Future<bool> mergeOrInitExternalFile(String targetFileName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final targetFile = File('${appDir.path}/$targetFileName');

      // 1. Pick the external JSON file first
      PlatformFile? result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.path == null) {
        return false;
      }

      final externalFile = File(result.path!);

      // 2. If the internal file DOES NOT exist, simply copy the picked file and load it!
      if (!await targetFile.exists()) {
        await externalFile.copy(targetFile.path);

        if (targetFileName == 'powierzchnie.json') {
          await loadData();
        }

        debugPrint('Plik wewnętrzny nie istniał. Zaimportowano pomyślnie: ${targetFile.path}');
        return true;
      }

      // 3. OTHERWISE, run your merge logic (since the internal file exists)
      final externalJsonString = await externalFile.readAsString();
      final dynamic externalDecoded = jsonDecode(externalJsonString);

      List<dynamic> externalDataList = [];
      if (externalDecoded is List) {
        externalDataList = externalDecoded;
      } else if (externalDecoded is Map<String, dynamic>) {
        for (var entry in externalDecoded.entries) {
          if (entry.value is List) {
            externalDataList = entry.value;
            break;
          }
        }
      }

      final List<PowierzchniaModel> externalPowierzchnie = externalDataList
          .map((json) => PowierzchniaModel.fromJson(json))
          .toList();

      // Read and parse the internal JSON file
      final internalJsonString = await targetFile.readAsString();
      final dynamic internalDecoded = jsonDecode(internalJsonString);

      List<dynamic> internalDataList = [];
      if (internalDecoded is List) {
        internalDataList = internalDecoded;
      } else if (internalDecoded is Map<String, dynamic>) {
        for (var entry in internalDecoded.entries) {
          if (entry.value is List) {
            internalDataList = entry.value;
            break;
          }
        }
      }

      final List<PowierzchniaModel> internalPowierzchnie = internalDataList
          .map((json) => PowierzchniaModel.fromJson(json))
          .toList();

      bool hasChanges = false;

      // 4. Merge: Replace empty internal surfaces with filled external ones
      for (var extPow in externalPowierzchnie) {
        bool isExternalNotEmpty = extPow.drzewa.isNotEmpty;

        if (isExternalNotEmpty) {
          int internalIndex = internalPowierzchnie.indexWhere((p) => p.numer == extPow.numer);

          if (internalIndex >= 0) {
            bool isInternalEmpty = internalPowierzchnie[internalIndex].drzewa.isEmpty;

            if (isInternalEmpty) {
              internalPowierzchnie[internalIndex] = extPow;
              hasChanges = true;
              debugPrint('Zastąpiono pustą powierzchnię numer ${extPow.numer} danymi z pliku zewnętrznego.');
            }
          }
        }
      }

      // 5. Save back if changes were made
      if (hasChanges) {
        final updatedJsonList = internalPowierzchnie.map((p) => p.toJson()).toList();
        await targetFile.writeAsString(jsonEncode(updatedJsonList));

        if (targetFileName == 'powierzchnie.json') {
          await loadData();
        }

        debugPrint('Pomyślnie zaktualizowano puste powierzchnie.');
        return true;
      }

      debugPrint('Brak pustych powierzchni do zastąpienia.');
      return false;

    } catch (e) {
      debugPrint('Błąd podczas obsługi pliku: $e');
      return false;
    }
  }
  // --- EXPORTING METHOD ---

  Future<bool> exportPowierzchnieJson() async {
    try {
      // Ensure memory lists are saved to file before exporting
      await savePowierzchnie();

      final internalFile = await _getPowierzchnieFile();

      if (!await internalFile.exists()) {
        debugPrint('Brak pliku do eksportu.');
        return false;
      }

      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Generate a unique timestamp string (e.g., 2026-09-29_17-09-27)
      final String timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first; // YYYY-MM-DDTHH-mm-ss

      final targetFile = File('${downloadsDir.path}/eksport_powierzchnie_$timestamp.json');
      await internalFile.copy(targetFile.path);

      debugPrint('Wyeksportowano do: ${targetFile.path}');
      return true;
    } catch (e) {
      debugPrint('Błąd podczas eksportu: $e');
      return false;
    }
  }

  // --- OTHER METHODS ---

  Future<bool> importDatabaseZip(String zipFilePath) async {
    try {
      final bytes = File(zipFilePath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      final appDir = await getApplicationDocumentsDirectory();

      for (final entry in archive) {
        String filename = entry.name.split('/').last;
        if (filename.isEmpty || !entry.isFile) continue;

        if (filename == 'f_ref_surfaces.json') {
          filename = 'powierzchnie.json';
        } else if (filename == 'f_ref_trees.json') {
          filename = 'drzewa.json';
        } else if (filename == 'f_ref_dead_wood.json') {
          filename = 'drzewa_martwe.json';
        }

        final data = entry.content as List<int>;
        File('${appDir.path}/$filename')
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      }

      await loadData(); // Refresh lists after zip import
      return true;
    } catch (e) {
      debugPrint('Error extracting zip: $e');
      return false;
    }
  }

  Future<void> formatInternalMemory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final List<String> filesToDelete = [
        'powierzchnie.json',
        'drzewa.json',
        'drzewa_martwe.json',
        'trees_data.json'
      ];

      for (String fileName in filesToDelete) {
        final file = File('${directory.path}/$fileName');
        if (await file.exists()) {
          await file.delete();
          debugPrint('Usunięto plik wewnętrzny: $fileName');
        }
      }

      // Clear class lists
      wydzList.clear();
      powierzchnie.clear();

    } catch (e) {
      debugPrint('Błąd podczas formatowania pamięci: $e');
    }
  }
}