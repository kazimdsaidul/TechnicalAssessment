import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repository/upload_queue_repository.dart';
import 'upload_queue_state.dart';

/// Drives the Upload Manager screen by polling [UploadQueueRepository] on a
/// timer while active. Hive's `box.watch()` only notifies within the
/// isolate that's listening, and the `workmanager` background isolate
/// writes retry results from a separate one — so there's no push
/// notification across isolates. Polling on a short interval while this
/// screen is visible is the simplest way to pick up those writes. See
/// design.md.
class UploadQueueCubit extends Cubit<UploadQueueState> {
  UploadQueueCubit({
    required this.repository,
    this.pollInterval = const Duration(seconds: 1),
  }) : super(const UploadQueueState());

  final UploadQueueRepository repository;
  final Duration pollInterval;
  Timer? _timer;

  Future<void> start() async {
    await _refresh();
    _timer ??= Timer.periodic(pollInterval, (_) => _refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _refresh() async {
    final batches = await repository.getAllBatches();
    emit(UploadQueueState(batches: batches));
  }

  @override
  Future<void> close() {
    stop();
    return super.close();
  }
}
