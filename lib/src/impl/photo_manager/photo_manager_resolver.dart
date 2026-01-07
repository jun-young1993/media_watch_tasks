import 'package:photo_manager/photo_manager.dart';

import '../../interfaces/media_resolver.dart';
import '../../models/resolved_media.dart';

class PhotoManagerMediaResolver implements MediaResolver {
  @override
  Future<ResolvedMedia?> resolveForUpload(String assetId) async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      throw StateError('photo_permission_denied');
    }

    final entity = await AssetEntity.fromId(assetId);
    if (entity == null) return null;

    final file = await entity.file;
    final bytes = file == null ? await entity.originBytes : null;

    if (file == null && bytes == null) return null;

    return ResolvedMedia(
      assetId: entity.id,
      createdAt: entity.createDateTime,
      file: file,
      bytes: bytes,
      mimeType: entity.mimeType,
    );
  }
}


