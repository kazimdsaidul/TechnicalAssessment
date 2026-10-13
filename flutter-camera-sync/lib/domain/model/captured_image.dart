import 'package:equatable/equatable.dart';

import 'upload_status.dart';

/// A single captured photo and its upload progress.
class CapturedImage extends Equatable {
  const CapturedImage({
    required this.id,
    required this.batchId,
    required this.filePath,
    this.status = UploadStatus.pending,
    this.retryCount = 0,
  });

  final String id;
  final String batchId;
  final String filePath;
  final UploadStatus status;
  final int retryCount;

  CapturedImage copyWith({
    UploadStatus? status,
    int? retryCount,
  }) {
    return CapturedImage(
      id: id,
      batchId: batchId,
      filePath: filePath,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  @override
  List<Object?> get props => [id, batchId, filePath, status, retryCount];
}
