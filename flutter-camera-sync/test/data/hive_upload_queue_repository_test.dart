import 'dart:io';

import 'package:camera_sync/data/local/hive_adapters.dart';
import 'package:camera_sync/data/local/hive_upload_queue_repository.dart';
import 'package:camera_sync/domain/model/captured_image.dart';
import 'package:camera_sync/domain/model/upload_batch.dart';
import 'package:camera_sync/domain/model/upload_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late Box<UploadBatch> box;
  late HiveUploadQueueRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
    registerHiveAdapters();
    box = await Hive.openBox<UploadBatch>('upload_batches_test');
    repository = HiveUploadQueueRepository(box);
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteBoxFromDisk('upload_batches_test', path: tempDir.path);
    await tempDir.delete(recursive: true);
  });

  test('create batch, add image, round-trip read back from box', () async {
    final batch = await repository.createBatch();

    await repository.addImageToBatch(
      batch.id,
      CapturedImage(id: 'img1', batchId: batch.id, filePath: '/a.jpg'),
    );

    final reread = box.get(batch.id);
    expect(reread, isNotNull);
    expect(reread!.images, hasLength(1));
    expect(reread.images.first.id, 'img1');
    expect(reread.images.first.status, UploadStatus.pending);
  });

  test('finalize batch persists status', () async {
    final batch = await repository.createBatch();
    await repository.finalizeBatch(batch.id);

    final reread = box.get(batch.id);
    expect(reread!.status, BatchStatus.finalized);
  });

  test('updateImageStatus persists the new status and retry count', () async {
    final batch = await repository.createBatch();
    await repository.addImageToBatch(
      batch.id,
      CapturedImage(id: 'img1', batchId: batch.id, filePath: '/a.jpg'),
    );

    await repository.updateImageStatus(batch.id, 'img1', UploadStatus.failed, retryCount: 1);

    final reread = box.get(batch.id);
    expect(reread!.images.first.status, UploadStatus.failed);
    expect(reread.images.first.retryCount, 1);
  });

  test('getImagesNeedingUpload only returns pending/failed images from finalized batches', () async {
    final batch = await repository.createBatch();
    await repository.addImageToBatch(
      batch.id,
      CapturedImage(id: 'pending', batchId: batch.id, filePath: '/p.jpg'),
    );
    await repository.addImageToBatch(
      batch.id,
      CapturedImage(
        id: 'synced',
        batchId: batch.id,
        filePath: '/s.jpg',
        status: UploadStatus.synced,
      ),
    );
    await repository.finalizeBatch(batch.id);

    final unfinalizedBatch = await repository.createBatch();
    await repository.addImageToBatch(
      unfinalizedBatch.id,
      CapturedImage(id: 'notready', batchId: unfinalizedBatch.id, filePath: '/n.jpg'),
    );

    final needingUpload = await repository.getImagesNeedingUpload();

    expect(needingUpload.map((i) => i.id), ['pending']);
  });

  test('observeBatches emits on each change, and cancelling the subscription completes promptly', () async {
    final events = <int>[];
    final subscription = repository.observeBatches().listen(
          (batches) => events.add(batches.length),
        );

    await Future<void>.delayed(const Duration(milliseconds: 50));
    await repository.createBatch();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await repository.createBatch();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await subscription.cancel().timeout(const Duration(seconds: 2));

    expect(events, [0, 1, 2]);
  });
}
