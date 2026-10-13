import '../../domain/model/captured_image.dart';
import '../../domain/repository/upload_api.dart';

/// No real backend exists for this assessment (see proposal.md). This mock
/// deterministically fails an image's first upload attempt and succeeds on
/// the second, per-image — so the resilient-retry behavior is visible every
/// time, rather than depending on randomized failure.
class MockUploadApi implements UploadApi {
  MockUploadApi({this.simulatedLatency = const Duration(milliseconds: 500)});

  final Duration simulatedLatency;
  final Map<String, int> _attemptCounts = {};

  @override
  Future<bool> uploadImage(CapturedImage image) async {
    if (simulatedLatency > Duration.zero) {
      await Future<void>.delayed(simulatedLatency);
    }
    final attempts = (_attemptCounts[image.id] ?? 0) + 1;
    _attemptCounts[image.id] = attempts;
    return attempts >= 2;
  }
}
