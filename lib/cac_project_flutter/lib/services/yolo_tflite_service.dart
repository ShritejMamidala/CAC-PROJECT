import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart' show Rect, Size;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as imglib;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import 'perception_hub.dart';

class YoloTfliteService {
  YoloTfliteService._(this._interpreter, this._inputSize, this._isFloat, this._labels);

  final tfl.Interpreter _interpreter;
  final int _inputSize;     // assume square tensor (e.g., 640)
  final bool _isFloat;      // model input type
  final List<String> _labels;

  // --- Load model/labels ---
  static Future<YoloTfliteService> load({
    String modelAsset = 'assets/best_float16.tflite',
    String labelsAsset = 'assets/labels.txt',
    int threads = 2,
  }) async {
    final options = tfl.InterpreterOptions()..threads = threads;
    final interpreter = await tfl.Interpreter.fromAsset(modelAsset, options: options);

    final inputT = interpreter.getInputTensor(0);
    final inputShape = inputT.shape;                 // [1,H,W,3] or [1,3,H,W]
    final isFloat = inputT.type == tfl.TensorType.float32;


    final size = (inputShape.length == 4)
        ? (inputShape[1] == 3 ? inputShape[2] : inputShape[1])
        : 640;

    final labels = (await rootBundle.loadString(labelsAsset))
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return YoloTfliteService._(interpreter, size, isFloat, labels);
  }

  // --- Detect on YUV420 CameraImage (for startImageStream) ---
  Future<List<Detection>> detectFromCameraImage(
    CameraImage image, {
    required int sensorOrientationDeg,
    required int deviceRotationDeg,
    double scoreThresh = 0.45,
    double iouThresh = 0.50,
  }) async {
    // 1) YUV420 -> RGB image
    final rgb = _yuv420ToRgb(image);

    // 2) Normalize orientation so the net sees upright portrait
    final rotate = _computeNeededRotation(sensorOrientationDeg, deviceRotationDeg);
    final upr = rotate == 0 ? rgb : imglib.copyRotate(rgb, angle: rotate);

    final origW = upr.width, origH = upr.height;

    // 3) Letterbox to model input
    final boxed = _letterbox(upr, _inputSize);
    final inputTensor = _isFloat ? _toFloat32(boxed.img) : _toUint8(boxed.img);

    // 4) Inference (single input/output)
    final outShape = _interpreter.getOutputTensor(0).shape;
    final total = outShape.reduce((a, b) => a * b);
    final outBuf = _isFloat ? Float32List(total) : Uint8List(total);
    _interpreter.run(inputTensor, outBuf);

    final preds = outBuf is Float32List
        ? outBuf
        : Float32List.fromList((outBuf as Uint8List).map((e) => e.toDouble()).toList());

    // 5) Decode back to ORIGINAL image coords
    final dets = _decode(preds, outShape, origW, origH, boxed.scale, boxed.dx, boxed.dy);

    // 6) NMS
    return _nms(dets, iouThreshold: iouThresh, scoreThreshold: scoreThresh);
  }

  // --- YUV420 -> RGB (reference, readable) ---
  imglib.Image _yuv420ToRgb(CameraImage image) {
    assert(image.format.group == ImageFormatGroup.yuv420);
    final w = image.width, h = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    final out = imglib.Image(width: w, height: h);

    for (int y = 0; y < h; y++) {
      final yRow = y * yPlane.bytesPerRow;
      final uvRow = (y ~/ 2) * uvRowStride;
      for (int x = 0; x < w; x++) {
        final yIndex = yRow + x;
        final uvCol = (x ~/ 2) * uvPixelStride;
        final uIndex = uvRow + uvCol;
        final vIndex = uvRow + uvCol;

        final Y = yPlane.bytes[yIndex].toDouble();
        final U = uPlane.bytes[uIndex].toDouble();
        final V = vPlane.bytes[vIndex].toDouble();

        // BT.601
        double r = Y + 1.402 * (V - 128.0);
        double g = Y - 0.344136 * (U - 128.0) - 0.714136 * (V - 128.0);
        double b = Y + 1.772 * (U - 128.0);

        out.setPixelRgb(
          x, y,
          r.clamp(0.0, 255.0).toInt(),
          g.clamp(0.0, 255.0).toInt(),
          b.clamp(0.0, 255.0).toInt(),
        );
      }
    }
    return out;
  }

  // --- Letterbox to square input, remember scale & pad ---
_Boxed _letterbox(imglib.Image src, int size) {
  final ow = src.width, oh = src.height;
  final scale = math.min(size / ow, size / oh);
  final nw = (ow * scale).round();
  final nh = (oh * scale).round();

  final resized = imglib.copyResize(
    src,
    width: nw,
    height: nh,
    interpolation: imglib.Interpolation.linear,
  );

  final canvas = imglib.Image(width: size, height: size);
  // image ^4.x: fill expects a Color object
  imglib.fill(canvas, color: imglib.ColorRgb8(0, 0, 0));

  final dx = ((size - nw) / 2).round();
  final dy = ((size - nh) / 2).round();

  // image ^4.x: compositeImage uses a BlendMode enum
  imglib.compositeImage(
    canvas,
    resized,
    dstX: dx,
    dstY: dy,
    blend: imglib.BlendMode.direct, // paste without blending
  );

  return _Boxed(img: canvas, scale: scale, dx: dx.toDouble(), dy: dy.toDouble());
}

