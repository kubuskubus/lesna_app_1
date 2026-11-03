import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lesna_app_1/screens/grafic_sketch/trees_sketch.dart';
import 'package:lesna_app_1/screens/powierzchnia_screen/powierzchnia_model.dart';

class PowierzchnieSketch {
  final PowierzchniaModel powierzchnia;
  final WydzielenieModel? wydzData;
  final List<DrzewoModel> drzewa; // <-- Added the list of trees to the class

  static const double realRadius = 11.28;
  static const double treeDiameterScaleFactor = 1.0;

  const PowierzchnieSketch({
    required this.powierzchnia,
    this.wydzData,
    required this.drzewa, // <-- Added to the constructor
  });

  /// Extracts (x, y) of center_KPP from geograficData if available
  ({double x, double y})? get centerKppCoords {
    final geoData = wydzData?.geograficData;
    if (geoData == null) return null;

    final centerKpp = geoData['center_KPP'];
    if (centerKpp is Map && centerKpp['center_coords'] is Map) {
      final coords = centerKpp['center_coords'];
      final x = (coords['x'] as num?)?.toDouble();
      final y = (coords['y'] as num?)?.toDouble();
      if (x != null && y != null) {
        return (x: x, y: y);
      }
    }
    return null;
  }

  /// Expands the bounding box around center_KPP by the maximum inclined radius
  void expandBounds(void Function(double x, double y) onPoint) {
    final kpp = centerKppCoords;
    if (kpp != null) {
      final double slopeDegrees = (powierzchnia.nachylenie).toDouble().clamp(0.0, 85.0);
      final double slopeRad = slopeDegrees * (math.pi / 180.0); // <-- Fixed operator
      final double maxRadius = realRadius / math.cos(slopeRad);

      onPoint(kpp.x - maxRadius, kpp.y - maxRadius); // <-- Fixed operators
      onPoint(kpp.x + maxRadius, kpp.y + maxRadius);
    }
  }

