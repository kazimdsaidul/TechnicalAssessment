import 'package:camera_sync/domain/model/captured_image.dart';
import 'package:camera_sync/domain/model/upload_batch.dart';
import 'package:camera_sync/domain/model/upload_status.dart';
import 'package:camera_sync/domain/repository/upload_queue_repository.dart';
import 'package:camera_sync/presentation/upload_queue/upload_manager_screen.dart';
import 'package:camera_sync/presentation/upload_queue/upload_queue_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUploadQueueRepository extends Mock implements UploadQueueRepository {}

void main() {
  testWidgets("renders each image's status driven directly by UploadQueueCubit state", (tester) async {
    final repository = MockUploadQueueRepository();
    final batch = UploadBatch(
      id: 'batch1',
      createdAt: DateTime(2026),
      status: BatchStatus.finalized,
      images: const [
        CapturedImage(id: '1', batchId: 'batch1', filePath: '/a.jpg'),
        CapturedImage(id: '2', batchId: 'batch1', filePath: '/b.jpg', status: UploadStatus.uploading),
        CapturedImage(id: '3', batchId: 'batch1', filePath: '/c.jpg', status: UploadStatus.synced),
        CapturedImage(id: '4', batchId: 'batch1', filePath: '/d.jpg', status: UploadStatus.failed, retryCount: 2),
      ],
    );
    when(() => repository.getAllBatches()).thenAnswer((_) async => [batch]);

    final cubit = UploadQueueCubit(repository: repository, pollInterval: const Duration(seconds: 10));

    await tester.pumpWidget(MaterialApp(home: UploadManagerScreen(cubit: cubit)));
    await tester.pumpAndSettle();

    expect(find.text('WAITING FOR CONNECTION'), findsOneWidget);
    expect(find.text('UPLOADING...'), findsOneWidget);
    expect(find.text('SYNCED'), findsOneWidget);
    expect(find.text('RETRYING (ATTEMPT 2)'), findsOneWidget);
    expect(find.text('1/4 synced · 1 retrying'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await cubit.close();
  });
}
