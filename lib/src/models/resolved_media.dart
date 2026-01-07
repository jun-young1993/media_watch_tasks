import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';

@immutable
class ResolvedMedia {
  const ResolvedMedia({
    required this.assetId,
    required this.createdAt,
    this.file,
    this.bytes,
    this.mimeType,
  }) : assert(file != null || bytes != null, 'Either file or bytes must exist.');

  final String assetId;
  final DateTime createdAt;

  /// May be null on iOS depending on PhotoKit export behavior.
  final File? file;

  /// Fallback bytes when file path is unavailable.
  final Uint8List? bytes;

  final String? mimeType;
}


