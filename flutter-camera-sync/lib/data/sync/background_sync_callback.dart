import 'package:workmanager/workmanager.dart';

import '../../domain/model/upload_status.dart';
import '../../domain/repository/upload_api.dart';
import '../../domain/repository/upload_queue_repository.dart';
import '../local/hive_bootstrap.dart';
import '../local/hive_upload_queue_repository.dart';
import '../remote/mock_upload_api.dart';

const uploadRetryTaskName = 'uploadRetryTask';

/// Entry point registered with `Workmanager().initialize()`. Runs in a
/// separate background isolate on Android — it does not share memory with
/// the UI isolate, so it opens its own Hive connection (see
/// `openUploadQueueBox`).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == uploadRetryTaskName) {
      return performBackgroundUploadRetry();
    }
    return true;
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
