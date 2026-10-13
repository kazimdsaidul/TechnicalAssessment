import 'dart:async';

import 'package:camera/camera.dart' show CameraPreview;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/camera/camera_controller_adapter.dart';
import '../../data/remote/mock_upload_api.dart';
import '../../data/sync/upload_sync_coordinator.dart';
import '../../domain/repository/upload_queue_repository.dart';
import '../upload_queue/upload_manager_screen.dart';
import '../upload_queue/upload_queue_cubit.dart';
import 'camera_cubit.dart';
import 'camera_state.dart';
import 'zoom_controls.dart';

enum _PermissionState { checking, granted, denied, permanentlyDenied }

class CameraPreviewScreen extends StatefulWidget {
  const CameraPreviewScreen({super.key, required this.repository});

  final UploadQueueRepository repository;

  @override
  State<CameraPreviewScreen> createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen> {
  late final CameraControllerAdapter _hardware;
  late final CameraCubit _cubit;
  _PermissionState _permissionState = _PermissionState.checking;

  @override
  void initState() {
    super.initState();
    _hardware = CameraControllerAdapter();
    _cubit = CameraCubit(
      hardware: _hardware,
      repository: widget.repository,
      syncCoordinator: UploadSyncCoordinator(
        repository: widget.repository,
        api: MockUploadApi(),
      ),
    );
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _permissionState = status.isGranted
          ? _PermissionState.granted
          : status.isPermanentlyDenied
              ? _PermissionState.permanentlyDenied
              : _PermissionState.denied;
    });
    if (status.isGranted) {
      await _cubit.initialize();
    }
  }

  Future<void> _handleUploadBatch() async {
    await _cubit.finalizeBatch();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UploadManagerScreen(cubit: UploadQueueCubit(repository: widget.repository)),
      ),
    );
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: switch (_permissionState) {
        _PermissionState.checking => const Center(child: CircularProgressIndicator(color: Colors.white)),
        _PermissionState.denied => _PermissionMessage(
            message: 'Camera access is needed to capture photos for this batch.',
            actionLabel: 'Grant Access',
            onAction: _checkPermission,
          ),
        _PermissionState.permanentlyDenied => _PermissionMessage(
            message: 'Camera access was permanently denied. Enable it from system settings to continue.',
            actionLabel: 'Open Settings',
            onAction: openAppSettings,
          ),
        _PermissionState.granted => BlocProvider.value(
            value: _cubit,
            child: BlocBuilder<CameraCubit, CameraState>(
              builder: (context, state) {
                return switch (state) {
                  CameraInitializing() => const Center(child: CircularProgressIndicator(color: Colors.white)),
                  CameraError(:final message) => _PermissionMessage(
                      message: 'Camera unavailable: $message',
                      actionLabel: 'Retry',
                      onAction: _cubit.initialize,
                    ),
                  CameraReady() => _ReadyCameraView(
                      hardware: _hardware,
                      state: state,
                      onUploadBatch: _handleUploadBatch,
                    ),
                };
              },
            ),
          ),
      },
    );
  }
}

class _PermissionMessage extends StatelessWidget {
  const _PermissionMessage({required this.message, required this.actionLabel, required this.onAction});

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _ReadyCameraView extends StatefulWidget {
  const _ReadyCameraView({required this.hardware, required this.state, required this.onUploadBatch});

  final CameraControllerAdapter hardware;
  final CameraReady state;
  final VoidCallback onUploadBatch;

  @override
  State<_ReadyCameraView> createState() => _ReadyCameraViewState();
}

class _ReadyCameraViewState extends State<_ReadyCameraView> {
  Offset? _indicatorPosition;
  Timer? _indicatorTimer;
  double _baseZoom = 1.0;

  @override
  void dispose() {
    _indicatorTimer?.cancel();
    super.dispose();
  }

  void _handleTapUp(TapUpDetails details, BoxConstraints constraints) {
    final cubit = context.read<CameraCubit>();
    final normalized = Offset(
      (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0),
      (details.localPosition.dy / constraints.maxHeight).clamp(0.0, 1.0),
    );
    cubit.focusAt(normalized);

    _indicatorTimer?.cancel();
    setState(() => _indicatorPosition = details.localPosition);
    _indicatorTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _indicatorPosition = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CameraCubit>();
    final state = widget.state;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onScaleStart: (_) => _baseZoom = state.zoomLevel,
                      onScaleUpdate: (details) => cubit.setZoomLevel(_baseZoom * details.scale),
                      onTapUp: (details) => _handleTapUp(details, constraints),
                      child: CameraPreview(widget.hardware.controller),
                    ),
                    if (_indicatorPosition != null)
                      Positioned(
                        left: _indicatorPosition!.dx - 32,
                        top: _indicatorPosition!.dy - 32,
                        child: IgnorePointer(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 8,
                      top: 24,
                      bottom: 24,
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: SizedBox(
                          width: 160,
                          child: Slider(
                            value: state.zoomLevel,
                            min: state.minZoom,
                            max: state.maxZoom,
                            onChanged: cubit.setZoomLevel,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          ZoomControls(state: state),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _BatchBadge(count: state.batchImageCount),
                GestureDetector(
                  onTap: state.isCapturing ? null : cubit.capture,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: state.isCapturing ? Colors.white54 : Colors.white,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                  ),
                ),
                const SizedBox(width: 56, height: 56),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: state.batchImageCount > 0 ? widget.onUploadBatch : null,
                icon: const Icon(Icons.upload),
                label: Text('UPLOAD BATCH (${state.batchImageCount})'),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _BatchBadge extends StatelessWidget {
  const _BatchBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white54),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }
}
