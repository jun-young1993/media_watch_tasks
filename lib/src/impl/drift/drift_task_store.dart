import '../../interfaces/task_store.dart';
import '../../models/task_models.dart';
import '../../utils/time.dart';
import 'drift_database.dart';
import 'package:drift/drift.dart';

class DriftTaskStore implements TaskStore {
  DriftTaskStore(this.db);

  final MediaWatchDatabase db;

  @override
  Future<void> enqueueIfAbsent({
    required String assetId,
    required DateTime createdAt,
  }) async {
    final nowMs = dateTimeToUtcMs(DateTime.now());
    await db.into(db.uploadTaskRows).insert(
          UploadTaskRowsCompanion.insert(
            assetId: assetId,
            createdAtMsUtc: dateTimeToUtcMs(createdAt),
            updatedAtMsUtc: nowMs,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  @override
  Future<List<UploadTask>> claimBatch({
    required int limit,
    required Duration lockTtl,
    required String lockId,
    required DateTime now,
  }) async {
    final nowMs = dateTimeToUtcMs(now);
    final expiredBeforeMs = dateTimeToUtcMs(now.subtract(lockTtl));

    return db.transaction(() async {
      final candidates = await (db.select(db.uploadTaskRows)
            ..where((t) {
              final isRunnable = t.status.equals('pending') |
                  (t.status.equals('failed') &
                      (t.nextRunAtMsUtc.isNull() | t.nextRunAtMsUtc.isSmallerOrEqualValue(nowMs)));

              final isUnlocked = t.lockedAtMsUtc.isNull() | t.lockedAtMsUtc.isSmallerOrEqualValue(expiredBeforeMs);
              return isRunnable & isUnlocked;
            })
            ..orderBy([(t) => OrderingTerm.asc(t.createdAtMsUtc)])
            ..limit(limit))
          .get();

      final claimed = <UploadTask>[];
      for (final row in candidates) {
        final updated = await (db.update(db.uploadTaskRows)
              ..where((t) {
                final isSame = t.id.equals(row.id);
                final isUnlocked = t.lockedAtMsUtc.isNull() | t.lockedAtMsUtc.isSmallerOrEqualValue(expiredBeforeMs);
                final isClaimable = t.status.equals('pending') | t.status.equals('failed');
                return isSame & isUnlocked & isClaimable;
              }))
            .write(
          UploadTaskRowsCompanion(
            status: const Value('uploading'),
            lockedAtMsUtc: Value(nowMs),
            lockId: Value(lockId),
            updatedAtMsUtc: Value(nowMs),
          ),
        );

        if (updated == 1) claimed.add(_toModel(row, statusOverride: UploadTaskStatus.uploading));
      }

      return claimed;
    });
  }

  @override
  Future<void> markSuccess({
    required int taskId,
    required DateTime now,
  }) async {
    final nowMs = dateTimeToUtcMs(now);
    await (db.update(db.uploadTaskRows)..where((t) => t.id.equals(taskId))).write(
      UploadTaskRowsCompanion(
        status: const Value('success'),
        nextRunAtMsUtc: const Value(null),
        lockedAtMsUtc: const Value(null),
        lockId: const Value(null),
        lastError: const Value(null),
        updatedAtMsUtc: Value(nowMs),
      ),
    );
  }

  @override
  Future<void> markFailed({
    required int taskId,
    required String error,
    required int retryCount,
    required DateTime nextRunAt,
    required DateTime now,
  }) async {
    final nowMs = dateTimeToUtcMs(now);
    await (db.update(db.uploadTaskRows)..where((t) => t.id.equals(taskId))).write(
      UploadTaskRowsCompanion(
        status: const Value('failed'),
        retryCount: Value(retryCount),
        nextRunAtMsUtc: Value(dateTimeToUtcMs(nextRunAt)),
        lockedAtMsUtc: const Value(null),
        lockId: const Value(null),
        lastError: Value(error),
        updatedAtMsUtc: Value(nowMs),
      ),
    );
  }

  UploadTask _toModel(UploadTaskRow row, {UploadTaskStatus? statusOverride}) {
    return UploadTask(
      taskId: row.id,
      assetId: row.assetId,
      createdAt: dateTimeFromMs(row.createdAtMsUtc),
      status: statusOverride ?? _statusFromString(row.status),
      retryCount: row.retryCount,
      nextRunAt: row.nextRunAtMsUtc == null ? null : dateTimeFromMs(row.nextRunAtMsUtc!),
      lastError: row.lastError,
    );
  }
}

UploadTaskStatus _statusFromString(String value) {
  switch (value) {
    case 'pending':
      return UploadTaskStatus.pending;
    case 'uploading':
      return UploadTaskStatus.uploading;
    case 'success':
      return UploadTaskStatus.success;
    case 'failed':
      return UploadTaskStatus.failed;
  }
  return UploadTaskStatus.failed;
}


