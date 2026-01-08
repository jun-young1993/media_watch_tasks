import 'package:flutter/material.dart';
import 'package:background_fetch/background_fetch.dart';
import 'package:media_watch_tasks/media_watch_tasks.dart';

@pragma('vm:entry-point')
void backgroundFetchHeadlessTask(HeadlessTask task) async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = MediaWatchDatabase();
  final taskManager = TaskManager(
    mediaScanner: PhotoManagerMediaScanner(),
    mediaResolver: PhotoManagerMediaResolver(),
    mediaStateStore: DriftMediaStateStore(db),
    taskStore: DriftTaskStore(db),
    uploader: _MockUploader(),
    options: const TaskManagerOptions(batchSize: 2),
    logger: const ConsoleLogger(),
  );

  try {
    await taskManager.scanAndEnqueueNew();
    await taskManager.process();
  } finally {
    await db.close();
  }

  BackgroundFetch.finish(task.taskId);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final MediaWatchDatabase _db;
  late final TaskManager _taskManager;
  late final BackgroundFetchScheduler _scheduler;
  String _status = 'idle';

  @override
  void initState() {
    super.initState();
    _db = MediaWatchDatabase();
    _taskManager = TaskManager(
      mediaScanner: PhotoManagerMediaScanner(),
      mediaResolver: PhotoManagerMediaResolver(),
      mediaStateStore: DriftMediaStateStore(_db),
      taskStore: DriftTaskStore(_db),
      uploader: _MockUploader(),
      options: const TaskManagerOptions(batchSize: 2),
      logger: const ConsoleLogger(),
    );
    _scheduler = BackgroundFetchScheduler(
      onFetch: () async {
        await _taskManager.scanAndEnqueueNew();
        await _taskManager.process();
      },
      logger: const ConsoleLogger(),
    );
  }

  @override
  void dispose() {
    _scheduler.stop();
    _db.close();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _status = 'running...');
    try {
      await fn();
      setState(() => _status = 'done');
    } catch (e) {
      setState(() => _status = 'error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'media_watch_tasks example',
      home: Scaffold(
        appBar: AppBar(title: const Text('media_watch_tasks example')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Status: $_status'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _run(_scheduler.start),
                child: const Text('0) Start background_fetch scheduler'),
              ),
              ElevatedButton(
                onPressed: () => _run(_taskManager.initializeBaseline),
                child: const Text('1) Initialize baseline (no upload)'),
              ),
              ElevatedButton(
                onPressed: () => _run(_taskManager.scanAndEnqueueNew),
                child: const Text('2) Scan & enqueue new assets'),
              ),
              ElevatedButton(
                onPressed: () => _run(_taskManager.process),
                child: const Text('3) Process task queue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MockUploader implements Uploader {
  @override
  Future<UploadResult> upload(ResolvedMedia media) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return const UploadResult.success(remoteId: 'mock');
  }
}
