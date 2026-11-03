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
      if (style == null) continue;

      final bool isGwozdz = drzewo.typ['type'] == 'gwozdz';
      double offsetForLabel;

      // 1. Draw the specific shape and label (Gwozdz or Drzewo)
      if (isGwozdz) {
        // Draw dashed line from center to the gwozdz with parallel text
        _drawDashedLineToCenter(
          canvas: canvas,
          start: centerCanvas,
          end: treeCanvasPos,
          zoom: zoom,
          azymut: drzewo.azymut!, // <-- Passed azymut
          odl: drzewo.odl,        // <-- Passed odl
        );
        offsetForLabel = _drawGwozdzShape(
          canvas: canvas,
          treeCanvasPos: treeCanvasPos,
          style: style,
          zoom: zoom,
        );

        _drawLabelGwozdz(
          canvas: canvas,
          treeCanvasPos: treeCanvasPos,
          style: style,
          offsetForLabel: offsetForLabel,
          zoom: zoom,
        );
      } else {
        offsetForLabel = _drawDrzewoShape(
          canvas: canvas,
          drzewo: drzewo,
          treeCanvasPos: treeCanvasPos,
          style: style,
          meterToCanvasScale: meterToCanvasScale,
          zoom: zoom,
          treeDiameterScaleFactor: treeDiameterScaleFactor,
        );

        _drawLabelTree(
          canvas: canvas,
          treeCanvasPos: treeCanvasPos,
          style: style,
          offsetForLabel: offsetForLabel,
          zoom: zoom,
        );
      }
    }
  }

  /// Helper to draw a dashed line from the center of the plot to the gwozdz with a label
  static void _drawDashedLineToCenter({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required double zoom,
    required double azymut,
    required double odl,
  }) {
    final Paint dashPaint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / zoom;

    final double distance = (end - start).distance;
    if (distance <= 0) return;

    final Offset direction = (end - start) / distance;
    final double dashWidth = 4.0 / zoom;
    final double dashSpace = 4.0 / zoom;
    double currentDistance = 0.0;

    // 1. Draw the dashed line
    while (currentDistance < distance) {
      final Offset dashStart = start + direction * currentDistance;
      final Offset dashEnd = start + direction * math.min(currentDistance + dashWidth, distance);

      canvas.drawLine(dashStart, dashEnd, dashPaint);
      currentDistance += dashWidth + dashSpace;
    }

    // 2. Prepare the text label
    final String labelStr = '${azymut.toStringAsFixed(0)}°, ${odl.toStringAsFixed(2)} m';
    final textPainter = TextPainter(
      text: TextSpan(
        text: labelStr,
        style: TextStyle(
          color: Colors.black87,
          fontSize: 9.0,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.white.withOpacity(0.85),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // 3. Calculate position and angle
    final Offset midPoint = (start + end) / 2;
    double angle = math.atan2(end.dy - start.dy, end.dx - start.dx);

    // Flip the text if it's upside down (heading left)
    if (angle > math.pi / 2 || angle < -math.pi / 2) {
      angle += math.pi;
    }

    // 4. Draw the rotated text
    canvas.save();
    canvas.translate(midPoint.dx, midPoint.dy);
    canvas.rotate(angle);
    canvas.scale(1.0 / zoom);

    // Offset slightly above the line
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height - 2.0));
    canvas.restore();
  }

  /// Helper to render the text label specifically for a 'gwozdz'
  static void _drawLabelGwozdz({
    required Canvas canvas,
    required Offset treeCanvasPos,
    required ({String prefix, Color fill, Color border, Color text, bool alignLeft}) style,
    required double offsetForLabel,
    required double zoom,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: style.prefix,
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

    final double targetX = style.alignLeft
        ? treeCanvasPos.dx - offsetForLabel - (textPainter.width / zoom) - (2.0 / zoom)
        : treeCanvasPos.dx + offsetForLabel + (2.0 / zoom);

    final double targetY = treeCanvasPos.dy;

    canvas.translate(targetX, targetY);
    canvas.scale(1.0 / zoom);
    textPainter.paint(canvas, Offset(0, -textPainter.height / 2));
    canvas.restore();
  }

  /// Helper to render the text label specifically for a standard tree
  static void _drawLabelTree({
    required Canvas canvas,
    required Offset treeCanvasPos,
    required ({String prefix, Color fill, Color border, Color text, bool alignLeft}) style,
    required double offsetForLabel,
    required double zoom,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: style.prefix,
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

    final double targetX = style.alignLeft
        ? treeCanvasPos.dx - offsetForLabel - (textPainter.width / zoom) - (2.0 / zoom)
        : treeCanvasPos.dx + offsetForLabel + (2.0 / zoom);

    final double targetY = treeCanvasPos.dy;

    canvas.translate(targetX, targetY);
    canvas.scale(1.0 / zoom);
    textPainter.paint(canvas, Offset(0, -textPainter.height / 2));
    canvas.restore();
  }

  /// Helper to draw a 'gwozdz' (nail) as a cross and return its label offset
  static double _drawGwozdzShape({
    required Canvas canvas,
    required Offset treeCanvasPos,
    required ({String prefix, Color fill, Color border, Color text, bool alignLeft}) style,
    required double zoom,
  }) {
    final double crossSize = 4.0 / zoom;
    final crossPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 / zoom;

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

    return crossSize;
  }

  /// Helper to draw a standard tree as a circle and return its label offset
  static double _drawDrzewoShape({
    required Canvas canvas,
    required DrzewoModel drzewo,
    required Offset treeCanvasPos,
    required ({String prefix, Color fill, Color border, Color text, bool alignLeft}) style,
    required double meterToCanvasScale,
    required double zoom,
    required double treeDiameterScaleFactor,
  }) {
    final double treeRadiusMeters = (drzewo.srednica / 200.0) * treeDiameterScaleFactor;
    final double rawRadiusCanvas = treeRadiusMeters * meterToCanvasScale;
    final double treeRadiusCanvas = math.max(rawRadiusCanvas, 2.5 / zoom);

    final fillPaint = Paint()
      ..color = style.fill
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = style.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 / zoom;

    canvas.drawCircle(treeCanvasPos, treeRadiusCanvas, fillPaint);
    canvas.drawCircle(treeCanvasPos, treeRadiusCanvas, borderPaint);

    return treeRadiusCanvas;
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

  // Updated to accept the color map and dynamic label
  // Added 'alignLeft' to the returned Record
  static ({String prefix, Color fill, Color border, Color text, bool alignLeft})? getTreeStyle(
      DrzewoModel drzewo,
      Map<String, ({Color fill, Color border, Color text})> warstwaColors,
      ) {
    final stateStr = (drzewo.typ['state'] ?? '').toLowerCase().trim();
    final typeStr = (drzewo.typ['type'] ?? '').toLowerCase().trim();
    final combined = '$stateStr $typeStr';

    if (stateStr != 'zywe' && !combined.contains('gwozdz') && !combined.contains('gwóźdź')) {
      return null;
    }

    final String dynamicLabel = '${drzewo.gatunek}${drzewo.wiek}_${drzewo.numer}';

    if (combined.contains('gwozdz') || combined.contains('gwóźdź')) {
      return (prefix: 'G_${drzewo.numer}', fill: Colors.blue.shade400.withOpacity(0.85), border: Colors.blue.shade900, text: Colors.blue.shade900, alignLeft: true);
    }
    else if (drzewo.wysRequired == true) {
      return (prefix: dynamicLabel, fill: Colors.indigo.shade400.withOpacity(0.85), border: Colors.indigo.shade900, text: Colors.indigo.shade900, alignLeft: false);
    }
    else {
      final colors = warstwaColors[drzewo.warstwa] ?? (
      fill: Colors.lightGreen.shade600.withOpacity(0.85),
      border: Colors.green.shade900,
      text: Colors.green.shade900
      );
      return (prefix: dynamicLabel, fill: colors.fill, border: colors.border, text: colors.text, alignLeft: false);
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