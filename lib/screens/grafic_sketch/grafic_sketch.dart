import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lesna_app_1/screens/grafic_sketch/pow_sketch.dart';
import 'package:lesna_app_1/screens/grafic_sketch/trees_sketch.dart';
import 'package:lesna_app_1/screens/grafic_sketch/wydz_sketch.dart';
import 'package:lesna_app_1/screens/powierzchnia_screen/powierzchnia_model.dart';

import '../powierzchnia_screen/drzewo_dialog.dart';
import '../powierzchnia_screen/powierzchnia_details.dart';

class GraficSketchScreen extends StatefulWidget {
  final PowierzchniaModel powierzchnia;
  final WydzielenieModel? wydzData;

  const GraficSketchScreen({
    Key? key,
    required this.powierzchnia,
    this.wydzData,
  }) : super(key: key);

  @override
  State<GraficSketchScreen> createState() => _GraficSketchScreenState();
}

class _GraficSketchScreenState extends State<GraficSketchScreen> {
  final TransformationController _transformController = TransformationController();
  bool _hasInitialZoomBeenSet = false;
  Size? _lastCanvasSize;
  Offset? _plotCenterCanvas;
  double? _plotScale;
  double? _geoCenterX;
  double? _geoCenterY;



  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Szkic Powierzchni'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'Wyśrodkuj na powierzchnię',
            onPressed: () {
              if (_lastCanvasSize != null) {
                _zoomToPowierzchnia(_lastCanvasSize!);
              } else {
                _transformController.value = Matrix4.identity();
              }
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

          if (!_hasInitialZoomBeenSet &&
              canvasSize.width > 0 &&
              canvasSize.height > 0) {
            _hasInitialZoomBeenSet = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _zoomToPowierzchnia(canvasSize);
              }
            });
          }

          return InteractiveViewer(
            transformationController: _transformController,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.01,
            maxScale: 10000.0,
            child: GestureDetector(
              onTapUp: (TapUpDetails details) {
                final tapPosition = details.localPosition;

                // 1. Convert tap pixel position to real-world global geographic coordinates (x, y)
                final Offset? tappedGeoCoords = canvasToGlobalCoords(
                  tapCanvasPosition: tapPosition,
                  canvasSize: canvasSize,
                  scale: _plotScale,
                  centerX: _geoCenterX,
                  centerY: _geoCenterY,
                );

                if (tappedGeoCoords != null) {
                  print('Tapped Geographic Coordinates: X = ${tappedGeoCoords.dx}, Y = ${tappedGeoCoords.dy}');
                }

                // 2. Perform tree detection using the true sample plot center
                if (_plotCenterCanvas != null && _plotScale != null) {
                  final currentZoom = _transformController.value.getMaxScaleOnAxis();

                  final tappedTree = TreesSketch.findTappedTree(
                    tapCanvasPosition: tapPosition,
                    powierzchnia: widget.powierzchnia,
                    centerCanvas: _plotCenterCanvas!,
                    meterToCanvasScale: _plotScale!,
                    zoom: currentZoom,
                    treeDiameterScaleFactor: 1.0,
                  );

                  if (tappedTree != null) {
                    // Find the exact index of the tapped tree in the main list
                    final int globalIndex = widget.powierzchnia.drzewa.indexOf(tappedTree);
                    if (tappedTree != null) {
                      final int globalIndex = widget.powierzchnia.drzewa.indexOf(tappedTree);

                      if (globalIndex >= 0) {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return DrzewoDialog(
                              powierzchnia: widget.powierzchnia,
                              maxRadiusSurface: widget.powierzchnia.maxRadius > 0 ? widget.powierzchnia.maxRadius : 11.28,
                              initialMode: DialogMode.edit,
                              initialGlobalIndex: globalIndex,
                              existingTree: tappedTree,
                              // Use the existing tree's layer as the default selected layer
                              selectedWarstwa: tappedTree.warstwa.toString(),
                              initialDynamicGatunki: widget.powierzchnia.gatunki,
                              onUpdate: () {
                                setState(() {}); // Redraw the canvas with the updated tree
                                // Add your save logic here if needed (e.g., widget.onUpdate!())
                              },
                            );
                          },
                        );
                      }
                    }
                  }
                }
              },
              child: CustomPaint(
                size: canvasSize,
                painter: PlotPainter(
                  powierzchnia: widget.powierzchnia,
                  wydzData: widget.wydzData,
                  transformController: _transformController,
                  // 3. PASS THE CALLBACK HERE TO RECEIVE THE METRICS
                  onMetricsCalculated: (Offset centerCanvas, double scale, double centerX, double centerY) {
                    _plotCenterCanvas = centerCanvas;
                    _plotScale = scale;
                    _geoCenterX = centerX;
                    _geoCenterY = centerY;
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _zoomToPowierzchnia(Size canvasSize) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return;
    _lastCanvasSize = canvasSize;

    final powSketch = PowierzchnieSketch(
      powierzchnia: widget.powierzchnia,
      wydzData: widget.wydzData,
    );
    final wydzSketch = WydzielenieSketch(wydzData: widget.wydzData);

    final kpp = powSketch.centerKppCoords;
    if (kpp == null) {
      _transformController.value = Matrix4.identity();
      return;
    }

    const double realRadius = PowierzchnieSketch.realRadius;

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    void expandBounds(double px, double py) {
      if (px < minX) minX = px;
      if (px > maxX) maxX = px;
      if (py < minY) minY = py;
      if (py > maxY) maxY = py;
    }

    powSketch.expandBounds(expandBounds);
    wydzSketch.expandBounds(expandBounds);

    final double dataWidth = math.max(maxX - minX, 1.0);
    final double dataHeight = math.max(maxY - minY, 1.0);

    final double scaleX = (canvasSize.width * 0.9) / dataWidth;
    final double scaleY = (canvasSize.height * 0.9) / dataHeight;
    final double scale = math.min(scaleX, scaleY);

    final double centerX = (minX + maxX) / 2.0;
    final double centerY = (minY + maxY) / 2.0;

    final double kppCanvasX = canvasSize.width / 2.0 + (kpp.x - centerX) * scale;
    final double kppCanvasY = canvasSize.height / 2.0 - (kpp.y - centerY) * scale;
    final double kppRadiusCanvas = realRadius * scale;

    // Target radius on screen = 42.5% of shortest screen side (85% diameter)
// Target radius on screen = 42.5% of shortest screen side (85% diameter)
    final double targetRadius =
        (math.min(canvasSize.width, canvasSize.height) * 0.85) / 2.0;
    final double desiredZoom =
    (targetRadius / kppRadiusCanvas).clamp(0.01, 10000.0);

    final double tx = (canvasSize.width / 2.0) - (desiredZoom * kppCanvasX);
    final double ty = (canvasSize.height / 2.0) - (desiredZoom * kppCanvasY);

    _transformController.value = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(desiredZoom);
  }

  // 2. Helper method to invert canvas pixels back to global geographic coordinates
  Offset? canvasToGlobalCoords({
    required Offset tapCanvasPosition,
    required Size canvasSize,
    required double? scale,
    required double? centerX,
    required double? centerY,
  }) {
    if (scale == null || centerX == null || centerY == null) return null;

    final double geoX = centerX + (tapCanvasPosition.dx - (canvasSize.width / 2.0)) / scale;
    final double geoY = centerY - (tapCanvasPosition.dy - (canvasSize.height / 2.0)) / scale;

    return Offset(geoX, geoY);
  }



  // 2. ADD THIS DIALOG METHOD TO YOUR STATE CLASS
  void _showTreeWarstwaDialog(DrzewoModel drzewo) {
    final List<String> availableLayers = ['1', '2', '3', 'Brak'];

    // Directly access the 'warstwa' property. If it's empty, default to 'Brak'
    String currentLayer = drzewo.warstwa.isEmpty ? 'Brak' : drzewo.warstwa;
    if (!availableLayers.contains(currentLayer)) {
      currentLayer = 'Brak';
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                title: Text('Change layer for tree #${drzewo.numer}'),
                content: DropdownButton<String>(
                  isExpanded: true,
                  value: currentLayer,
                  items: availableLayers.map((String layer) {
                    return DropdownMenuItem<String>(
                      value: layer,
                      child: Text(layer == 'Brak' ? 'None' : 'Layer $layer'),
                    );
                  }).toList(),
                  onChanged: (String? newLayer) {
                    if (newLayer != null) {
                      setStateDialog(() {
                        currentLayer = newLayer;
                      });
                    }
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Trigger a rebuild of the widget tree and the CustomPainter
                      setState(() {
                        // Update the direct 'warstwa' property
                        drzewo.warstwa = currentLayer == 'Brak' ? '' : currentLayer;
                      });
                      Navigator.of(context).pop();
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            }
        );
      },
    );
  }
}

