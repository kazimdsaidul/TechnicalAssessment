import 'package:camera_sync/domain/model/captured_image.dart';
import 'package:camera_sync/domain/model/upload_batch.dart';
import 'package:camera_sync/domain/model/upload_status.dart';
import 'package:camera_sync/domain/usecase/calculate_batch_progress.dart';
import 'package:flutter_test/flutter_test.dart';

CapturedImage _image(String id, UploadStatus status) => CapturedImage(
      id: id,
      batchId: 'b1',
      filePath: '/$id.jpg',
      status: status,
    );

void main() {
  final useCase = CalculateBatchProgressUseCase();

  test('all images synced', () {
    final batch = UploadBatch(
      id: 'b1',
      createdAt: DateTime(2026, 1, 1),
      images: [
        _image('1', UploadStatus.synced),
        _image('2', UploadStatus.synced),
      ],
    );

    final progress = useCase(batch);

    expect(progress.total, 2);
    expect(progress.synced, 2);
    expect(progress.failed, 0);
    expect(progress.fractionSynced, 1.0);
    expect(progress.isComplete, isTrue);
  });

  test('partially synced batch', () {
    final batch = UploadBatch(
      id: 'b1',
      createdAt: DateTime(2026, 1, 1),
      images: [
        _image('1', UploadStatus.synced),
        _image('2', UploadStatus.synced),
        _image('3', UploadStatus.synced),
        _image('4', UploadStatus.pending),
        _image('5', UploadStatus.failed),
      ],
    );

    final progress = useCase(batch);

    expect(progress.total, 5);
    expect(progress.synced, 3);
    expect(progress.failed, 1);
    expect(progress.pending, 1);
    expect(progress.fractionSynced, closeTo(0.6, 0.001));
    expect(progress.isComplete, isFalse);
  });

  test('all images failed', () {
    final batch = UploadBatch(
      id: 'b1',
      createdAt: DateTime(2026, 1, 1),
      images: [
        _image('1', UploadStatus.failed),
        _image('2', UploadStatus.failed),
      ],
    );

    final progress = useCase(batch);

    expect(progress.synced, 0);
    expect(progress.failed, 2);
    expect(progress.fractionSynced, 0.0);
    expect(progress.isComplete, isFalse);
  });

  test('empty batch has zero fraction and is not complete', () {
    final batch = UploadBatch(id: 'b1', createdAt: DateTime(2026, 1, 1));

    final progress = useCase(batch);

    expect(progress.total, 0);
    expect(progress.fractionSynced, 0.0);
    expect(progress.isComplete, isFalse);
  });
}
