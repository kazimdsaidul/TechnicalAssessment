import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/model/captured_image.dart';
import '../../domain/model/upload_batch.dart';
import '../../domain/model/upload_status.dart';
import '../../domain/usecase/calculate_batch_progress.dart';
import 'upload_queue_cubit.dart';
import 'upload_queue_state.dart';

class UploadManagerScreen extends StatefulWidget {
  const UploadManagerScreen({super.key, required this.cubit});

  final UploadQueueCubit cubit;

  @override
  State<UploadManagerScreen> createState() => _UploadManagerScreenState();
}

class _UploadManagerScreenState extends State<UploadManagerScreen> {
  @override
  void initState() {
    super.initState();
    widget.cubit.start();
  }

  @override
  void dispose() {
    widget.cubit.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.cubit,
      child: Scaffold(
        appBar: AppBar(title: const Text('Upload Manager')),
        body: SafeArea(
          child: BlocBuilder<UploadQueueCubit, UploadQueueState>(
            builder: (context, state) {
              final images = state.batches.expand((batch) => batch.images).toList();
              final progress = CalculateBatchProgressUseCase().call(
                UploadBatch(id: 'all', createdAt: DateTime.now(), images: images),
              );
              return Column(
                children: [
                  _ProgressHeader(progress: progress),
                  Expanded(
                    child: images.isEmpty
                        ? const Center(
                            child: Text('No uploads yet', style: TextStyle(color: Colors.white54)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: images.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) => _UploadListItem(image: images[index]),
                          ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('START NEW UPLOAD BATCH'),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.progress});

  final BatchProgress progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.fractionSynced * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('BATCH SYNC PROGRESS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text('$percent%', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress.fractionSynced, minHeight: 6),
          ),
          const SizedBox(height: 8),
          Text(
            '${progress.synced}/${progress.total} synced'
            '${progress.failed > 0 ? ' · ${progress.failed} retrying' : ''}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _UploadListItem extends StatelessWidget {
  const _UploadListItem({required this.image});

  final CapturedImage image;

  String get _fileName => image.filePath.split(Platform.pathSeparator).last;

  (String, Color) get _statusLabel {
    switch (image.status) {
      case UploadStatus.pending:
        return ('WAITING FOR CONNECTION', Colors.orange);
      case UploadStatus.uploading:
        return ('UPLOADING...', Colors.blue);
      case UploadStatus.synced:
        return ('SYNCED', Colors.green);
      case UploadStatus.failed:
        return ('RETRYING (ATTEMPT ${image.retryCount})', Colors.redAccent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = _statusLabel;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Image.file(
                File(image.filePath),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: Colors.grey.shade700,
                  child: const Icon(Icons.insert_drive_file, color: Colors.white54),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fileName, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
