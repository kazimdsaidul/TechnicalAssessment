import 'dart:ui' show Offset;

import 'package:equatable/equatable.dart';

sealed class CameraState extends Equatable {
  const CameraState();

  @override
  List<Object?> get props => [];
}

class CameraInitializing extends CameraState {
  const CameraInitializing();
}

class CameraError extends CameraState {
  const CameraError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// The steady state once the camera is live. Zoom, focus, in-progress
/// capture, and the current batch's image count all need to be visible on
/// screen at once (per the camera-capture spec), so they live together on
/// one state rather than as separate mutually-exclusive states.
class CameraReady extends CameraState {
  const CameraReady({
    required this.zoomLevel,
    required this.minZoom,
    required this.maxZoom,
    this.focusPoint,
    this.batchImageCount = 0,
    this.isCapturing = false,
  });

  final double zoomLevel;
  final double minZoom;
  final double maxZoom;
  final Offset? focusPoint;
  final int batchImageCount;
  final bool isCapturing;

  CameraReady copyWith({
    double? zoomLevel,
    Offset? focusPoint,
    bool clearFocusPoint = false,
    int? batchImageCount,
    bool? isCapturing,
  }) {
    return CameraReady(
      zoomLevel: zoomLevel ?? this.zoomLevel,
      minZoom: minZoom,
      maxZoom: maxZoom,
      focusPoint: clearFocusPoint ? null : (focusPoint ?? this.focusPoint),
      batchImageCount: batchImageCount ?? this.batchImageCount,
      isCapturing: isCapturing ?? this.isCapturing,
    );
  }

  @override
  List<Object?> get props => [
        zoomLevel,
        minZoom,
        maxZoom,
        focusPoint,
        batchImageCount,
        isCapturing,
      ];
}
