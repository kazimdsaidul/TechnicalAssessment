import 'dart:io';

import 'package:camera_sync/data/local/hive_adapters.dart';
import 'package:camera_sync/data/local/hive_upload_queue_repository.dart';
import 'package:camera_sync/data/remote/mock_upload_api.dart';
import 'package:camera_sync/data/sync/background_sync_callback.dart';
import 'package:camera_sync/domain/model/captured_image.dart';
import 'package:camera_sync/domain/model/upload_batch.dart';
import 'package:camera_sync/domain/model/upload_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late Box<UploadBatch> box;
  late HiveUploadQueueRepository repository;
  late MockUploadApi api;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_sync_test_');
    Hive.init(tempDir.path);
    registerHiveAdapters();
    box = await Hive.openBox<UploadBatch>('sync_test');
    repository = HiveUploadQueueRepository(box);
    api = MockUploadApi(simulatedLatency: Duration.zero);

    final batch = await repository.createBatch();
    await repository.addImageToBatch(
      batch.id,
      CapturedImage(id: 'img1', batchId: batch.id, filePath: '/a.jpg'),
    );
    await repository.addImageToBatch(
      batch.id,
      CapturedImage(id: 'img2', batchId: batch.id, filePath: '/b.jpg'),
    );
    await repository.finalizeBatch(batch.id);
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteBoxFromDisk('sync_test', path: tempDir.path);
    await tempDir.delete(recursive: true);
  });

  test('first run fails every image and signals retry; second run succeeds', () async {
    final firstRunSucceeded = await performBackgroundUploadRetry(
      repositoryOverride: repository,
      apiOverride: api,
    );

    expect(firstRunSucceeded, isFalse, reason: 'MockUploadApi fails every image on its first attempt');

    final afterFirstRun = await repository.getImagesNeedingUpload();
    expect(afterFirstRun, hasLength(2));
    expect(afterFirstRun.every((i) => i.status == UploadStatus.failed), isTrue);
    expect(afterFirstRun.every((i) => i.retryCount == 1), isTrue);

    final secondRunSucceeded = await performBackgroundUploadRetry(
      repositoryOverride: repository,
      apiOverride: api,
    );

    expect(secondRunSucceeded, isTrue, reason: 'MockUploadApi succeeds on the second attempt per image');

    final afterSecondRun = await repository.getImagesNeedingUpload();
    expect(afterSecondRun, isEmpty, reason: 'both images should now be synced, not pending/failed');
  });

  test('a batch still being captured (not finalized) is left untouched', () async {
    final unfinalized = await repository.createBatch();
    await repository.addImageToBatch(
      unfinalized.id,
      CapturedImage(id: 'notready', batchId: unfinalized.id, filePath: '/n.jpg'),
    );

    await performBackgroundUploadRetry(repositoryOverride: repository, apiOverride: api);

    final notReadyBatch = box.get(unfinalized.id)!;
    expect(notReadyBatch.images.single.status, UploadStatus.pending);
  });
}
