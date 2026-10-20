import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lesna_app_1/screens/powierzchnia_screen/powierzchnia_model.dart';

class TreesSketch {
  /// Draws all trees
  static void drawTrees({
    required Canvas canvas,
    required PowierzchniaModel powierzchnia,
    required Offset centerCanvas,
    required double meterToCanvasScale,
    required double zoom,
    required double treeDiameterScaleFactor,
  }) {
    final drzewa = powierzchnia.drzewa;
    if (drzewa.isEmpty) return;

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

      final style = getTreeStyle(drzewo);
      final bool isGwozdz = drzewo.typ['type'] == 'gwozdz';

      double offsetForLabel;

      if (isGwozdz) {
        // 1. Draw 'X' for gwozdz since it has no size
        final double crossSize = 4.0 / zoom;
        offsetForLabel = crossSize;

        final crossPaint = Paint()
          ..color = style.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / zoom;

        // Draw first diagonal line
        canvas.drawLine(
          Offset(treeCanvasPos.dx - crossSize, treeCanvasPos.dy - crossSize),
          Offset(treeCanvasPos.dx + crossSize, treeCanvasPos.dy + crossSize),
          crossPaint,
        );
        // Draw second diagonal line
        canvas.drawLine(
          Offset(treeCanvasPos.dx + crossSize, treeCanvasPos.dy - crossSize),
          Offset(treeCanvasPos.dx - crossSize, treeCanvasPos.dy + crossSize),
          crossPaint,
        );
      } else {
        // 2. Draw standard circle for live trees based on their diameter
        final double treeRadiusMeters = (drzewo.srednica / 200.0) * treeDiameterScaleFactor;
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

      // 3. Draw the label
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
      // Offset the text so it starts just outside the circle or the 'X'
      final double targetX = treeCanvasPos.dx + offsetForLabel + (2.0 / zoom);
      final double targetY = treeCanvasPos.dy;

      canvas.translate(targetX, targetY);
      canvas.scale(1.0 / zoom);
      textPainter.paint(canvas, Offset(0, -textPainter.height / 2));
      canvas.restore();
    }
  }

  /// NEW: Function to detect the tapped tree
  static DrzewoModel? findTappedTree({
    required Offset tapCanvasPosition,
    required PowierzchniaModel powierzchnia,
    required Offset centerCanvas,
    required double meterToCanvasScale,
    required double zoom,
    required double treeDiameterScaleFactor,
  }) {
    for (final drzewo in powierzchnia.drzewa.reversed) {
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
      final double rawRadiusCanvas = treeRadiusMeters * meterToCanvasScale; // <-- Check *
      final double treeRadiusCanvas = math.max(rawRadiusCanvas, 2.5 / zoom);

      final double hitThreshold = treeRadiusCanvas + (15.0 / zoom);

      final double distance = (tapCanvasPosition - treeCanvasPos).distance; // <-- Check -
      if (distance <= hitThreshold) {
        return drzewo;
      }
    }
    return null;
  }

  static ({String prefix, Color fill, Color border, Color text}) getTreeStyle(DrzewoModel drzewo) {
    final stateStr = (drzewo.typ['state'] ?? '').toLowerCase().trim();
    final typeStr = (drzewo.typ['type'] ?? '').toLowerCase().trim();
    final combined = '$stateStr $typeStr';

    if (combined.contains('gwozdz') || combined.contains('gwóźdź')) {
      return (prefix: 'G', fill: Colors.blue.shade400.withOpacity(0.85), border: Colors.blue.shade900, text: Colors.blue.shade900);
    } else if (combined.contains('martw') || combined.contains('posusz') || combined.contains('zlom') || combined.contains('złom') || combined.contains('wywrot')) {
      return (prefix: 'M', fill: Colors.deepOrange.shade400.withOpacity(0.85), border: Colors.brown.shade900, text: Colors.deepOrange.shade900);
    } else {
      return (prefix: 'Z', fill: Colors.lightGreen.shade600.withOpacity(0.85), border: Colors.green.shade900, text: Colors.green.shade900);
    }
  }

  static Offset calculateTreeCanvasPosition({
    required double azymut,
    required double odl,
    required double diameterMeters,
    required Offset centerCanvas,
    required double meterToCanvasScale,
  }) {
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