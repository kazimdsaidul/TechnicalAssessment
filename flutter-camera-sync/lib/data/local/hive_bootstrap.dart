import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/model/upload_batch.dart';
import 'hive_adapters.dart';

const uploadBatchesBoxName = 'upload_batches';

/// Opens the upload-queue box, initializing Hive's Flutter bindings first.
/// Must be called independently in every isolate that touches this box —
/// the UI isolate (in `main.dart`) and the `workmanager` background
/// isolate each need their own call, since they don't share memory.
Future<Box<UploadBatch>> openUploadQueueBox() async {
  await Hive.initFlutter();
  registerHiveAdapters();
  return Hive.openBox<UploadBatch>(uploadBatchesBoxName);
}
