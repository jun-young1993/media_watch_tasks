import 'package:meta/meta.dart';

@immutable
class TaskManagerOptions {
  const TaskManagerOptions({
    this.batchSize = 3,
    this.lockTtl = const Duration(minutes: 10),
    this.maxRetries = 8,
    this.initialBackoff = const Duration(seconds: 30),
    this.maxBackoff = const Duration(hours: 6),
    this.enableHashDedup = false,
  });

  /// How many tasks to claim per processing run.
  final int batchSize;

  /// Lock expiration window for claimed tasks to avoid double-processing.
  final Duration lockTtl;

  final int maxRetries;

  final Duration initialBackoff;
  final Duration maxBackoff;

  /// If enabled, compute sha256 before upload and dedup by hash (best-effort).
  final bool enableHashDedup;
}


