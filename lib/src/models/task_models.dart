import 'package:meta/meta.dart';

enum UploadTaskStatus {
  pending,
  uploading,
  success,
  failed,
}

@immutable
class UploadTask {
  const UploadTask({
    required this.taskId,
    required this.assetId,
    required this.createdAt,
    required this.status,
    required this.retryCount,
    this.nextRunAt,
    this.lastError,
  });

  final int taskId;
  final String assetId;
  final DateTime createdAt;
  final UploadTaskStatus status;
  final int retryCount;
  final DateTime? nextRunAt;
  final String? lastError;
}

@immutable
class UploadResult {
  const UploadResult.success({this.remoteId}) : isSuccess = true, error = null;
  const UploadResult.failure(this.error) : isSuccess = false, remoteId = null;

  final bool isSuccess;
  final String? remoteId;
  final String? error;
}


