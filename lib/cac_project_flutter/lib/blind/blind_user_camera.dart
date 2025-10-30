// lib/blind/blind_user_camera_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as imglib;

// LiveKit + WebRTC (aliased to avoid name clashes)
import 'package:livekit_client/livekit_client.dart' as lk;

enum _StreamMode { yolo, armed, live }

class BlindCameraPage extends StatefulWidget {
  const BlindCameraPage({
    super.key,
    this.preset = ResolutionPreset.high,
    this.targetHz = 3, // frames per second
    required this.livekitUrl,        // e.g. wss://pathguide.livekit.cloud
    required this.navigatorToken,    // short-lived token for Navigator
  });

  final ResolutionPreset preset;
  final int targetHz;

  final String livekitUrl;
  final String navigatorToken;

  @override
  State<BlindCameraPage> createState() => _BlindCameraPageState();
}

class _BlindCameraPageState extends State<BlindCameraPage>
    with WidgetsBindingObserver {
  // --- your original fields ---
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _initializing = true;
  String? _error;

  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;

  bool _showOverlay = true;
  Size _imageSize = const Size(0, 0);
  List<Map<String, dynamic>> _detections = [];

  bool _running = false;
  int _lastInferMs = 0;
  late int _intervalMs;

  // --- LiveKit (updated) ---
  final lk.Room _room =
      lk.Room(connectOptions: const lk.ConnectOptions(autoSubscribe: true));
  lk.LocalVideoTrack? _liveTrack;
  lk.EventsListener<lk.RoomEvent>? _roomSub; // <-- correct type
  _StreamMode _mode = _StreamMode.yolo;
  Timer? _noGuardianTimer;

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

    // LiveKit cleanup
    _noGuardianTimer?.cancel();
    _roomSub?.dispose(); // <-- dispose EventsListener
    _roomSub = null;
    if (_mode == _StreamMode.live) {
      _room.localParticipant?.unpublishAllTracks();
      _liveTrack?.disable();
      _liveTrack?.dispose();
      _liveTrack = null;
    }
    _room.dispose();

    // your cleanup
    _stopStream();
    _disposeController();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (_mode == _StreamMode.live) return; // LiveKit owns camera
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

    try {
      // camera setup (unchanged)
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

      final controller = CameraController(
        cam,
        widget.preset,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);

      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = await controller.getMaxZoomLevel();
      _currentZoom = _minZoom;
      await controller.setZoomLevel(_currentZoom);

      setState(() {
        _controller = controller;
        _initializing = false;
      });

      // start your YOLO stream
      _startStream();

      // connect to LiveKit in "armed" mode
      _armGuardian();
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

  // --- your YUV→RGB + HTTP YOLO code (unchanged) ---
  Uint8List _yuv420toRgb(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final out = Uint8List(width * height * 3);
    int outIndex = 0;
    for (int y = 0; y < height; y++) {
      final uvRow = (y >> 1) * uPlane.bytesPerRow;
      for (int x = 0; x < width; x++) {
        final yIndex = y * yPlane.bytesPerRow + x;
        final uvIndex = uvRow + (x >> 1) * uPlane.bytesPerPixel!;
        final Y = yPlane.bytes[yIndex].toDouble();
        final U = uPlane.bytes[uvIndex].toDouble();
        final V = vPlane.bytes[uvIndex].toDouble();
        final R = (Y + 1.402 * (V - 128)).clamp(0, 255).toInt();
        final G =
            (Y - 0.344136 * (U - 128) - 0.714136 * (V - 128)).clamp(0, 255).toInt();
        final B = (Y + 1.772 * (U - 128)).clamp(0, 255).toInt();
        out[outIndex++] = R;
        out[outIndex++] = G;
        out[outIndex++] = B;
      }
    }
    return out;
  }

  Future<void> _sendFrame(CameraImage img) async {
    try {
      final rgbBytes = _yuv420toRgb(img);
      final imglib.Image converted = imglib.Image.fromBytes(
        width: img.width,
        height: img.height,
        bytes: rgbBytes.buffer,
        numChannels: 3,
      );
      final jpg = imglib.encodeJpg(converted, quality: 70);
      final uri = Uri.parse("http://10.0.2.2:8000/predict");
      final request = http.MultipartRequest("POST", uri)
        ..files.add(
            http.MultipartFile.fromBytes("file", jpg, filename: "frame.jpg"))
        ..fields["conf"] = "0.4";
      final response = await request.send();
      final body = await response.stream.bytesToString();
      final data = json.decode(body);
      if (mounted) {
        setState(() {
          _detections = List<Map<String, dynamic>>.from(data["detections"]);
        });
      }
    } catch (e) {
      debugPrint("Send frame error: $e");
    }
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
        _lastInferMs = now;
        await _sendFrame(img);
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

  // ---------------- LiveKit ----------------

  void _armGuardian() async {
    if (_room.connectionState == lk.ConnectionState.connected) {
      _mode = (_mode == _StreamMode.live) ? _StreamMode.live : _StreamMode.armed;
      setState(() {});
      _maybeEnterLive();
      return;
    }
    try {
      await _room.connect(widget.livekitUrl, widget.navigatorToken);
      _roomSub ??= _room.createListener()
        ..on<lk.ParticipantConnectedEvent>((_) => _maybeEnterLive())
        ..on<lk.ParticipantDisconnectedEvent>((_) => _handleNoGuardianSoon())
        ..on<lk.RoomDisconnectedEvent>((_) => _handleNoGuardianSoon());
      _mode = _StreamMode.armed;
      setState(() {});
      _maybeEnterLive();
    } catch (e) {
      debugPrint('LiveKit connect failed: $e');
    }
  }

  bool _guardianPresent() {
    if (_room.remoteParticipants.isEmpty) return false;
    for (final p in _room.remoteParticipants.values) {
      final m = p.metadata;
      if (m != null && m.contains('role=guardian')) return true;
    }
    return true; // fallback: any remote participant
  }

  Future<void> _maybeEnterLive() async {
    if (_mode == _StreamMode.live || !_guardianPresent()) return;

    // Release app camera before LiveKit grabs it
    _stopStream();
    await _controller?.pausePreview();
    _disposeController();

    try {
      _liveTrack = await lk.LocalVideoTrack.createCameraTrack(
  const lk.CameraCaptureOptions(
    cameraPosition: lk.CameraPosition.back,
    params: lk.VideoParametersPresets.h540_169,
  ),
);
await _room.localParticipant?.publishVideoTrack(
  _liveTrack!,
  publishOptions: const lk.VideoPublishOptions(name: 'navigator-camera'),
);

      _mode = _StreamMode.live;
      setState(() {});
    } catch (e) {
      debugPrint('enter LIVE failed: $e');
      await _exitLiveResumeYolo();
    }
  }

  void _handleNoGuardianSoon() {
    _noGuardianTimer?.cancel();
    _noGuardianTimer = Timer(const Duration(seconds: 3), () {
      if (!_guardianPresent() && _mode == _StreamMode.live) {
        _exitLiveResumeYolo();
      }
    });
  }

  Future<void> _exitLiveResumeYolo() async {
    try {
      await _room.localParticipant?.unpublishAllTracks();
    } catch (_) {}
    await _liveTrack?.disable();
    await _liveTrack?.dispose();
    _liveTrack = null;

    // Recreate original camera + YOLO
    await _init();
    _mode = _StreamMode.armed;
    setState(() {});
  }

  // ---- UI helpers ----

  Widget _zoomSlider() {
    if (_mode == _StreamMode.live) return const SizedBox.shrink(); // no controller when LIVE
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return const SizedBox.shrink();
    if ((_maxZoom - _minZoom).abs() < 1e-6) return const SizedBox.shrink();
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
    // When LIVE, render LiveKit's local track preview
    if (_mode == _StreamMode.live) {
      final t = _liveTrack;
      return Stack(
        fit: StackFit.expand,
        children: [
          if (t != null)
lk.VideoTrackRenderer(
  t,
  fit: lk.VideoViewFit.cover,
)

          else
            const Center(child: CircularProgressIndicator()),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.red, borderRadius: BorderRadius.circular(10)),
              child: const Text('LIVE',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }

    // original preview + overlay
    final ctrl = _controller!;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            AspectRatio(
              aspectRatio: ctrl.value.aspectRatio,
              child: CameraPreview(ctrl),
            ),
            if (_showOverlay)
              CustomPaint(
                painter: _DetectionPainter(_detections, constraints.biggest),
              ),
            if (_mode == _StreamMode.armed)
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Text('Guardian armed…',
                      style: TextStyle(color: Colors.white70)),
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
      floatingActionButton: (_mode == _StreamMode.live)
          ? null
          : FloatingActionButton(
              onPressed: () => setState(() => _showOverlay = !_showOverlay),
              tooltip: _showOverlay ? 'Hide overlay' : 'Show overlay',
              child:
                  Icon(_showOverlay ? Icons.visibility : Icons.visibility_off),
            ),
      bottomNavigationBar:
          (_mode == _StreamMode.live) ? null : SafeArea(child: _zoomSlider()),
    );
  }
}

// your painter (unchanged)
class _DetectionPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final Size canvasSize;
  _DetectionPainter(this.detections, this.canvasSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (final det in detections) {
      final List bbox = det["bbox"];
      final String label =
          "${det["class"]} ${(det["score"] as double).toStringAsFixed(2)}";
      final rect = Rect.fromLTRB(
        bbox[0].toDouble(),
        bbox[1].toDouble(),
        bbox[2].toDouble(),
        bbox[3].toDouble(),
      );
      canvas.drawRect(rect, paint);
      textPainter.text = const TextSpan(
          text: '', style: TextStyle(color: Colors.white, fontSize: 14));
      textPainter.text =
          TextSpan(text: label, style: const TextStyle(color: Colors.white, fontSize: 14));
      textPainter.layout();
      textPainter.paint(canvas, rect.topLeft);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
