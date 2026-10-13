import 'package:equatable/equatable.dart';

import '../../domain/model/upload_batch.dart';

class UploadQueueState extends Equatable {
  const UploadQueueState({this.batches = const []});

  final List<UploadBatch> batches;

  @override
  List<Object?> get props => [batches];
}
