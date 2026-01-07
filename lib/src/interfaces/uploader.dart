import '../models/resolved_media.dart';
import '../models/task_models.dart';

abstract interface class Uploader {
  Future<UploadResult> upload(ResolvedMedia media);
}


