import 'dart:ui' show Offset;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/camera/camera_hardware_controller.dart';
import '../../data/sync/upload_sync_coordinator.dart';
import '../../domain/model/captured_image.dart';
import '../../domain/repository/upload_queue_repository.dart';
import 'camera_state.dart';

class CameraCubit extends Cubit<CameraState> {
  CameraCubit({
    required this.hardware,
    required this.repository,
    required this.syncCoordinator,
  }) : super(const CameraInitializing());

  final CameraHardwareController hardware;
  final UploadQueueRepository repository;
  final UploadSyncCoordinator syncCoordinator;

  String? _currentBatchId;
  int _imageIdCounter = 0;

  Future<void> initialize() async {
    try {
      await hardware.initialize();
      final minZoom = hardware.minZoomLevel;
      emit(CameraReady(
        zoomLevel: minZoom > 1.0 ? minZoom : 1.0,
        minZoom: minZoom,
        maxZoom: hardware.maxZoomLevel,
      ));
    } catch (e) {
      emit(CameraError(e.toString()));
    }
  }

  Future<void> setZoomLevel(double requested) async {
    final current = state;
    if (current is! CameraReady) return;

    final clamped = _clamp(requested, current.minZoom, current.maxZoom);
    await hardware.setZoomLevel(clamped);
    emit(current.copyWith(zoomLevel: clamped));
  }

  /// Jumps to the nearest supported zoom for a 0.5x/1x/2x preset tap.
  Future<void> setZoomPreset(double preset) => setZoomLevel(preset);

  Future<void> focusAt(Offset point) async {
    final current = state;
    if (current is! CameraReady) return;

    await hardware.setFocusPoint(point);
    emit(current.copyWith(focusPoint: point));
  }

  Future<void> capture() async {
    final current = state;
    if (current is! CameraReady || current.isCapturing) return;
    emit(current.copyWith(isCapturing: true));

    _currentBatchId ??= (await repository.createBatch()).id;
    final filePath = await hardware.takePicture();
    final image = CapturedImage(
      id: 'img_${DateTime.now().microsecondsSinceEpoch}_${_imageIdCounter++}',
      batchId: _currentBatchId!,
      filePath: filePath,
    );
    await repository.addImageToBatch(_currentBatchId!, image);

    final refreshed = state;
    if (refreshed is CameraReady) {
      emit(refreshed.copyWith(
        isCapturing: false,
        batchImageCount: refreshed.batchImageCount + 1,
      ));
    }
  }

  Future<void> finalizeBatch() async {
    final batchId = _currentBatchId;
    if (batchId == null) return;

    await syncCoordinator.finalizeAndSync(batchId);
    _currentBatchId = null;

    final current = state;
    if (current is CameraReady) {
      emit(current.copyWith(batchImageCount: 0));
    }
  }

  double _clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  @override
  Future<void> close() async {
    await hardware.dispose();
    return super.close();
  }
}
