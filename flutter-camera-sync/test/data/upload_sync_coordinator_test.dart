import 'dart:io';

import 'package:camera_sync/data/local/hive_adapters.dart';
import 'package:camera_sync/data/local/hive_upload_queue_repository.dart';
import 'package:camera_sync/data/remote/mock_upload_api.dart';
import 'package:camera_sync/data/sync/background_sync_callback.dart';
import 'package:camera_sync/data/sync/upload_sync_coordinator.dart';
import 'package:camera_sync/domain/model/captured_image.dart';
import 'package:camera_sync/domain/model/upload_batch.dart';
import 'package:camera_sync/domain/model/upload_status.dart';
import 'package:camera_sync/domain/repository/upload_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:workmanager/workmanager.dart';

class MockWorkmanager extends Mock implements Workmanager {}

class _AlwaysSucceedsApi implements UploadApi {
  @override
  Future<bool> uploadImage(CapturedImage image) async => true;
}

void main() {
  late Directory tempDir;
  late Box<UploadBatch> box;
  late HiveUploadQueueRepository repository;
  late MockWorkmanager workmanager;

  setUpAll(() {
    registerFallbackValue(Constraints());
    registerFallbackValue(ExistingWorkPolicy.replace);
    registerFallbackValue(BackoffPolicy.exponential);
    registerFallbackValue(const Duration(seconds: 30));
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sync_coord_test_');
    Hive.init(tempDir.path);
    registerHiveAdapters();
    box = await Hive.openBox<UploadBatch>('coord_test');
    repository = HiveUploadQueueRepository(box);
    workmanager = MockWorkmanager();
    when(
      () => workmanager.registerOneOffTask(
        any(),
        any(),
        constraints: any(named: 'constraints'),
        existingWorkPolicy: any(named: 'existingWorkPolicy'),
        backoffPolicy: any(named: 'backoffPolicy'),
        backoffPolicyDelay: any(named: 'backoffPolicyDelay'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteBoxFromDisk('coord_test', path: tempDir.path);
    await tempDir.delete(recursive: true);
  });

  test('schedules a connectivity-constrained background retry when the foreground attempt fails', () async {
    final coordinator = UploadSyncCoordinator(
      repository: repository,
      api: MockUploadApi(simulatedLatency: Duration.zero),
      workmanager: workmanager,
    );
    final batch = await repository.createBatch();
    await repository.addImageToBatch(
      batch.id,
      CapturedImage(id: 'img1', batchId: batch.id, filePath: '/a.jpg'),
    );

    await coordinator.finalizeAndSync(batch.id);

    final captured = verify(
      () => workmanager.registerOneOffTask(
        uploadRetryTaskName,
        uploadRetryTaskName,
        constraints: captureAny(named: 'constraints'),
        existingWorkPolicy: any(named: 'existingWorkPolicy'),
        backoffPolicy: any(named: 'backoffPolicy'),
        backoffPolicyDelay: any(named: 'backoffPolicyDelay'),
      ),
    ).captured;

    final constraints = captured.single as Constraints;
    expect(constraints.networkType, NetworkType.connected);

    final updatedBatch = box.get(batch.id)!;
    expect(updatedBatch.images.single.status, UploadStatus.failed);
  });

  test('does not schedule a background job when every image uploads successfully', () async {
    final coordinator = UploadSyncCoordinator(
      repository: repository,
      api: _AlwaysSucceedsApi(),
      workmanager: workmanager,
    );
    final batch = await repository.createBatch();
    await repository.addImageToBatch(
      batch.id,
      CapturedImage(id: 'img1', batchId: batch.id, filePath: '/a.jpg'),
    );

    await coordinator.finalizeAndSync(batch.id);

    verifyNever(
      () => workmanager.registerOneOffTask(
        any(),
        any(),
        constraints: any(named: 'constraints'),
        existingWorkPolicy: any(named: 'existingWorkPolicy'),
        backoffPolicy: any(named: 'backoffPolicy'),
        backoffPolicyDelay: any(named: 'backoffPolicyDelay'),
      ),
    );

    final updatedBatch = box.get(batch.id)!;
    expect(updatedBatch.images.single.status, UploadStatus.synced);
  });
}
