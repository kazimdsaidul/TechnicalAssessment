import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'data/local/hive_bootstrap.dart';
import 'data/local/hive_upload_queue_repository.dart';
import 'data/sync/background_sync_callback.dart';
import 'domain/repository/upload_queue_repository.dart';
import 'presentation/camera/camera_preview_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final box = await openUploadQueueBox();
  final repository = HiveUploadQueueRepository(box);

  await Workmanager().initialize(callbackDispatcher);

  runApp(CameraSyncApp(repository: repository));
}

class CameraSyncApp extends StatelessWidget {
  const CameraSyncApp({super.key, required this.repository});

  final UploadQueueRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera Sync',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      ),
      home: CameraPreviewScreen(repository: repository),
    );
  }
}
