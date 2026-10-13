import 'dart:ui' show Offset;

/// Abstracts the device camera hardware away from [CameraCubit], so zoom
/// clamping and batch logic can be unit tested against a fake without a
/// platform channel. The real implementation wraps the `camera` package's
/// `CameraController` (wired up alongside the preview screen, since both
/// need the same controller instance).
abstract class CameraHardwareController {
  Future<void> initialize();

  double get minZoomLevel;
  double get maxZoomLevel;

  Future<void> setZoomLevel(double zoom);
  Future<void> setFocusPoint(Offset point);

  /// Captures a still image and returns its saved file path.
  Future<String> takePicture();

  Future<void> dispose();
}
