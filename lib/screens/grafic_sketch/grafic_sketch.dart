import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lesna_app_1/screens/grafic_sketch/pow_sketch.dart';
import 'package:lesna_app_1/screens/grafic_sketch/trees_sketch.dart';
import 'package:lesna_app_1/screens/grafic_sketch/wydz_sketch.dart';
import 'package:lesna_app_1/screens/powierzchnia_screen/pomiar_wysokosci.dart';
import 'package:lesna_app_1/screens/powierzchnia_screen/powierzchnia_model.dart';

import '../powierzchnia_screen/drzewo_dialog.dart';
import '../powierzchnia_screen/powierzchnia_details.dart';

class GraficSketchScreen extends StatefulWidget {
  final PowierzchniaModel powierzchnia;
  final WydzielenieModel? wydzData;
  final String typDrzewa;
  final String selectedWarstwa;
  final bool isWysokoscPomiarActive;
  final String defaultGatunekWysokosc;
  final int defaultWiekWysokosc;
  final VoidCallback? onUpdate;

  const GraficSketchScreen({
    Key? key,
    required this.powierzchnia,
    this.wydzData,
    required this.typDrzewa,
    required this.selectedWarstwa,
    required this.isWysokoscPomiarActive,
    required this.defaultGatunekWysokosc,
    required this.defaultWiekWysokosc,
    this.onUpdate,
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

  /// Dynamically prepares the list of trees to display on the sketch
  List<DrzewoModel> _getTreesForSketch() {
    final pomiarManager = PomiarWysokosci(powierzchnia: widget.powierzchnia);

    // 1. Get the primary filtered trees (e.g., 'zywe')
    final List<DrzewoModel> mainTrees = pomiarManager.getPreparedTreesForBuilder(
      allTrees: widget.powierzchnia.drzewa,
      typDrzewa: widget.typDrzewa,
      selectedWarstwa: widget.selectedWarstwa,
      isWysokoscPomiarActive: widget.isWysokoscPomiarActive,
      defaultGatunekWysokosc: widget.defaultGatunekWysokosc,
      defaultWiekWysokosc: widget.defaultWiekWysokosc,
    );

    // 2. If 'zywe' is passed, also include 'gwozdz' so nails stay visible on the sketch
    if (widget.typDrzewa == 'zywe') {
      final List<DrzewoModel> gwozdzie = pomiarManager.getPreparedTreesForBuilder(
        allTrees: widget.powierzchnia.drzewa,
        typDrzewa: 'gwozdz',
        selectedWarstwa: widget.selectedWarstwa,
        isWysokoscPomiarActive: widget.isWysokoscPomiarActive,
        defaultGatunekWysokosc: widget.defaultGatunekWysokosc,
        defaultWiekWysokosc: widget.defaultWiekWysokosc,
      );
      return [...mainTrees, ...gwozdzie];
    }

    return mainTrees;
  }

  @override
  Widget build(BuildContext context) {
    // Re-evaluated automatically on every setState()!
    final List<DrzewoModel> currentTrees = _getTreesForSketch();

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
                _zoomToPowierzchnia(_lastCanvasSize!, currentTrees);
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
                _zoomToPowierzchnia(canvasSize, currentTrees);
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

                if (_plotCenterCanvas != null && _plotScale != null) {
                  final currentZoom = _transformController.value.getMaxScaleOnAxis();

                  final tappedTree = TreesSketch.findTappedTree(
                    tapCanvasPosition: tapPosition,
                    drzewa: currentTrees, // <-- Uses fresh list
                    centerCanvas: _plotCenterCanvas!,
                    meterToCanvasScale: _plotScale!,
                    zoom: currentZoom,
                    treeDiameterScaleFactor: 1.0,
                  );

                  if (tappedTree != null) {
                    final int globalIndex = widget.powierzchnia.drzewa.indexOf(tappedTree);
                    if (globalIndex >= 0) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) {
                          return DrzewoDialog(
                            powierzchnia: widget.powierzchnia,
                            maxRadiusSurface: widget.powierzchnia.maxRadius > 0 ? widget.powierzchnia.maxRadius : 11.28,
                            initialMode: DialogMode.edit,
                            initialGlobalIndex: globalIndex,
                            existingTree: tappedTree,
                            selectedWarstwa: tappedTree.warstwa.toString(),
                            initialDynamicGatunki: widget.powierzchnia.gatunki,
                            onUpdate: () {
                              setState(() {});
                              widget.onUpdate?.call();
                            },
                          );
                        },
                      ).then((_) {
                        setState(() {});
                      });
                    }
                  }
                }
              },
              child: CustomPaint(
                size: canvasSize,
                painter: PlotPainter(
                  powierzchnia: widget.powierzchnia,
                  wydzData: widget.wydzData,
                  drzewa: currentTrees, // <-- Passes fresh list to painter
                  transformController: _transformController,
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

  void _zoomToPowierzchnia(Size canvasSize, List<DrzewoModel> currentTrees) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return;
    _lastCanvasSize = canvasSize;

    final powSketch = PowierzchnieSketch(
      powierzchnia: widget.powierzchnia,
      wydzData: widget.wydzData,
      drzewa: currentTrees,
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

    final double targetRadius = (math.min(canvasSize.width, canvasSize.height) * 0.85) / 2.0;
    final double desiredZoom = (targetRadius / kppRadiusCanvas).clamp(0.01, 10000.0);

    final double tx = (canvasSize.width / 2.0) - (desiredZoom * kppCanvasX);
    final double ty = (canvasSize.height / 2.0) - (desiredZoom * kppCanvasY);

    _transformController.value = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(desiredZoom);
  }

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
}

class PlotPainter extends CustomPainter {
  final PowierzchniaModel powierzchnia;
  final WydzielenieModel? wydzData;
  final List<DrzewoModel> drzewa;
  final TransformationController transformController;
  final WydzielenieSketch _wydzSketch;
  final PowierzchnieSketch _powSketch;

  final void Function(
      Offset centerCanvas,
      double scale,
      double centerX,
      double centerY,
      )? onMetricsCalculated;

  PlotPainter({
    required this.powierzchnia,
    this.wydzData,
    required this.drzewa,
    required this.transformController,
    this.onMetricsCalculated,
  })  : _wydzSketch = WydzielenieSketch(wydzData: wydzData),
        _powSketch = PowierzchnieSketch(
          powierzchnia: powierzchnia,
          wydzData: wydzData,
          drzewa: drzewa,
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

    if (onMetricsCalculated != null) {
      final kpp = _powSketch.centerKppCoords;
      if (kpp != null) {
        final Offset kppCenterCanvas = toCanvas(kpp.x, kpp.y);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          onMetricsCalculated!(kppCenterCanvas, scale, centerX, centerY);
        });
      }
    }

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