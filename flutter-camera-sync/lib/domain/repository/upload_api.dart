import '../model/captured_image.dart';

/// Uploads a single image. No real backend exists for this assessment — see
/// the data-layer `MockUploadApi` implementation — but the domain and
/// presentation layers only ever depend on this interface.
abstract class UploadApi {
  /// Attempts to upload [image]. Returns `true` on success, `false` on a
  /// failure the caller should treat as retryable (no connectivity, server
  /// error, etc).
  Future<bool> uploadImage(CapturedImage image);
}
