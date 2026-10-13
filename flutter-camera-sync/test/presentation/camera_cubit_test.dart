import 'package:bloc_test/bloc_test.dart';
import 'package:camera_sync/data/camera/camera_hardware_controller.dart';
import 'package:camera_sync/data/sync/upload_sync_coordinator.dart';
import 'package:camera_sync/domain/model/captured_image.dart';
import 'package:camera_sync/domain/model/upload_batch.dart';
import 'package:camera_sync/domain/repository/upload_queue_repository.dart';
import 'package:camera_sync/presentation/camera/camera_cubit.dart';
import 'package:camera_sync/presentation/camera/camera_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCameraHardwareController extends Mock implements CameraHardwareController {}

class MockUploadQueueRepository extends Mock implements UploadQueueRepository {}

class MockUploadSyncCoordinator extends Mock implements UploadSyncCoordinator {}

void main() {
  late MockCameraHardwareController hardware;
  late MockUploadQueueRepository repository;
  late MockUploadSyncCoordinator syncCoordinator;

  setUpAll(() {
    registerFallbackValue(
      const CapturedImage(id: 'fallback', batchId: 'fallback', filePath: 'fallback'),
    );
  });

  setUp(() {
    hardware = MockCameraHardwareController();
    repository = MockUploadQueueRepository();
    syncCoordinator = MockUploadSyncCoordinator();

    when(() => hardware.initialize()).thenAnswer((_) async {});
    when(() => hardware.minZoomLevel).thenReturn(0.5);
    when(() => hardware.maxZoomLevel).thenReturn(4.0);
    when(() => hardware.setZoomLevel(any())).thenAnswer((_) async {});
    when(() => hardware.takePicture()).thenAnswer((_) async => '/fake/path.jpg');
    when(() => hardware.dispose()).thenAnswer((_) async {});
  });

  CameraCubit buildCubit() => CameraCubit(
        hardware: hardware,
        repository: repository,
        syncCoordinator: syncCoordinator,
      );

  blocTest<CameraCubit, CameraState>(
    'initialize emits CameraReady seeded with the hardware zoom range',
    build: buildCubit,
    act: (cubit) => cubit.initialize(),
    expect: () => [
      const CameraReady(zoomLevel: 1.0, minZoom: 0.5, maxZoom: 4.0),
    ],
  );

  blocTest<CameraCubit, CameraState>(
    'setZoomLevel clamps a request above the hardware maximum',
    build: buildCubit,
    seed: () => const CameraReady(zoomLevel: 1.0, minZoom: 0.5, maxZoom: 4.0),
    act: (cubit) => cubit.setZoomLevel(10.0),
    expect: () => [
      const CameraReady(zoomLevel: 4.0, minZoom: 0.5, maxZoom: 4.0),
    ],
    verify: (_) {
      verify(() => hardware.setZoomLevel(4.0)).called(1);
    },
  );

  blocTest<CameraCubit, CameraState>(
    'setZoomLevel clamps a request below the hardware minimum',
    build: buildCubit,
    seed: () => const CameraReady(zoomLevel: 1.0, minZoom: 0.5, maxZoom: 4.0),
    act: (cubit) => cubit.setZoomLevel(0.1),
    expect: () => [
      const CameraReady(zoomLevel: 0.5, minZoom: 0.5, maxZoom: 4.0),
    ],
  );

  blocTest<CameraCubit, CameraState>(
    'setZoomPreset jumps directly to the preset value within range',
    build: buildCubit,
    seed: () => const CameraReady(zoomLevel: 1.0, minZoom: 0.5, maxZoom: 4.0),
    act: (cubit) => cubit.setZoomPreset(2.0),
    expect: () => [
      const CameraReady(zoomLevel: 2.0, minZoom: 0.5, maxZoom: 4.0),
    ],
  );

  group('capture', () {
    late UploadBatch batch;

    setUp(() {
      batch = UploadBatch(id: 'batch1', createdAt: DateTime(2026));
      when(() => repository.createBatch()).thenAnswer((_) async => batch);
      when(() => repository.addImageToBatch(any(), any())).thenAnswer((_) async {});
    });

    blocTest<CameraCubit, CameraState>(
      'first capture creates a batch and increments the count to 1',
      build: buildCubit,
      seed: () => const CameraReady(zoomLevel: 1.0, minZoom: 0.5, maxZoom: 4.0),
      act: (cubit) => cubit.capture(),
      expect: () => [
        const CameraReady(zoomLevel: 1.0, minZoom: 0.5, maxZoom: 4.0, isCapturing: true),
        const CameraReady(zoomLevel: 1.0, minZoom: 0.5, maxZoom: 4.0, batchImageCount: 1),
      ],
      verify: (_) {
        verify(() => repository.createBatch()).called(1);
        verify(() => repository.addImageToBatch('batch1', any(that: isA<CapturedImage>()))).called(1);
      },
    );

    blocTest<CameraCubit, CameraState>(
      'three captures reuse the same batch and the count reaches 3',
      build: buildCubit,
      seed: () => const CameraReady(zoomLevel: 1.0, minZoom: 0.5, maxZoom: 4.0),
      act: (cubit) async {
        await cubit.capture();
        await cubit.capture();
        await cubit.capture();
      },
      verify: (_) {
        verify(() => repository.createBatch()).called(1);
        verify(() => repository.addImageToBatch('batch1', any())).called(3);
      },
      expect: () => [
        const CameraReady(zoomLevel: 1.0, minZoom: 0.5, maxZoom: 4.0, isCapturing: true),
        const CameraReady(zoomLevel: 1.0, minZoom: 0.5, maxZoom: 4.0, batchImageCount: 1),
        const CameraReady(zoomLevel: 1.0, minZoom: 0.5, maxZoom: 4.0, batchImageCount: 1, isCapturing: true),
        const CameraReady(zoomLevel: 1.0, minZoom: 0.5, maxZoom: 4.0, batchImageCount: 2),
        const CameraReady(zoomLevel: 1.0, minZoom: 0.5, maxZoom: 4.0, batchImageCount: 2, isCapturing: true),
        const CameraReady(zoomLevel: 1.0, minZoom: 0.5, maxZoom: 4.0, batchImageCount: 3),
      ],
    );
  });

  blocTest<CameraCubit, CameraState>(
    'finalizeBatch delegates to the sync coordinator and resets the count',
    setUp: () {
      final batch = UploadBatch(id: 'batch1', createdAt: DateTime(2026));
      when(() => repository.createBatch()).thenAnswer((_) async => batch);
      when(() => repository.addImageToBatch(any(), any())).thenAnswer((_) async {});
      when(() => syncCoordinator.finalizeAndSync(any())).thenAnswer((_) async {});
    },
    build: buildCubit,
    seed: () => const CameraReady(zoomLevel: 1.0, minZoom: 0.5, maxZoom: 4.0),
    act: (cubit) async {
      await cubit.capture();
      await cubit.finalizeBatch();
    },
    skip: 2,
    expect: () => [
      const CameraReady(zoomLevel: 1.0, minZoom: 0.5, maxZoom: 4.0, batchImageCount: 0),
    ],
    verify: (_) {
      verify(() => syncCoordinator.finalizeAndSync('batch1')).called(1);
    },
  );

  blocTest<CameraCubit, CameraState>(
    'initialize emits CameraError when the hardware fails to start',
    build: buildCubit,
    setUp: () {
      when(() => hardware.initialize()).thenThrow(Exception('camera unavailable'));
    },
    act: (cubit) => cubit.initialize(),
    expect: () => [isA<CameraError>()],
  );
}
