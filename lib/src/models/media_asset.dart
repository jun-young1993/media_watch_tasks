import 'package:meta/meta.dart';

@immutable
class MediaAsset {
  const MediaAsset({
    required this.assetId,
    required this.createdAt,
    this.hash,
  });

  /// OS-provided stable identifier for the media asset.
  final String assetId;

  /// When the asset was created (capture time when available).
  final DateTime createdAt;

  /// Optional content hash (e.g. sha256) for stronger dedup.
  final String? hash;
}
