import 'package:hive/hive.dart';

import '../../domain/model/captured_image.dart';
import '../../domain/model/upload_batch.dart';
import '../../domain/model/upload_status.dart';

/// Hand-written Hive adapters (not `hive_generator`/codegen): the generator
/// package's `analyzer` constraint is incompatible with `bloc_test`'s, and
/// these models are small enough that writing the adapters by hand — the
/// same shape Hive's own generator would produce — is simpler than forcing
/// a dependency resolution around the conflict. See design.md.

const uploadStatusTypeId = 0;
const batchStatusTypeId = 1;
const capturedImageTypeId = 2;
const uploadBatchTypeId = 3;

class UploadStatusAdapter extends TypeAdapter<UploadStatus> {
  @override
  final int typeId = uploadStatusTypeId;

  @override
  UploadStatus read(BinaryReader reader) => UploadStatus.values[reader.readByte()];

  @override
  void write(BinaryWriter writer, UploadStatus obj) => writer.writeByte(obj.index);
}

class BatchStatusAdapter extends TypeAdapter<BatchStatus> {
  @override
  final int typeId = batchStatusTypeId;

  @override
  BatchStatus read(BinaryReader reader) => BatchStatus.values[reader.readByte()];

  @override
  void write(BinaryWriter writer, BatchStatus obj) => writer.writeByte(obj.index);
}

class CapturedImageAdapter extends TypeAdapter<CapturedImage> {
  @override
  final int typeId = capturedImageTypeId;

  @override
  CapturedImage read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return CapturedImage(
      id: fields[0] as String,
      batchId: fields[1] as String,
      filePath: fields[2] as String,
      status: fields[3] as UploadStatus,
      retryCount: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CapturedImage obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.batchId)
      ..writeByte(2)
      ..write(obj.filePath)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.retryCount);
  }
}

class UploadBatchAdapter extends TypeAdapter<UploadBatch> {
  @override
  final int typeId = uploadBatchTypeId;

  @override
  UploadBatch read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return UploadBatch(
      id: fields[0] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[1] as int),
      images: (fields[2] as List).cast<CapturedImage>(),
      status: fields[3] as BatchStatus,
    );
  }

  @override
  void write(BinaryWriter writer, UploadBatch obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.createdAt.millisecondsSinceEpoch)
      ..writeByte(2)
      ..write(obj.images)
      ..writeByte(3)
      ..write(obj.status);
  }
}

/// Registers all adapters for this app's Hive types. Safe to call more than
/// once per isolate (each registration is guarded).
void registerHiveAdapters() {
  if (!Hive.isAdapterRegistered(uploadStatusTypeId)) {
    Hive.registerAdapter(UploadStatusAdapter());
  }
  if (!Hive.isAdapterRegistered(batchStatusTypeId)) {
    Hive.registerAdapter(BatchStatusAdapter());
  }
  if (!Hive.isAdapterRegistered(capturedImageTypeId)) {
    Hive.registerAdapter(CapturedImageAdapter());
  }
  if (!Hive.isAdapterRegistered(uploadBatchTypeId)) {
    Hive.registerAdapter(UploadBatchAdapter());
  }
}
