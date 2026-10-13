import 'package:camera_sync/data/remote/mock_upload_api.dart';
import 'package:camera_sync/domain/model/captured_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockUploadApi', () {
    test('first attempt fails, second attempt succeeds', () async {
      final api = MockUploadApi(simulatedLatency: Duration.zero);
      const image = CapturedImage(id: 'img1', batchId: 'b1', filePath: '/a.jpg');

      final first = await api.uploadImage(image);
      final second = await api.uploadImage(image);

      expect(first, isFalse);
      expect(second, isTrue);
    });

    test('subsequent attempts after success remain successful', () async {
      final api = MockUploadApi(simulatedLatency: Duration.zero);
      const image = CapturedImage(id: 'img1', batchId: 'b1', filePath: '/a.jpg');

      await api.uploadImage(image);
      await api.uploadImage(image);
      final third = await api.uploadImage(image);

      expect(third, isTrue);
    });

    test('different images track attempts independently', () async {
      final api = MockUploadApi(simulatedLatency: Duration.zero);
      const imageA = CapturedImage(id: 'a', batchId: 'b1', filePath: '/a.jpg');
      const imageB = CapturedImage(id: 'b', batchId: 'b1', filePath: '/b.jpg');

      expect(await api.uploadImage(imageA), isFalse);
      expect(await api.uploadImage(imageB), isFalse, reason: 'a new image also fails its first attempt');
      expect(await api.uploadImage(imageA), isTrue);
    });
  });
}
