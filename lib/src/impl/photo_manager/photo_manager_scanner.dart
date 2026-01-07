import 'package:photo_manager/photo_manager.dart';

import '../../interfaces/media_scanner.dart';
import '../../models/media_asset.dart';

class PhotoManagerMediaScanner implements MediaScanner {
  PhotoManagerMediaScanner({this.pageSize = 200});

  final int pageSize;

  @override
  Future<List<MediaAsset>> scanAssets({DateTime? since}) async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      throw StateError('photo_permission_denied');
    }

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
      onlyAll: true,
    );

    if (paths.isEmpty) return const [];

    final allPath = paths.first;
    final out = <MediaAsset>[];

    var page = 0;
    while (true) {
      final pageAssets = await allPath.getAssetListPaged(page: page, size: pageSize);
      if (pageAssets.isEmpty) break;

      var shouldStop = false;
      for (final asset in pageAssets) {
        final createdAt = asset.createDateTime;
        if (since != null && !createdAt.isAfter(since)) {
          shouldStop = true;
          break;
        }

        out.add(MediaAsset(assetId: asset.id, createdAt: createdAt));
      }

      if (shouldStop) break;
      page += 1;
    }

    return out;
  }
}


