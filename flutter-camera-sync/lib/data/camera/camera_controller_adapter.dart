import 'dart:ui' show Offset;

import 'package:camera/camera.dart';

import 'camera_hardware_controller.dart';

/// Wraps the `camera` package's [CameraController] behind
/// [CameraHardwareController], so `CameraCubit`'s zoom/focus/batch logic
/// never depends on it directly (see `camera_cubit_test.dart`, which mocks
/// the interface instead). The preview screen reaches into [controller]
/// separately to build the live preview widget, since rendering frames
/// isn't part of the cubit's testable logic.
class CameraControllerAdapter implements CameraHardwareController {
  CameraController? _controller;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;

  CameraController get controller {
    final controller = _controller;
    if (controller == null) {
      throw StateError('CameraControllerAdapter.initialize() must complete before use');
    }
    return controller;
  }

  @override
  Future<void> initialize() async {
    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(backCamera, ResolutionPreset.high, enableAudio: false);
    await controller.initialize();
    _controller = controller;

    _minZoom = await controller.getMinZoomLevel();
    _maxZoom = await controller.getMaxZoomLevel();
  }

  @override
  double get minZoomLevel => _minZoom;

  @override
  double get maxZoomLevel => _maxZoom;

  @override
  Future<void> setZoomLevel(double zoom) => controller.setZoomLevel(zoom);

  @override
  Future<void> setFocusPoint(Offset point) async {
    await controller.setFocusMode(FocusMode.auto);
    await controller.setFocusPoint(point);
  }

  @override
  Future<String> takePicture() async {
    final file = await controller.takePicture();
    return file.path;
  }

  @override
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
