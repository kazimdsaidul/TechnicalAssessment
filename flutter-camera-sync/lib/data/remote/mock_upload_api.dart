import '../../domain/model/captured_image.dart';
import '../../domain/repository/upload_api.dart';

/// No real backend exists for this assessment (see proposal.md). This mock
/// deterministically fails an image's first upload attempt and succeeds on
/// the second, per-image — so the resilient-retry behavior is visible every
/// time, rather than depending on randomized failure.
///
/// Determinism is driven by [CapturedImage.retryCount] rather than an
/// in-memory attempt counter: the background retry runs in a separate
/// `workmanager` isolate on Android with no shared memory with the
/// foreground UI isolate, so an in-memory counter here would reset to zero
/// every time and the image would fail forever. `retryCount` is persisted
/// by the repository on each failed attempt, so it survives the isolate
/// boundary and "second attempt" means the same thing on both sides.
class MockUploadApi implements UploadApi {
  MockUploadApi({this.simulatedLatency = const Duration(milliseconds: 500)});

  final Duration simulatedLatency;

  @override
  Future<bool> uploadImage(CapturedImage image) async {
    if (simulatedLatency > Duration.zero) {
      await Future<void>.delayed(simulatedLatency);
    }
    return image.retryCount >= 1;
  }
}
