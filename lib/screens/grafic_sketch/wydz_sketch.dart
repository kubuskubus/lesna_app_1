import 'package:flutter/material.dart';
import 'package:lesna_app_1/screens/powierzchnia_screen/powierzchnia_model.dart';

class WydzielenieSketch {
  final WydzielenieModel? wydzData;

  const WydzielenieSketch({this.wydzData});

  List<dynamic>? get _wydzCoordinList {
    final geoData = wydzData?.geograficData;
    if (geoData == null) return null;
    return geoData['wydz_coordin'] as List<dynamic>?;
  }

  void expandBounds(void Function(double x, double y) onPoint) {
    final coordList = _wydzCoordinList;
    if (coordList == null) return;

    for (final wydzItem in coordList) {
      if (wydzItem is Map) {
        final dartCoords = wydzItem['dart_coordinates'] as List?;
        if (dartCoords != null) {
          for (final ring in dartCoords) {
            if (ring is List) {
              for (final pt in ring) {
                if (pt is Map) {
                  final px = (pt['x'] as num?)?.toDouble();
                  final py = (pt['y'] as num?)?.toDouble();
                  if (px != null && py != null) {
                    onPoint(px, py);
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  void draw({
    required Canvas canvas,
    required Offset Function(double x, double y) toCanvas,
    required double zoom,
  }) {
    final coordList = _wydzCoordinList;
    if (coordList == null) return;

    final polyFillPaint = Paint()
      ..color = Colors.amber.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    final polyStrokePaint = Paint()
      ..color = Colors.brown.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 / zoom;

    // CHANGED: Use a standard for loop to access the index 'i'
    for (int i = 0; i < coordList.length; i++) {
      final wydzItem = coordList[i];
      if (wydzItem is Map) {

        // CHANGED: Fetch the address for the specific index from the adressLes list
        String currentAdressLes = '';
        if (wydzData != null && wydzData!.adressLes.isNotEmpty) {
          if (i < wydzData!.adressLes.length) {
            currentAdressLes = wydzData!.adressLes[i];
          } else {
            // Fallback: if there are fewer addresses than coordinates for some reason, use the last one
            currentAdressLes = wydzData!.adressLes.last;
          }
        }

        final dartCoords = wydzItem['dart_coordinates'] as List?;

        if (dartCoords != null) {
          for (final ring in dartCoords) {
            if (ring is List && ring.isNotEmpty) {
              _drawPolygonRing(
                ring: ring,
                adressLes: currentAdressLes, // <-- CHANGED: Pass the address instead of arodesNum
                canvas: canvas,
                toCanvas: toCanvas,
                zoom: zoom,
                fillPaint: polyFillPaint,
                strokePaint: polyStrokePaint,
              );
            }
          }
        }
      }
    }
  }

  /// Extracted void helper that processes the ring loop, draws the path, and paints the label
  void _drawPolygonRing({
    required List<dynamic> ring,
    required String adressLes, // <-- CHANGED: Updated variable name
    required Canvas canvas,
    required Offset Function(double x, double y) toCanvas,
    required double zoom,
    required Paint fillPaint,
    required Paint strokePaint,
  }) {
    final path = Path();
    double sumX = 0;
    double sumY = 0;
    int count = 0;

    final firstX = (ring[0]['x'] as num).toDouble();
    final firstY = (ring[0]['y'] as num).toDouble();

    for (int i = 0; i < ring.length; i++) {
      final pt = ring[i];
      if (pt is Map) {
        final px = (pt['x'] as num).toDouble();
        final py = (pt['y'] as num).toDouble();
        final canvasPt = toCanvas(px, py);

        if (i == 0) {
          path.moveTo(canvasPt.dx, canvasPt.dy);
        } else {
          path.lineTo(canvasPt.dx, canvasPt.dy);
        }

        if (i < ring.length - 1 || (px != firstX || py != firstY)) {
          sumX += px;
          sumY += py;
          count++;
        }
      }
    }
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    // CHANGED: Use adressLes instead of arodesNum
    if (count > 0 && adressLes.isNotEmpty) {
      final centroidCanvas = toCanvas(sumX / count, sumY / count);
      final wydzTextPainter = TextPainter(
        text: TextSpan(
          text: adressLes,
          style: TextStyle(
            color: Colors.brown.shade900,
            fontSize: 13.0, // <-- CHANGED: Removed "/ zoom" to keep text crisp
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.white.withOpacity(0.75),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // CHANGED: Added scaling to prevent text blurriness when zooming in
      canvas.save();
      canvas.translate(
        centroidCanvas.dx - (wydzTextPainter.width / zoom / 2),
        centroidCanvas.dy - (wydzTextPainter.height / zoom / 2),
      );
      canvas.scale(1.0 / zoom);
      wydzTextPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }
}