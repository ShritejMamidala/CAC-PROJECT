import 'dart:async';
import 'package:flutter/material.dart';

class Detection {
  final Rect bbox;        // IMAGE-space bbox (camera pixels)
  final double score;     // 0..1
  final String label;

  const Detection({required this.bbox, required this.score, required this.label});

  Offset get center => bbox.center;
}

class PerceptionEvent {
  final String source;        // "yolo"
  final DateTime t;
  final String space;         // "image"
  final Size frameSize;       // image width/height
  final List<Detection> items;
  final Map<String, dynamic>? meta; // rotation, lens, etc. (optional)

  const PerceptionEvent({
    required this.source,
    required this.t,
    required this.space,
    required this.frameSize,
    required this.items,
    this.meta,
  });
}

class PerceptionHub {
  PerceptionHub._();
  static final PerceptionHub I = PerceptionHub._();

  final _ctrl = StreamController<PerceptionEvent>.broadcast();
  Stream<PerceptionEvent> get stream => _ctrl.stream;

  void publish(PerceptionEvent e) {
    if (!_ctrl.isClosed) _ctrl.add(e);
  }

  void dispose() => _ctrl.close();
}
