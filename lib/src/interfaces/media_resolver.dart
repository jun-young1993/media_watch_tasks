import '../models/resolved_media.dart';

abstract interface class MediaResolver {
  Future<ResolvedMedia?> resolveForUpload(String assetId);
}
