import '../models/task_models.dart';

abstract interface class TaskStore {
  Future<void> enqueueIfAbsent({
    required String assetId,
    required DateTime createdAt,
  });

  /// Claim tasks for processing. Should set status to uploading and lock them.
  Future<List<UploadTask>> claimBatch({
    required int limit,
    required Duration lockTtl,
    required String lockId,
    required DateTime now,
  });

  Future<void> markSuccess({
    required int taskId,
    required DateTime now,
  });

  Future<void> markFailed({
    required int taskId,
    required String error,
    required int retryCount,
    required DateTime nextRunAt,
    required DateTime now,
  });
}


