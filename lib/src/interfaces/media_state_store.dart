import '../models/media_asset.dart';

abstract interface class MediaStateStore {
  Future<DateTime?> getLastScanCutoff();
  Future<void> setLastScanCutoff(DateTime cutoff);

  Future<bool> existsByAssetId(String assetId);

  /// Records that assets were seen in scan (and optionally updates their metadata).
  Future<void> upsertSeenAssets(List<MediaAsset> assets);

  Future<void> markUploaded({
    required String assetId,
    String? hash,
    DateTime? uploadedAt,
  });

  /// Optional stronger dedup: if hash exists and was already uploaded, skip.
  Future<bool> existsUploadedByHash(String hash);
}