  // --- NHWC RGB tensors ---
  Uint8List _toUint8(imglib.Image img) {
    final rgba = img.getBytes(); // RGBA
    final out = Uint8List(_inputSize * _inputSize * 3);
    int j = 0;
    for (int i = 0; i < rgba.length; i += 4) {
      out[j++] = rgba[i];     // R
      out[j++] = rgba[i + 1]; // G
      out[j++] = rgba[i + 2]; // B
    }
    return out;
  }

  Float32List _toFloat32(imglib.Image img) {
    final rgba = img.getBytes();
    final out = Float32List(_inputSize * _inputSize * 3);
    int j = 0;
    for (int i = 0; i < rgba.length; i += 4) {
      out[j++] = rgba[i] / 255.0;
      out[j++] = rgba[i + 1] / 255.0;
      out[j++] = rgba[i + 2] / 255.0;
    }
    return out;
  }

  // --- Compute rotation for upright portrait tensor ---
  int _computeNeededRotation(int sensorOrientationDeg, int deviceRotationDeg) {
    final rot = (sensorOrientationDeg - deviceRotationDeg) % 360;
    return (rot + 360) % 360;
  }

  // --- Decode YOLOv8/v11-style outputs + NMS ---

  List<Detection> _decode(
    Float32List flat,
    List<int> outShape,
    int origW,
    int origH,
    double scale,
    double dx,
    double dy,
  ) {
    // Support [1, 8400, 84] or [1, 84, 8400]
    late final int boxes;
    late final int dims;

    if (outShape.length >= 3) {
      final a = outShape[1], b = outShape[2];
      if (a == 8400 || b == 8400) {
        if (a == 8400) { boxes = a; dims = b; }
        else { boxes = b; dims = a; }
      } else {
        boxes = b;
        dims = a;
      }
    } else {
      boxes = 8400;
      dims = (flat.length / boxes).round();
    }

    double at(int row, int col) {
      if (outShape[1] == boxes) return flat[row * dims + col];      // [1, boxes, dims]
      if (outShape[2] == boxes) return flat[col * dims + row];      // [1, dims, boxes]
      return flat[row * dims + col];
    }

    final out = <Detection>[];
    for (int i = 0; i < boxes; i++) {
      final x = at(i, 0), y = at(i, 1), w = at(i, 2), h = at(i, 3);
      final obj = dims > 4 ? at(i, 4) : 1.0;

      double best = 0; int bestIdx = 0;
      for (int c = 5; c < dims; c++) {
        final s = at(i, c);
        if (s > best) { best = s; bestIdx = c - 5; }
      }
      final conf = obj * best;
      if (conf < 0.20) continue;

      // xywh -> xyxy in letterboxed coords
      final left = x - w / 2, top = y - h / 2, right = x + w / 2, bottom = y + h / 2;

      // remove letterbox + unscale to ORIGINAL image coords
      final sx = (left - dx) / scale;
      final sy = (top - dy) / scale;
      final ex = (right - dx) / scale;
      final ey = (bottom - dy) / scale;

      final rect = Rect.fromLTRB(
        sx.clamp(0, origW.toDouble()),
        sy.clamp(0, origH.toDouble()),
        ex.clamp(0, origW.toDouble()),
        ey.clamp(0, origH.toDouble()),
      );

      final label = (bestIdx >= 0 && bestIdx < _labels.length) ? _labels[bestIdx] : 'obj';
      out.add(Detection(bbox: rect, score: conf, label: label));
    }
    return out;
  }

  List<Detection> _nms(
    List<Detection> dets, {
    double iouThreshold = 0.5,
    double scoreThreshold = 0.45,
  }) {
    final list = dets.where((d) => d.score >= scoreThreshold).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final keep = <Detection>[];

    while (list.isNotEmpty) {
      final a = list.removeAt(0);
      keep.add(a);
      list.removeWhere((b) => _iou(a.bbox, b.bbox) > iouThreshold && a.label == b.label);
    }
    return keep;
  }

  double _iou(Rect a, Rect b) {
    final x1 = math.max(a.left, b.left);
    final y1 = math.max(a.top, b.top);
    final x2 = math.min(a.right, b.right);
    final y2 = math.min(a.bottom, b.bottom);
    final inter = math.max(0.0, x2 - x1) * math.max(0.0, y2 - y1);
    final ua = a.width * a.height + b.width * b.height - inter;
    if (ua <= 0) return 0.0;
    return inter / ua;
  }
}

class _Boxed {
  final imglib.Image img;
  final double scale;
  final double dx, dy;
  _Boxed({required this.img, required this.scale, required this.dx, required this.dy});
}