class PlotPainter extends CustomPainter {
  final PowierzchniaModel powierzchnia;
  final WydzielenieModel? wydzData;
  final TransformationController transformController;
  final WydzielenieSketch _wydzSketch;
  final PowierzchnieSketch _powSketch;

  // UPDATED: Now passes centerCanvas, scale, centerX, and centerY
  final void Function(
      Offset centerCanvas,
      double scale,
      double centerX,
      double centerY,
      )? onMetricsCalculated;

  PlotPainter({
    required this.powierzchnia,
    this.wydzData,
    required this.transformController,
    this.onMetricsCalculated,
  })  : _wydzSketch = WydzielenieSketch(wydzData: wydzData),
        _powSketch = PowierzchnieSketch(
          powierzchnia: powierzchnia,
          wydzData: wydzData,
        ),
        super(repaint: transformController);

  @override
  void paint(Canvas canvas, Size size) {
    final double zoom = transformController.value.getMaxScaleOnAxis();
    final geoData = wydzData?.geograficData;

    if (geoData == null) {
      _powSketch.drawFallback(canvas: canvas, size: size, zoom: zoom);
      return;
    }

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    void expandBounds(double x, double y) {
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    _powSketch.expandBounds(expandBounds);
    _wydzSketch.expandBounds(expandBounds);

    if (minX == double.infinity) {
      _powSketch.drawFallback(canvas: canvas, size: size, zoom: zoom);
      return;
    }

    final double dataWidth = math.max(maxX - minX, 1.0);
    final double dataHeight = math.max(maxY - minY, 1.0);

    final double scaleX = (size.width * 0.9) / dataWidth;
    final double scaleY = (size.height * 0.9) / dataHeight;
    final double scale = math.min(scaleX, scaleY);

    final double centerX = (minX + maxX) / 2.0;
    final double centerY = (minY + maxY) / 2.0;

    Offset toCanvas(double x, double y) {
      final double cx = size.width / 2.0 + (x - centerX) * scale;
      final double cy = size.height / 2.0 - (y - centerY) * scale;
      return Offset(cx, cy);
    }

    // --- SEND ALL METRICS OUT VIA CALLBACK ---
    if (onMetricsCalculated != null) {
      final kpp = _powSketch.centerKppCoords;
      if (kpp != null) {
        final Offset kppCenterCanvas = toCanvas(kpp.x, kpp.y);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          onMetricsCalculated!(kppCenterCanvas, scale, centerX, centerY);
        });
      }
    }
    // -----------------------------------------

    _wydzSketch.draw(
      canvas: canvas,
      toCanvas: toCanvas,
      zoom: zoom,
    );

    _powSketch.drawPowElipse(
      canvas: canvas,
      toCanvas: toCanvas,
      scale: scale,
      zoom: zoom,
    );
  }

  @override
  bool shouldRepaint(covariant PlotPainter oldDelegate) {
    return true;
  }
}