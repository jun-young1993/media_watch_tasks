import '../../interfaces/media_state_store.dart';
import '../../models/media_asset.dart';
import '../../utils/time.dart';
import 'drift_database.dart';
import 'package:drift/drift.dart';

class DriftMediaStateStore implements MediaStateStore {
  DriftMediaStateStore(this.db);

  final MediaWatchDatabase db;

  static const _lastScanCutoffKey = 'last_scan_cutoff_ms_utc';

  @override
  Future<bool> existsByAssetId(String assetId) async {
    final row = await (db.select(db.mediaStates)
          ..where((t) => t.assetId.equals(assetId)))
        .getSingleOrNull();
    return row != null;
  }

  @override
  Future<bool> existsUploadedByHash(String hash) async {
    final row = await (db.select(db.mediaStates)
          ..where((t) => t.hash.equals(hash) & t.uploaded.equals(true)))
        .getSingleOrNull();
    return row != null;
  }

  @override
  Future<DateTime?> getLastScanCutoff() async {
    final row = await (db.select(db.appMeta)
          ..where((t) => t.key.equals(_lastScanCutoffKey)))
        .getSingleOrNull();
    if (row == null) return null;
    final ms = int.tryParse(row.value);
    if (ms == null) return null;
    return dateTimeFromMs(ms);
  }

  @override
  Future<void> setLastScanCutoff(DateTime cutoff) async {
    final ms = dateTimeToUtcMs(cutoff).toString();
    await db.into(db.appMeta).insertOnConflictUpdate(
        AppMetaCompanion.insert(key: _lastScanCutoffKey, value: ms));
  }

  @override
  Future<void> upsertSeenAssets(List<MediaAsset> assets) async {
    if (assets.isEmpty) return;
    final nowMs = dateTimeToUtcMs(DateTime.now());
    await db.transaction(() async {
      for (final asset in assets) {
        final existing = await (db.select(db.mediaStates)
              ..where((t) => t.assetId.equals(asset.assetId)))
            .getSingleOrNull();

        if (existing == null) {
          await db.into(db.mediaStates).insert(
                MediaStatesCompanion.insert(
                  assetId: asset.assetId,
                  createdAtMsUtc: dateTimeToUtcMs(asset.createdAt),
                  hash: asset.hash == null
                      ? const Value.absent()
                      : Value(asset.hash),
                  firstSeenAtMsUtc: nowMs,
                ),
              );
          continue;
        }

        await (db.update(db.mediaStates)
              ..where((t) => t.assetId.equals(asset.assetId)))
            .write(
          MediaStatesCompanion(
            createdAtMsUtc: Value(dateTimeToUtcMs(asset.createdAt)),
            hash: asset.hash == null ? const Value.absent() : Value(asset.hash),
          ),
        );
      }
    });
  }

  @override
  Future<void> markUploaded({
    required String assetId,
    String? hash,
    DateTime? uploadedAt,
  }) async {
    final uploadedAtMs = dateTimeToUtcMs(uploadedAt ?? DateTime.now());
    await (db.update(db.mediaStates)..where((t) => t.assetId.equals(assetId)))
        .write(
      MediaStatesCompanion(
        uploaded: const Value(true),
        uploadedAtMsUtc: Value(uploadedAtMs),
        hash: hash == null ? const Value.absent() : Value(hash),
      ),
    );
  }
}
