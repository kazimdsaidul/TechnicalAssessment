import '../model/captured_image.dart';
import '../model/upload_batch.dart';
import '../model/upload_status.dart';

/// The persistent batch/image queue. Implementations must be safe to open
/// from both the UI isolate and a background execution context (see
/// design.md) — callers on either side only ever read/write through this
/// interface.
abstract class UploadQueueRepository {
  /// Emits the current list of batches whenever the queue changes.
  Stream<List<UploadBatch>> observeBatches();

  /// One-shot read of every batch. Used for polling (see design.md on why
  /// the Upload Manager screen polls rather than subscribes), where opening
  /// and tearing down a stream subscription on every tick would be wasteful.
  Future<List<UploadBatch>> getAllBatches();

  /// Creates a new, empty batch in the `capturing` state.
  Future<UploadBatch> createBatch();

  /// Adds a captured image to an existing batch.
  Future<void> addImageToBatch(String batchId, CapturedImage image);

  /// Marks a batch as finalized, handing its images off for upload.
  Future<void> finalizeBatch(String batchId);

  /// Updates a single image's upload status (and retry count).
  Future<void> updateImageStatus(
    String batchId,
    String imageId,
    UploadStatus status, {
    int? retryCount,
  });

  /// One-shot read of every image still needing an upload attempt
  /// (`pending` or `failed`), across all finalized batches. Used by the
  /// background worker, which has no reason to subscribe to the stream.
  Future<List<CapturedImage>> getImagesNeedingUpload();
}
