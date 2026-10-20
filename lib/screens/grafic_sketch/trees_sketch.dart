import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lesna_app_1/screens/powierzchnia_screen/powierzchnia_model.dart';

class TreesSketch {
  /// Analyzes the list of trees to find the most common 'warstwa' and assigns colors accordingly
  static Map<String, ({Color fill, Color border, Color text})> buildWarstwaColorMap(List<DrzewoModel> drzewa) {
    // 1. Count occurrences of each warstwa for live trees only
    final Map<String, int> counts = {};
    for (final d in drzewa) {
      if (d.typ['state'] == 'zywe' && d.typ['type'] != 'gwozdz') {
        counts[d.warstwa] = (counts[d.warstwa] ?? 0) + 1;
      }
    }

    // 2. Sort the warstwa keys by their count in descending order
    final sortedWarstwy = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    // 3. Define the palette for up to 5 layers
    final List<({Color fill, Color border, Color text})> palettes = [
      (fill: Colors.lightGreen.shade600.withOpacity(0.85), border: Colors.green.shade900, text: Colors.green.shade900), // 1st: Standard Green
      (fill: Colors.teal.shade400.withOpacity(0.85), border: Colors.teal.shade900, text: Colors.teal.shade900),         // 2nd: Teal
      (fill: Colors.purple.shade400.withOpacity(0.85), border: Colors.purple.shade900, text: Colors.purple.shade900),   // 3rd: Purple
      (fill: Colors.amber.shade500.withOpacity(0.85), border: Colors.amber.shade900, text: Colors.amber.shade900),      // 4th: Amber
      (fill: Colors.pink.shade400.withOpacity(0.85), border: Colors.pink.shade900, text: Colors.pink.shade900),         // 5th: Pink
    ];

    // 4. Map the sorted layers to the colors
    final Map<String, ({Color fill, Color border, Color text})> colorMap = {};
    for (int i = 0; i < sortedWarstwy.length; i++) {
      // Use modulo operator so if there are more than 5 layers, it repeats the palette safely
      colorMap[sortedWarstwy[i]] = palettes[i % palettes.length];
    }

    return colorMap;
  }

  /// Draws all trees from the provided list
  static void drawTrees({
    required Canvas canvas,
    required List<DrzewoModel> drzewa,
    required Offset centerCanvas,
    required double meterToCanvasScale,
    required double zoom,
    required double treeDiameterScaleFactor,
  }) {
    if (drzewa.isEmpty) return;

    // Build the color map for the current list of trees BEFORE drawing
    final warstwaColors = buildWarstwaColorMap(drzewa);

    for (final drzewo in drzewa) {
      if (drzewo.azymut == null) continue;
      if (drzewo.typ['state'] == 'martwe') continue;

      final Offset treeCanvasPos = calculateTreeCanvasPosition(
        azymut: drzewo.azymut!,
        odl: drzewo.odl,
        diameterMeters: drzewo.srednica / 100.0,
        centerCanvas: centerCanvas,
        meterToCanvasScale: meterToCanvasScale,
      );

      // Pass the computed color map into the styling method
      final style = getTreeStyle(drzewo, warstwaColors);
      final bool isGwozdz = drzewo.typ['type'] == 'gwozdz';

      double offsetForLabel;

      if (isGwozdz) {
        final double crossSize = 4.0 / zoom;
        offsetForLabel = crossSize;

        final crossPaint = Paint()
          ..color = style.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / zoom;

        // Restored missing '-' and '+' operators
        canvas.drawLine(
          Offset(treeCanvasPos.dx - crossSize, treeCanvasPos.dy - crossSize),
          Offset(treeCanvasPos.dx + crossSize, treeCanvasPos.dy + crossSize),
          crossPaint,
        );
        canvas.drawLine(
          Offset(treeCanvasPos.dx + crossSize, treeCanvasPos.dy - crossSize),
          Offset(treeCanvasPos.dx - crossSize, treeCanvasPos.dy + crossSize),
          crossPaint,
        );
      } else {
        final double treeRadiusMeters = (drzewo.srednica / 200.0) * treeDiameterScaleFactor;
        // Restored missing '*' operator
        final double rawRadiusCanvas = treeRadiusMeters * meterToCanvasScale;
        final double treeRadiusCanvas = math.max(rawRadiusCanvas, 2.5 / zoom);
        offsetForLabel = treeRadiusCanvas;

        final fillPaint = Paint()
          ..color = style.fill
          ..style = PaintingStyle.fill;

        final borderPaint = Paint()
          ..color = style.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 / zoom;

        canvas.drawCircle(treeCanvasPos, treeRadiusCanvas, fillPaint);
        canvas.drawCircle(treeCanvasPos, treeRadiusCanvas, borderPaint);
      }

      final String label = '${style.prefix}${drzewo.numer}';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: style.text,
            fontSize: 10.0,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.white.withOpacity(0.75),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      final double targetX = treeCanvasPos.dx + offsetForLabel + (2.0 / zoom);
      final double targetY = treeCanvasPos.dy;

      canvas.translate(targetX, targetY);
      canvas.scale(1.0 / zoom);
      textPainter.paint(canvas, Offset(0, -textPainter.height / 2));
      canvas.restore();
    }
  }

