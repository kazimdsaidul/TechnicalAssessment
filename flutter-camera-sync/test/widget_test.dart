import 'package:camera_sync/data/camera/camera_hardware_controller.dart';
import 'package:camera_sync/data/sync/upload_sync_coordinator.dart';
import 'package:camera_sync/domain/repository/upload_queue_repository.dart';
import 'package:camera_sync/presentation/camera/camera_cubit.dart';
import 'package:camera_sync/presentation/camera/camera_state.dart';
import 'package:camera_sync/presentation/camera/zoom_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCameraHardwareController extends Mock implements CameraHardwareController {}

class MockUploadQueueRepository extends Mock implements UploadQueueRepository {}

class MockUploadSyncCoordinator extends Mock implements UploadSyncCoordinator {}

void main() {
  testWidgets('tapping a zoom preset chip updates the displayed zoom level', (tester) async {
    final hardware = MockCameraHardwareController();
    when(() => hardware.initialize()).thenAnswer((_) async {});
    when(() => hardware.minZoomLevel).thenReturn(0.5);
    when(() => hardware.maxZoomLevel).thenReturn(4.0);
    when(() => hardware.setZoomLevel(any())).thenAnswer((_) async {});
    when(() => hardware.dispose()).thenAnswer((_) async {});

    final cubit = CameraCubit(
      hardware: hardware,
      repository: MockUploadQueueRepository(),
      syncCoordinator: MockUploadSyncCoordinator(),
    );
    await cubit.initialize();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: BlocBuilder<CameraCubit, CameraState>(
              builder: (context, state) {
                if (state is! CameraReady) return const SizedBox();
                return ZoomControls(state: state);
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('1.0x'), findsOneWidget);

    await tester.tap(find.text('2x'));
    await tester.pumpAndSettle();

    expect(find.text('2.0x'), findsOneWidget);

    await cubit.close();
  });
}
