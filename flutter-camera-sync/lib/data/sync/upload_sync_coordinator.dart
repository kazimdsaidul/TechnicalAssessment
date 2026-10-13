import 'package:workmanager/workmanager.dart';

import '../../domain/model/upload_status.dart';
import '../../domain/repository/upload_api.dart';
import '../../domain/repository/upload_queue_repository.dart';
import 'background_sync_callback.dart';

/// Coordinates what happens when a batch is finalized: an immediate
/// foreground upload attempt (fast feedback, no need to background the app
/// to see the fail-then-retry story), backed by a `workmanager` job that
/// guarantees the retry happens even if the app is backgrounded or killed
/// before the foreground attempt resolves. See design.md.
class UploadSyncCoordinator {
  UploadSyncCoordinator({
    required this.repository,
    required this.api,
    Workmanager? workmanager,
  }) : _workmanager = workmanager ?? Workmanager();

  final UploadQueueRepository repository;
  final UploadApi api;
  final Workmanager _workmanager;

  /// Finalizes [batchId], attempts to upload its images immediately, and
  /// schedules a background retry job if any attempt failed.
  Future<void> finalizeAndSync(String batchId) async {
    await repository.finalizeBatch(batchId);

    final needingUpload = await repository.getImagesNeedingUpload();
    final thisBatchImages = needingUpload.where((image) => image.batchId == batchId);

    var anyFailed = false;
    for (final image in thisBatchImages) {
      await repository.updateImageStatus(batchId, image.id, UploadStatus.uploading);
      final success = await api.uploadImage(image);
      if (success) {
        await repository.updateImageStatus(batchId, image.id, UploadStatus.synced);
      } else {
        await repository.updateImageStatus(
          batchId,
          image.id,
          UploadStatus.failed,
          retryCount: image.retryCount + 1,
        );
        anyFailed = true;
      }
    }

    if (anyFailed) {
      await _scheduleBackgroundRetry();
    }
  }

  Future<void> _scheduleBackgroundRetry() async {
    await _workmanager.registerOneOffTask(
      uploadRetryTaskName,
      uploadRetryTaskName,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
    );
  }
}
