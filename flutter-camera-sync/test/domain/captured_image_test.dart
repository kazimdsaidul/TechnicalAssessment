import 'package:camera_sync/domain/model/captured_image.dart';
import 'package:camera_sync/domain/model/upload_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CapturedImage status transitions', () {
    test('starts as pending by default', () {
      const image = CapturedImage(id: '1', batchId: 'b1', filePath: '/a.jpg');
      expect(image.status, UploadStatus.pending);
      expect(image.retryCount, 0);
    });

    test('pending -> uploading -> synced', () {
      const pending = CapturedImage(id: '1', batchId: 'b1', filePath: '/a.jpg');

      final uploading = pending.copyWith(status: UploadStatus.uploading);
      expect(uploading.status, UploadStatus.uploading);
      expect(uploading.id, pending.id, reason: 'copyWith must preserve identity');

      final synced = uploading.copyWith(status: UploadStatus.synced);
      expect(synced.status, UploadStatus.synced);
    });

    test('pending -> uploading -> failed increments retry count', () {
      const pending = CapturedImage(id: '1', batchId: 'b1', filePath: '/a.jpg');

      final uploading = pending.copyWith(status: UploadStatus.uploading);
      final failed = uploading.copyWith(
        status: UploadStatus.failed,
        retryCount: uploading.retryCount + 1,
      );

      expect(failed.status, UploadStatus.failed);
      expect(failed.retryCount, 1);
    });

    test('failed -> uploading -> synced on retry', () {
      const failed = CapturedImage(
        id: '1',
        batchId: 'b1',
        filePath: '/a.jpg',
        status: UploadStatus.failed,
        retryCount: 1,
      );

      final retrying = failed.copyWith(status: UploadStatus.uploading);
      final synced = retrying.copyWith(status: UploadStatus.synced);

      expect(synced.status, UploadStatus.synced);
      expect(synced.retryCount, 1, reason: 'retryCount reflects attempts already made');
    });

    test('equality is value-based', () {
      const a = CapturedImage(id: '1', batchId: 'b1', filePath: '/a.jpg');
      const b = CapturedImage(id: '1', batchId: 'b1', filePath: '/a.jpg');
      expect(a, equals(b));
    });
  });
}