  /// Function to detect the tapped tree from the provided list
  static DrzewoModel? findTappedTree({
    required Offset tapCanvasPosition,
    required List<DrzewoModel> drzewa,
    required Offset centerCanvas,
    required double meterToCanvasScale,
    required double zoom,
    required double treeDiameterScaleFactor,
  }) {
    for (final drzewo in drzewa.reversed) {
      if (drzewo.azymut == null) continue;
      if (drzewo.typ['state'] == 'martwe') continue;

      final Offset treeCanvasPos = calculateTreeCanvasPosition(
        azymut: drzewo.azymut!,
        odl: drzewo.odl,
        diameterMeters: drzewo.srednica / 100.0,
        centerCanvas: centerCanvas,
        meterToCanvasScale: meterToCanvasScale,
      );

      final double treeRadiusMeters = (drzewo.srednica / 200.0) * treeDiameterScaleFactor;
      final double rawRadiusCanvas = treeRadiusMeters * meterToCanvasScale; // Restored '*'
      final double treeRadiusCanvas = math.max(rawRadiusCanvas, 2.5 / zoom);

      final double hitThreshold = treeRadiusCanvas + (15.0 / zoom);

      final double distance = (tapCanvasPosition - treeCanvasPos).distance; // Restored '-'
      if (distance <= hitThreshold) {
        return drzewo;
      }
    }
    return null;
  }

  // Updated to accept the color map
  static ({String prefix, Color fill, Color border, Color text}) getTreeStyle(
      DrzewoModel drzewo,
      Map<String, ({Color fill, Color border, Color text})> warstwaColors,
      ) {
    final stateStr = (drzewo.typ['state'] ?? '').toLowerCase().trim();
    final typeStr = (drzewo.typ['type'] ?? '').toLowerCase().trim();
    final combined = '$stateStr $typeStr';

    if (combined.contains('gwozdz') || combined.contains('gwóźdź')) {
      return (prefix: 'G', fill: Colors.blue.shade400.withOpacity(0.85), border: Colors.blue.shade900, text: Colors.blue.shade900);
    } else if (combined.contains('martw') || combined.contains('posusz') || combined.contains('zlom') || combined.contains('złom') || combined.contains('wywrot')) {
      return (prefix: 'M', fill: Colors.deepOrange.shade400.withOpacity(0.85), border: Colors.brown.shade900, text: Colors.deepOrange.shade900);
    }
    else if (drzewo.wysRequired == true) {
      return (prefix: 'Z', fill: Colors.indigo.shade400.withOpacity(0.85), border: Colors.indigo.shade900, text: Colors.indigo.shade900);
    }
    else {
      // Dynamic layer color assignment. Fallback to standard green if map fails.
      final colors = warstwaColors[drzewo.warstwa] ?? (
      fill: Colors.lightGreen.shade600.withOpacity(0.85),
      border: Colors.green.shade900,
      text: Colors.green.shade900
      );
      return (prefix: 'Z', fill: colors.fill, border: colors.border, text: colors.text);
    }
  }

  static Offset calculateTreeCanvasPosition({
    required double azymut,
    required double odl,
    required double diameterMeters,
    required Offset centerCanvas,
    required double meterToCanvasScale,
  }) {
    // Restored all missing '*' and '-' operators
    final double azymutRad = azymut * (math.pi / 180.0);
    final double dxMeters = odl * math.sin(azymutRad);
    final double dyMeters = odl * math.cos(azymutRad);

    final double shiftAzymutRad = azymutRad + (math.pi / 2.0);
    final double radiusMeters = diameterMeters / 2.0;
    final double shiftX = radiusMeters * math.sin(shiftAzymutRad);
    final double shiftY = radiusMeters * math.cos(shiftAzymutRad);

    final double trueDxMeters = dxMeters + shiftX;
    final double trueDyMeters = dyMeters + shiftY;

    return Offset(
      centerCanvas.dx + (trueDxMeters * meterToCanvasScale),
      centerCanvas.dy - (trueDyMeters * meterToCanvasScale),
    );
  }
}