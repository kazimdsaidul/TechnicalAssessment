import 'package:equatable/equatable.dart';

import '../model/upload_batch.dart';
import '../model/upload_status.dart';

/// Summarized sync progress for a batch, derived purely from its images'
/// statuses — no I/O, easy to unit test in isolation.
class BatchProgress extends Equatable {
  const BatchProgress({
    required this.total,
    required this.synced,
    required this.failed,
    required this.uploading,
  });

  final int total;
  final int synced;
  final int failed;
  final int uploading;

  int get pending => total - synced - failed - uploading;

  double get fractionSynced => total == 0 ? 0 : synced / total;

  bool get isComplete => total > 0 && synced == total;

  @override
  List<Object?> get props => [total, synced, failed, uploading];
}

class CalculateBatchProgressUseCase {
  BatchProgress call(UploadBatch batch) {
    final images = batch.images;
    return BatchProgress(
      total: images.length,
      synced: images.where((i) => i.status == UploadStatus.synced).length,
      failed: images.where((i) => i.status == UploadStatus.failed).length,
      uploading: images.where((i) => i.status == UploadStatus.uploading).length,
    );
  }
}
