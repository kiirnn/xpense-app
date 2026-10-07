import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Native save/open dialogs (Android Storage Access Framework). See MainActivity.kt.
class DeviceFiles {
  static const _ch = MethodChannel('xpense/files');

  static bool get supported => Platform.isAndroid;

  /// Returns true if saved, false if the user cancelled.
  static Future<bool> save(String name, String content, String mime) async {
    final ok = await _ch.invokeMethod<bool>('save', {
      'name': name,
      'mime': mime,
      'bytes': Uint8List.fromList(utf8.encode(content)),
    });
    return ok ?? false;
  }

  /// Returns the file's text, or null if the user cancelled.
  static Future<String?> open() => _ch.invokeMethod<String>('open');
}
