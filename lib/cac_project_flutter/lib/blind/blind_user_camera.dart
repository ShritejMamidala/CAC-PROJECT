// lib/blind/blind_user_camera_page.dart
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation; // <-- needed
import 'package:permission_handler/permission_handler.dart';

import 'package:cac_project_flutter/services/yolo_tflite_service.dart';
import 'package:cac_project_flutter/services/perception_hub.dart';
import 'package:cac_project_flutter/perception/overlay_painter.dart';

class BlindCameraPage extends StatefulWidget {
  const BlindCameraPage({
    super.key,
    this.preset = ResolutionPreset.veryHigh,
    this.targetHz = 3, // YOLO calls per second (demo friendly)
  });

  final ResolutionPreset preset;
  final int targetHz;

  @override
  State<BlindCameraPage> createState() => _BlindCameraPageState();
}

class _BlindCameraPageState extends State<BlindCameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _initializing = true;
  String? _error;

  // Zoom state
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  double _baseZoomOnScaleStart = 1.0;

  // YOLO + Hub + Overlay
  YoloTfliteService? _yolo;
  bool _showOverlay = true;
  List<Detection> _latestDets = const [];
  Size _imageSize = const Size(0, 0); // camera IMAGE space (w,h)

  // Throttle
  bool _running = false;
  int _lastInferMs = 0;
  late int _intervalMs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _intervalMs = (1000 / widget.targetHz).round();
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopStream();
    _disposeController(); // <-- back in
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (ctrl == null) return;

    if (state == AppLifecycleState.resumed) {
      _reinit();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopStream();
      unawaited(ctrl.pausePreview());
    }
  }

  Future<void> _reinit() async {
    _stopStream();
    _disposeController();
    await _init();
  }

  Future<void> _init() async {
    setState(() {
      _initializing = true;
      _error = null;
    });

    // 1) Camera permission
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _initializing = false;
        _error = 'Camera permission not granted';
      });
      return;
    }

    try {
      // 2) Choose camera
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _initializing = false;
          _error = 'No cameras available';
        });
        return;
      }
      final cam = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      // 3) Controller
      final controller = CameraController(
        cam,
        widget.preset,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);

      // 4) Zoom
      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = await controller.getMaxZoomLevel();
      _currentZoom = _minZoom;
      await controller.setZoomLevel(_currentZoom);

      // 5) YOLO once
      _yolo ??= await YoloTfliteService.load();

      setState(() {
        _controller = controller;
        _initializing = false;
      });

      // 6) Stream
      _startStream();
    } catch (e) {
      setState(() {
        _initializing = false;
        _error = 'Camera init error: $e';
      });
    }
  }

  void _disposeController() {
    final ctrl = _controller;
    _controller = null;
    ctrl?.dispose();
  }

  void _startStream() {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (ctrl.value.isStreamingImages) return;

    ctrl.startImageStream((CameraImage img) async {
      _imageSize = Size(img.width.toDouble(), img.height.toDouble());

      final now = DateTime.now().millisecondsSinceEpoch;
      if (_running || (now - _lastInferMs) < _intervalMs) return;

      _running = true;
      try {
        final svc = _yolo;
        if (svc == null) return;

        final deviceRotationDeg =
            _deviceOrientationToDegrees(ctrl.value.deviceOrientation);
        final sensorOrientationDeg = ctrl.description.sensorOrientation;

        final dets = await svc.detectFromCameraImage(
          img,
          sensorOrientationDeg: sensorOrientationDeg,
          deviceRotationDeg: deviceRotationDeg,
          scoreThresh: 0.45,
          iouThresh: 0.50,
        );

        // Publish
        PerceptionHub.I.publish(PerceptionEvent(
          source: 'yolo',
          t: DateTime.now(),
          space: 'image',
          frameSize: _imageSize,
          items: dets,
          meta: {
            'lens': ctrl.description.lensDirection.name,
            'rotation_device_deg': deviceRotationDeg,
            'sensor_deg': sensorOrientationDeg,
          },
        ));

        if (_showOverlay) {
          setState(() => _latestDets = dets);
        }

        _lastInferMs = now;
      } catch (e) {
        debugPrint('Inference error: $e');
      } finally {
        _running = false;
      }
    });
  }

  void _stopStream() {
    final ctrl = _controller;
    if (ctrl == null) return;
    if (ctrl.value.isStreamingImages) {
      ctrl.stopImageStream();
    }
  }

  int _deviceOrientationToDegrees(DeviceOrientation? o) {
    switch (o) {
      case DeviceOrientation.landscapeLeft:
        return 90;
      case DeviceOrientation.portraitDown:
        return 180;
      case DeviceOrientation.landscapeRight:
        return 270;
      case DeviceOrientation.portraitUp:
      case null:
      default:
        return 0;
    }
  }

  // ---- UI helpers ----

  Widget _zoomSlider() {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return const SizedBox.shrink();
    }
    if ((_maxZoom - _minZoom).abs() < 1e-6) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          const Icon(Icons.zoom_out),
          Expanded(
            child: Slider(
              min: _minZoom,
              max: _maxZoom,
              value: _currentZoom.clamp(_minZoom, _maxZoom),
              onChanged: (v) async {
                setState(() => _currentZoom = v);
                await _controller?.setZoomLevel(v);
              },
            ),
          ),
          const Icon(Icons.zoom_in),
        ],
      ),
    );
  }

  Widget _previewWithOverlay() {
    final ctrl = _controller!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          fit: StackFit.expand,
          children: [
            AspectRatio(
              aspectRatio: ctrl.value.aspectRatio,
              child: CameraPreview(ctrl),
            ),
            if (_showOverlay && _imageSize.width > 0 && _imageSize.height > 0)
              CustomPaint(
                painter: YoloOverlayPainter(
                  detections: _latestDets,
                  previewSize: _imageSize,
                  viewportSize: viewSize,
                  mirror: ctrl.description.lensDirection ==
                      CameraLensDirection.front,
                  showLabels: true,
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: _init,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: _previewWithOverlay()),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _showOverlay = !_showOverlay),
        tooltip: _showOverlay ? 'Hide overlay' : 'Show overlay',
        child: Icon(_showOverlay ? Icons.visibility : Icons.visibility_off),
      ),
      bottomNavigationBar: SafeArea(child: _zoomSlider()),
    );
  }
}
