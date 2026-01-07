import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

Future<String> sha256ForBytes(Uint8List bytes) async {
  final digest = sha256.convert(bytes);
  return digest.toString();
}

Future<String> sha256ForFile(File file) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString();
}
