import 'dart:io';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'interfaces/logger.dart';
import 'interfaces/media_resolver.dart';
import 'interfaces/media_scanner.dart';
import 'interfaces/media_state_store.dart';
import 'interfaces/task_store.dart';
import 'interfaces/uploader.dart';
import 'models/media_asset.dart';
import 'models/task_models.dart';
import 'models/task_options.dart';
import 'utils/hash.dart';

class TaskManager {
  TaskManager({
    required this.mediaScanner,
    required this.mediaResolver,
    required this.mediaStateStore,
    required this.taskStore,
    required this.uploader,
    this.options = const TaskManagerOptions(),
    Logger? logger,
  }) : logger = logger ?? NoopLogger();

  final MediaScanner mediaScanner;
  final MediaResolver mediaResolver;
  final MediaStateStore mediaStateStore;
  final TaskStore taskStore;
  final Uploader uploader;
  final TaskManagerOptions options;
  final Logger logger;

  static const _uuid = Uuid();

  /// First-run setup: scans current library and stores assetIds + cutoff.
  ///
  /// This prevents mass-enqueue on later runs. It does NOT upload.
  Future<void> initializeBaseline() async {
    logger.info('initializeBaseline: start');
    final allAssets = await mediaScanner.scanAssets(since: null);
    await mediaStateStore.upsertSeenAssets(allAssets);

    final cutoff = _maxCreatedAt(allAssets) ?? DateTime.now();
    await mediaStateStore.setLastScanCutoff(cutoff);
    logger.info('initializeBaseline: stored baseline. assets=${allAssets.length} cutoff=$cutoff');
  }

  /// Scans and enqueues tasks for assets not in [MediaStateStore].
  Future<void> scanAndEnqueueNew() async {
    final lastCutoff = await mediaStateStore.getLastScanCutoff();
    logger.info('scanAndEnqueueNew: start cutoff=$lastCutoff');

    final assets = await mediaScanner.scanAssets(since: lastCutoff);
    if (assets.isEmpty) {
      await mediaStateStore.setLastScanCutoff(DateTime.now());
      logger.info('scanAndEnqueueNew: no assets. cutoff updated.');
      return;
    }

    final newlySeen = <MediaAsset>[];
    var enqueued = 0;

    for (final asset in assets) {
      final exists = await mediaStateStore.existsByAssetId(asset.assetId);
      newlySeen.add(asset);
      if (exists) continue;

      await taskStore.enqueueIfAbsent(assetId: asset.assetId, createdAt: asset.createdAt);
      enqueued += 1;
    }

    await mediaStateStore.upsertSeenAssets(newlySeen);
    await mediaStateStore.setLastScanCutoff(_maxCreatedAt(assets) ?? DateTime.now());

    logger.info('scanAndEnqueueNew: scanned=${assets.length} enqueued=$enqueued');
  }

  Future<void> process() async {
    final now = DateTime.now();
    final lockId = _uuid.v4();
    final tasks = await taskStore.claimBatch(
      limit: options.batchSize,
      lockTtl: options.lockTtl,
      lockId: lockId,
      now: now,
    );

    if (tasks.isEmpty) {
      logger.debug('process: no runnable tasks');
      return;
    }

    logger.info('process: claimed=${tasks.length} lockId=$lockId');
    for (final task in tasks) {
      await _processOne(task: task, now: DateTime.now());
    }
  }

  Future<void> _processOne({required UploadTask task, required DateTime now}) async {
    try {
      final resolved = await mediaResolver.resolveForUpload(task.assetId);
      if (resolved == null) {
        await _fail(task: task, now: now, error: 'asset_not_found');
        return;
      }

      final hash = options.enableHashDedup ? await _computeHash(resolved.file, resolved.bytes) : null;
      if (hash != null) {
        final alreadyUploaded = await mediaStateStore.existsUploadedByHash(hash);
        if (alreadyUploaded) {
          logger.info('process: dedup by hash (skip upload). assetId=${task.assetId}');
          await mediaStateStore.markUploaded(assetId: task.assetId, hash: hash, uploadedAt: now);
          await taskStore.markSuccess(taskId: task.taskId, now: now);
          return;
        }
      }

      final result = await uploader.upload(resolved);
      if (result.isSuccess) {
        await mediaStateStore.markUploaded(assetId: task.assetId, hash: hash, uploadedAt: now);
        await taskStore.markSuccess(taskId: task.taskId, now: now);
        logger.info('process: success assetId=${task.assetId}');
        return;
      }

      await _fail(task: task, now: now, error: result.error ?? 'upload_failed');
    } catch (e, st) {
      logger.error('process: exception assetId=${task.assetId}', error: e, stackTrace: st);
      await _fail(task: task, now: now, error: e.toString());
    }
  }

  Future<void> _fail({required UploadTask task, required DateTime now, required String error}) async {
    final nextRetry = task.retryCount + 1;
    final isExhausted = nextRetry > options.maxRetries;
    final backoff = _computeBackoff(nextRetry);
    final nextRunAt = isExhausted ? now.add(options.maxBackoff) : now.add(backoff);

    await taskStore.markFailed(
      taskId: task.taskId,
      error: isExhausted ? 'max_retries_exceeded: $error' : error,
      retryCount: nextRetry,
      nextRunAt: nextRunAt,
      now: now,
    );
  }

  Duration _computeBackoff(int retryCount) {
    if (retryCount <= 0) return options.initialBackoff;
    final multiplier = 1 << (retryCount - 1);
    final candidate = options.initialBackoff * multiplier;
    if (candidate > options.maxBackoff) return options.maxBackoff;
    return candidate;
  }
}

DateTime? _maxCreatedAt(List<MediaAsset> assets) {
  if (assets.isEmpty) return null;
  var max = assets.first.createdAt;
  for (final a in assets.skip(1)) {
    if (a.createdAt.isAfter(max)) max = a.createdAt;
  }
  return max;
}

Future<String?> _computeHash(File? file, Uint8List? bytes) async {
  if (bytes != null) return sha256ForBytes(bytes);
  if (file != null) return sha256ForFile(file);
  return null;
}


