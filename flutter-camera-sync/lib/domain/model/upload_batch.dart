import 'package:equatable/equatable.dart';

import 'captured_image.dart';
import 'upload_status.dart';

/// A group of images captured together and uploaded as a unit.
class UploadBatch extends Equatable {
  const UploadBatch({
    required this.id,
    required this.createdAt,
    this.images = const [],
    this.status = BatchStatus.capturing,
  });

  final String id;
  final DateTime createdAt;
  final List<CapturedImage> images;
  final BatchStatus status;

  UploadBatch copyWith({
    List<CapturedImage>? images,
    BatchStatus? status,
  }) {
    return UploadBatch(
      id: id,
      createdAt: createdAt,
      images: images ?? this.images,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [id, createdAt, images, status];
}