  /// Extracted method to handle drawing the rotated ellipse and its inner dashed axes with labels
  /// Extracted method to handle drawing the rotated ellipse and its inner dashed axes with labels
  void _drawEllipseAndAxes({
    required Canvas canvas,
    required double zoom,
    required Offset kppCenterCanvas,
    required double slopeAzimuthRad,
    required double slopeAzimuthDeg,
    required Rect localEllipseRect,
    required double radiusPerpendicularCanvas,
    required double radiusInclinedCanvas,
    required double radiusPerpendicularMeters,
    required double radiusInclinedMeters,
  }) {
    final ellipseFillPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    final ellipseStrokePaint = Paint()
      ..color = Colors.green.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 / zoom;

    final shortAxisPaint = Paint()
      ..color = Colors.blue.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / zoom;

    final longAxisPaint = Paint()
      ..color = Colors.orange.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 / zoom;

    // Helper function to draw dashed lines on the canvas
    void drawDashedLine(Offset p1, Offset p2, Paint paint) {
      final distance = (p2 - p1).distance;
      if (distance == 0) return;
      final direction = (p2 - p1) / distance;
      final dashWidth = 6.0 / zoom;
      final dashSpace = 4.0 / zoom;
      double currentDistance = 0.0;
      while (currentDistance < distance) {
        final start = p1 + direction * currentDistance;
        final end = p1 + direction * math.min(currentDistance + dashWidth, distance);
        canvas.drawLine(start, end, paint);
        currentDistance += dashWidth + dashSpace;
      }
    }

    // Save canvas state, translate to KPP center, and rotate by slope azimuth
    canvas.save();
    canvas.translate(kppCenterCanvas.dx, kppCenterCanvas.dy);
    canvas.rotate(slopeAzimuthRad);

    canvas.drawOval(localEllipseRect, ellipseFillPaint);
    canvas.drawOval(localEllipseRect, ellipseStrokePaint);

    // --- Draw Short Axis (X-axis) as Dashed Line & Adjacent Label ---
    drawDashedLine(
      Offset(-radiusPerpendicularCanvas, 0),
      Offset(radiusPerpendicularCanvas, 0),
      shortAxisPaint,
    );

    final shortTextPainter = TextPainter(
      text: TextSpan(
        text: '${radiusPerpendicularMeters.toStringAsFixed(2)} m',
        style: TextStyle(
          color: Colors.blue.shade900,
          fontSize: 9.0,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.white.withOpacity(0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Calculate X offset to place text at the right edge of the ellipse
    final double shortXEdgeOffset = radiusPerpendicularCanvas - (shortTextPainter.width / zoom) - (6.0 / zoom);

    canvas.save();
    if (slopeAzimuthDeg >= 0 && slopeAzimuthDeg <= 180) {
      canvas.translate(shortXEdgeOffset, 2.0 / zoom);
      canvas.scale(1.0 / zoom);
      shortTextPainter.paint(canvas, Offset.zero);
    } else {
      canvas.translate(shortXEdgeOffset, -(shortTextPainter.height / zoom) - (2.0 / zoom));
      canvas.scale(1.0 / zoom);
      shortTextPainter.paint(canvas, Offset.zero);
    }
    canvas.restore();


    // --- Draw Long Axis (Y-axis) as Dashed Line & Adjacent Label ---
    drawDashedLine(
      Offset(0, -radiusInclinedCanvas),
      Offset(0, radiusInclinedCanvas),
      longAxisPaint,
    );

    final longTextPainter = TextPainter(
      text: TextSpan(
        text: '${radiusInclinedMeters.toStringAsFixed(2)} m',
        style: TextStyle(
          color: Colors.orange.shade900,
          fontSize: 9.0,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.white.withOpacity(0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    if (slopeAzimuthDeg >= 0 && slopeAzimuthDeg <= 180) {
      // Calculate Y offset to place text at the top edge
      final double longYTopEdge = -radiusInclinedCanvas + (longTextPainter.width / zoom) + (6.0 / zoom);
      canvas.translate(-2.0 / zoom, longYTopEdge);
      canvas.rotate(-math.pi / 2);
      canvas.scale(1.0 / zoom);
      longTextPainter.paint(canvas, Offset(0, -longTextPainter.height));
    } else {
      // Calculate Y offset to place text at the bottom edge
      final double longYBottomEdge = radiusInclinedCanvas - (longTextPainter.width / zoom) - (6.0 / zoom);
      canvas.translate(2.0 / zoom, longYBottomEdge);
      canvas.rotate(math.pi / 2);
      canvas.scale(1.0 / zoom);
      longTextPainter.paint(canvas, Offset(0, -longTextPainter.height));
    }
    canvas.restore();

    // RESTORE THE MAIN ROTATION CANVAS BEFORE DRAWING THE CROSS AND TREES
    canvas.restore();
  }

  /// Draws the KPP ellipse rotated by slope azimuth, dashed axis lines with adjacent value labels, center red cross, and all trees
  void drawPowElipse({
    required Canvas canvas,
    required Offset Function(double x, double y) toCanvas,
    required double scale,
    required double zoom,
  }) {
    // 1. Call the extracted calculation method
    final metrics = _calculateEllipseMetrics(toCanvas, scale);
    if (metrics == null) return;

    // 2. Draw the ellipse and its internal dashed axes
    _drawEllipseAndAxes(
      canvas: canvas,
      zoom: zoom,
      kppCenterCanvas: metrics.kppCenterCanvas,
      slopeAzimuthRad: metrics.slopeAzimuthRad,
      slopeAzimuthDeg: metrics.slopeAzimuthDeg,
      localEllipseRect: metrics.localEllipseRect,
      radiusPerpendicularCanvas: metrics.radiusPerpendicularCanvas,
      radiusInclinedCanvas: metrics.radiusInclinedCanvas,
      radiusPerpendicularMeters: metrics.radiusPerpendicularMeters,
      radiusInclinedMeters: metrics.radiusInclinedMeters,
    );

    // 3. Draw center red cross
    final crossPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 / zoom;

    final double crossSize = 6.0 / zoom;
    canvas.drawLine(
      Offset(metrics.kppCenterCanvas.dx - crossSize, metrics.kppCenterCanvas.dy), // <-- Fixed operator
      Offset(metrics.kppCenterCanvas.dx + crossSize, metrics.kppCenterCanvas.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(metrics.kppCenterCanvas.dx, metrics.kppCenterCanvas.dy - crossSize), // <-- Fixed operator
      Offset(metrics.kppCenterCanvas.dx, metrics.kppCenterCanvas.dy + crossSize),
      crossPaint,
    );

    // 4. Draw overall plot info label on the top
    final String titleLabel = 'KPP ${powierzchnia.numer}';

    final kppTextPainter = TextPainter(
      text: TextSpan(
        text: titleLabel,
        style: TextStyle(
          color: Colors.green.shade900,
          fontSize: 20.0,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.white.withOpacity(0.75),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Find the max radius to know where the top edge of the ellipse is
    final double labelOffsetRadius = math.max(metrics.radiusPerpendicularCanvas, metrics.radiusInclinedCanvas);

    canvas.save();
    // Center horizontally and place above the top edge
    final double targetX = metrics.kppCenterCanvas.dx - (kppTextPainter.width / zoom / 2);
    final double targetY = metrics.kppCenterCanvas.dy - labelOffsetRadius - (kppTextPainter.height / zoom) - (20.0 / zoom);

    canvas.translate(targetX, targetY);
    canvas.scale(1.0 / zoom);
    kppTextPainter.paint(canvas, Offset.zero);
    canvas.restore();

    // 5. Draw trees inside/around the plot using the dedicated TreesSketch class
    TreesSketch.drawTrees(
      canvas: canvas,
      drzewa: drzewa, // <-- Changed 'powierzchnia' to the 'drzewa' list
      centerCanvas: metrics.kppCenterCanvas,
      meterToCanvasScale: scale,
      zoom: zoom,
      treeDiameterScaleFactor: treeDiameterScaleFactor,
    );
  }

  /// Extracts and calculates all coordinates, angles, and dimensions for the ellipse
  ({
  Offset kppCenterCanvas,
  double slopeAzimuthDeg,
  double slopeAzimuthRad,
  double radiusPerpendicularMeters,
  double radiusInclinedMeters,
  double radiusPerpendicularCanvas,
  double radiusInclinedCanvas,
  Rect localEllipseRect,
  })? _calculateEllipseMetrics(
      Offset Function(double x, double y) toCanvas,
      double scale,
      ) {
    final kpp = centerKppCoords;
    if (kpp == null) return null;

    final kppCenterCanvas = toCanvas(kpp.x, kpp.y);

    // 1. Get slope azimuth (azymut nachylenia) in degrees and convert to radians
    final double slopeAzimuthDeg = (powierzchnia.azymutNachylenia).toDouble();
    final double slopeAzimuthRad = slopeAzimuthDeg * (math.pi / 180.0); // <-- Fixed operator

    // 2. Radii in meters:
    // Short radius (perpendicular) is fixed at realRadius (11.28 m)
    // Long radius (parallel to slope) is read directly from powierzchnia.maxRadius
    final double radiusPerpendicularMeters = realRadius;
    final double radiusInclinedMeters =
    powierzchnia.maxRadius > 0 ? powierzchnia.maxRadius : realRadius;

    // 3. Convert radii to canvas units
    final double radiusPerpendicularCanvas = radiusPerpendicularMeters * scale; // <-- Fixed operator
    final double radiusInclinedCanvas = radiusInclinedMeters * scale; // <-- Fixed operator

    // 4. Create the bounding rectangle for the ellipse (centered at 0,0 for rotated canvas)
    final Rect localEllipseRect = Rect.fromCenter(
      center: Offset.zero,
      width: radiusPerpendicularCanvas * 2, // <-- Fixed operator
      height: radiusInclinedCanvas * 2, // <-- Fixed operator
    );

    return (
    kppCenterCanvas: kppCenterCanvas,
    slopeAzimuthDeg: slopeAzimuthDeg,
    slopeAzimuthRad: slopeAzimuthRad,
    radiusPerpendicularMeters: radiusPerpendicularMeters,
    radiusInclinedMeters: radiusInclinedMeters,
    radiusPerpendicularCanvas: radiusPerpendicularCanvas,
    radiusInclinedCanvas: radiusInclinedCanvas,
    localEllipseRect: localEllipseRect,
    );
  }

  /// Draws fallback plot and trees when geograficData is missing
  void drawFallback({
    required Canvas canvas,
    required Size size,
    required double zoom,
  }) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) * 0.8) / 2;
    final double meterToCanvasScale = radius / realRadius;

    final circlePaint = Paint()
      ..color = Colors.green.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 / zoom;

    final crossPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 / zoom;

    canvas.drawCircle(center, radius, circlePaint);

    final double crossSize = 12.0 / zoom;
    canvas.drawLine(
      Offset(center.dx - crossSize, center.dy), // <-- Fixed operator
      Offset(center.dx + crossSize, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - crossSize), // <-- Fixed operator
      Offset(center.dx, center.dy + crossSize),
      crossPaint,
    );

    TreesSketch.drawTrees(
      canvas: canvas,
      drzewa: drzewa, // <-- Correctly uses the passed list
      centerCanvas: center,
      meterToCanvasScale: meterToCanvasScale,
      zoom: zoom,
      treeDiameterScaleFactor: treeDiameterScaleFactor,
    );
  }
}