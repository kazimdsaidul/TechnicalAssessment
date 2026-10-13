import 'dart:async';

import 'package:hive/hive.dart';

import '../../domain/model/captured_image.dart';
import '../../domain/model/upload_batch.dart';
import '../../domain/model/upload_status.dart';
import '../../domain/repository/upload_queue_repository.dart';

class HiveUploadQueueRepository implements UploadQueueRepository {
  HiveUploadQueueRepository(this._box);

  final Box<UploadBatch> _box;

  int _idCounter = 0;

  String _generateId() {
    _idCounter++;
    return '${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  @override
  Stream<List<UploadBatch>> observeBatches() {
    // A manually-bridged StreamController, rather than an `async*` generator
    // wrapping `await for (final _ in _box.watch())`: cancelling a listener
    // mid-`await for` on an external plugin-backed stream doesn't tear down
    // promptly, which would hang callers (e.g. a Cubit cancelling its
    // subscription on dispose). Cancelling `boxSubscription` directly here
    // resolves immediately.
    late final StreamController<List<UploadBatch>> controller;
    StreamSubscription<BoxEvent>? boxSubscription;

    controller = StreamController<List<UploadBatch>>(
      onListen: () {
        controller.add(_box.values.toList());
        boxSubscription = _box.watch().listen((_) {
          controller.add(_box.values.toList());
        });
      },
      onCancel: () async {
        await boxSubscription?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  Future<List<UploadBatch>> getAllBatches() async => _box.values.toList();

  @override
  Future<UploadBatch> createBatch() async {
    final batch = UploadBatch(id: _generateId(), createdAt: DateTime.now());
    await _box.put(batch.id, batch);
    return batch;
  }

  @override
  Future<void> addImageToBatch(String batchId, CapturedImage image) async {
    final batch = _box.get(batchId);
    if (batch == null) return;
    await _box.put(batchId, batch.copyWith(images: [...batch.images, image]));
  }

  @override
  Future<void> finalizeBatch(String batchId) async {
    final batch = _box.get(batchId);
    if (batch == null) return;
    await _box.put(batchId, batch.copyWith(status: BatchStatus.finalized));
  }

  @override
  Future<void> updateImageStatus(
    String batchId,
    String imageId,
    UploadStatus status, {
    int? retryCount,
  }) async {
    final batch = _box.get(batchId);
    if (batch == null) return;
    final updatedImages = batch.images.map((image) {
      if (image.id != imageId) return image;
      return image.copyWith(status: status, retryCount: retryCount ?? image.retryCount);
    }).toList();
    await _box.put(batchId, batch.copyWith(images: updatedImages));
  }

  @override
  Future<List<CapturedImage>> getImagesNeedingUpload() async {
    return _box.values
        .where((batch) => batch.status == BatchStatus.finalized)
        .expand((batch) => batch.images)
        .where((image) => image.status == UploadStatus.pending || image.status == UploadStatus.failed)
        .toList();
  }
}
