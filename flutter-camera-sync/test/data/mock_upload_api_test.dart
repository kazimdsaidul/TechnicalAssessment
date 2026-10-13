import 'package:camera_sync/data/remote/mock_upload_api.dart';
import 'package:camera_sync/domain/model/captured_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockUploadApi', () {
    test('an image with no prior attempts fails', () async {
      final api = MockUploadApi(simulatedLatency: Duration.zero);
      const image = CapturedImage(id: 'img1', batchId: 'b1', filePath: '/a.jpg');

      expect(await api.uploadImage(image), isFalse);
    });

    test('an image with a persisted retry count succeeds', () async {
      final api = MockUploadApi(simulatedLatency: Duration.zero);
      const image = CapturedImage(id: 'img1', batchId: 'b1', filePath: '/a.jpg', retryCount: 1);

      expect(await api.uploadImage(image), isTrue);
    });

    test(
      'determinism survives a fresh MockUploadApi instance, as happens across the '
      'foreground/background isolate boundary',
      () async {
        const firstAttemptImage = CapturedImage(id: 'img1', batchId: 'b1', filePath: '/a.jpg');
        final firstResult = await MockUploadApi(simulatedLatency: Duration.zero).uploadImage(firstAttemptImage);
        expect(firstResult, isFalse);

        final retriedImage = firstAttemptImage.copyWith(retryCount: firstAttemptImage.retryCount + 1);
        final secondResult = await MockUploadApi(simulatedLatency: Duration.zero).uploadImage(retriedImage);
        expect(secondResult, isTrue);
      },
    );

    test('different images are judged independently by their own retry count', () async {
      final api = MockUploadApi(simulatedLatency: Duration.zero);
      const imageA = CapturedImage(id: 'a', batchId: 'b1', filePath: '/a.jpg');
      const imageB = CapturedImage(id: 'b', batchId: 'b1', filePath: '/b.jpg', retryCount: 1);

      expect(await api.uploadImage(imageA), isFalse);
      expect(await api.uploadImage(imageB), isTrue);
    });
  });
}
