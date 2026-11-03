import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';

class SketchExporter {
  static Future<void> captureAndSave(GlobalKey boundaryKey, BuildContext context, String fileName) async {
    try {
      // 1. Request Gallery Access
      bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
        if (!hasAccess) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brak uprawnień do galerii'), backgroundColor: Colors.red));
          }
          return;
        }
      }

      // 2. Capture and Save
      RenderRepaintBoundary boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName.png');
      await file.writeAsBytes(byteData!.buffer.asUint8List());

      await Gal.putImage(file.path);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zapisano szkic do galerii'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd zapisu: $e'), backgroundColor: Colors.red));
      }
    }
  }
}