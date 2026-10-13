import 'package:workmanager/workmanager.dart';

import '../../domain/model/upload_status.dart';
import '../../domain/repository/upload_api.dart';
import '../../domain/repository/upload_queue_repository.dart';
import '../local/hive_bootstrap.dart';
import '../local/hive_upload_queue_repository.dart';
import '../remote/mock_upload_api.dart';

const uploadRetryTaskName = 'uploadRetryTask';

/// Entry point registered with `Workmanager().initialize()`. May run
/// in-process on the UI isolate (while the app is alive) or in a separate
/// headless background isolate (once the app is backgrounded/killed) — the
/// `workmanager` plugin picks whichever avoids spinning up a second engine
/// unnecessarily. Either way this never assumes shared memory with the UI:
/// it opens its own Hive connection (see `openUploadQueueBox`), which is
/// safe to call even when a box of the same name is already open.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != uploadRetryTaskName) return true;
    try {
      return await performBackgroundUploadRetry();
    } catch (_) {
      // Signals WorkManager to retry with its own backoff rather than
      // letting an unexpected failure (e.g. a transient Hive/plugin error)
      // crash the worker and drop the task.
      return false;
    }
  });
}

/// The actual retry logic, factored out of [callbackDispatcher] so it can
/// be invoked directly in tests against injected fakes, without going
/// through the `workmanager` plugin's platform channel.
///
/// Returns `true` only if every pending/failed image succeeded — the
/// workmanager convention where `false` signals WorkManager to retry (with
/// its own exponential backoff) rather than treat the task as satisfied.
Future<bool> performBackgroundUploadRetry({
  UploadQueueRepository? repositoryOverride,
  UploadApi? apiOverride,
}) async {
  final repository = repositoryOverride ?? HiveUploadQueueRepository(await openUploadQueueBox());
  final api = apiOverride ?? MockUploadApi();

  final images = await repository.getImagesNeedingUpload();
  var allSucceeded = true;

  for (final image in images) {
    await repository.updateImageStatus(image.batchId, image.id, UploadStatus.uploading);
    final success = await api.uploadImage(image);
    if (success) {
      await repository.updateImageStatus(image.batchId, image.id, UploadStatus.synced);
    } else {
      await repository.updateImageStatus(
        image.batchId,
        image.id,
        UploadStatus.failed,
        retryCount: image.retryCount + 1,
      );
      allSucceeded = false;
    }
  }

  return allSucceeded;
}
