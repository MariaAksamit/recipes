import 'dart:typed_data';

import 'package:wakelock_plus/wakelock_plus.dart';

/// Verzia pre Windows, Android a iOS. Úložisko prehliadača tu neexistuje –
/// recepty sú v súboroch (pozri RecipeStore) – takže WebDb sa tu nepoužíva.
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

Future<bool> saveFileTo(String fileName, Uint8List bytes, String mimeType) =>
    throw UnsupportedError('saveFileTo je len pre web');

/// Na Windows / Androide súbory nikto nemaže – netreba nič pýtať.
Future<bool> requestPersistentStorage() async => true;

Future<Uint8List> fetchBytes(String url) => throw UnsupportedError('fetchBytes je len pre web');

/// „Displej nezhasína“ počas varenia. Vo webovej verzii to rieši
/// web_platform_web.dart sám, tu to zariadi wakelock_plus.
class ScreenWakeLock {
  static Future<bool> enable() async {
    try {
      await WakelockPlus.enable();
      return await WakelockPlus.enabled;
    } catch (_) {
      // Keď to systém nedovolí, varenie beží ďalej, len displej zhasne.
      return false;
    }
  }

  static Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {
      // Nič – zámok sa uvoľní najneskôr pri zatvorení apky.
    }
  }
}
