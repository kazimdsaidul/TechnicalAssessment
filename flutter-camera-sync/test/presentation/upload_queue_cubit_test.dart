import 'package:camera_sync/domain/model/upload_batch.dart';
import 'package:camera_sync/domain/repository/upload_queue_repository.dart';
import 'package:camera_sync/presentation/upload_queue/upload_queue_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUploadQueueRepository extends Mock implements UploadQueueRepository {}

void main() {
  late MockUploadQueueRepository repository;
  late List<UploadBatch> currentBatches;

  setUp(() {
    repository = MockUploadQueueRepository();
    currentBatches = [];
    when(() => repository.getAllBatches()).thenAnswer((_) async => currentBatches);
  });

  test('start emits an immediate snapshot, then reflects queue changes on the next poll', () async {
    final cubit = UploadQueueCubit(
      repository: repository,
      pollInterval: const Duration(milliseconds: 20),
    );

    await cubit.start();
    expect(cubit.state.batches, isEmpty);

    currentBatches = [UploadBatch(id: 'b1', createdAt: DateTime(2026))];
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(cubit.state.batches, hasLength(1));
    expect(cubit.state.batches.single.id, 'b1');

    await cubit.close();
  });

  test('stop halts polling so later queue changes are not reflected', () async {
    final cubit = UploadQueueCubit(
      repository: repository,
      pollInterval: const Duration(milliseconds: 20),
    );

    await cubit.start();
    cubit.stop();

    currentBatches = [UploadBatch(id: 'b2', createdAt: DateTime(2026))];
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(cubit.state.batches, isEmpty);

    await cubit.close();
  });
}
