import 'dart:typed_data';

/// Náhrada pre Windows / Android / iOS – tieto triedy sa tam nepoužívajú.
class WebDb {
  static Future<WebDb> open() => throw UnsupportedError('WebDb je len pre web');

  Future<String?> getText(String key) => throw UnsupportedError('web');
  Future<Uint8List?> getBytes(String key) => throw UnsupportedError('web');
  Future<List<String>> keys() => throw UnsupportedError('web');
  Future<void> putText(String key, String value) => throw UnsupportedError('web');
  Future<void> putBytes(String key, Uint8List value) => throw UnsupportedError('web');
  Future<void> delete(String key) => throw UnsupportedError('web');
}

void downloadFile(String fileName, Uint8List bytes, String mimeType) =>
    throw UnsupportedError('downloadFile je len pre web');

Future<Uint8List> fetchBytes(String url) => throw UnsupportedError('fetchBytes je len pre web');

class ScreenWakeLock {
  static Future<bool> enable() async => false;
  static Future<void> disable() async {}
}
