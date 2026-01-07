import '../models/media_asset.dart';

abstract interface class MediaScanner {
  Future<List<MediaAsset>> scanAssets({DateTime? since});
}
