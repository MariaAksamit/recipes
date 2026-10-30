// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

const _dbName = 'recepty';
const _storeName = 'kv';

/// Jednoduché úložisko kľúč → hodnota v prehliadači (IndexedDB).
/// Zmestia sa sem aj fotky (na rozdiel od localStorage).
///
/// Safari zatvára spojenie s IndexedDB, keď stránka odíde na pozadie – čo sa
/// stane napríklad pri výbere súboru zo Súborov. Po návrate potom každá
/// transakcia skončí chybou „the database connection is closing“. Preto si
/// spojenie nedržíme natvrdo: keď sa zatvorí, otvorí sa znova a operácia
/// zopakuje.
class WebDb {
  web.IDBDatabase? _db;

  WebDb._();

  static Future<WebDb> open() async {
    final db = WebDb._();
    await db._connection(); // overí, že prehliadač úložisko vôbec dovolí
    return db;
  }

  Future<web.IDBDatabase> _connection() async {
    final current = _db;
    if (current != null) return current;
    final req = web.window.indexedDB.open(_dbName, 1);
    req.onupgradeneeded = ((web.Event _) {
      final db = req.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains(_storeName)) {
        db.createObjectStore(_storeName);
      }
    }).toJS;
    final db = await _request(req) as web.IDBDatabase;
    // Keď prehliadač spojenie zavrie, nabudúce si otvoríme nové.
    db.addEventListener('close', ((web.Event _) { _db = null; }).toJS);
    _db = db;
    return db;
  }

  /// Spustí operáciu; pri zatvorenom spojení ho otvorí znova a skúsi raz ešte.
  Future<T> _run<T>(Future<T> Function(web.IDBDatabase db) op) async {
    try {
      return await op(await _connection());
    } catch (e) {
      if (!_connectionClosed(e)) rethrow;
      _db = null;
      return await op(await _connection());
    }
  }

  static bool _connectionClosed(Object e) {
    final m = e.toString().toLowerCase();
    return m.contains('invalidstateerror') || m.contains('connection is closing');
  }

  Future<JSAny?> _get(String key) => _run((db) async {
    final tx = db.transaction(_storeName.toJS, 'readonly');
    return _request(tx.objectStore(_storeName).get(key.toJS));
  });

  Future<String?> getText(String key) async {
    final r = await _get(key);
    if (r.isUndefinedOrNull) return null;
    return (r as JSString).toDart;
  }

  Future<Uint8List?> getBytes(String key) async {
    final r = await _get(key);
    if (r.isUndefinedOrNull) return null;
    return (r as JSUint8Array).toDart;
  }

  Future<List<String>> keys() => _run((db) async {
    final tx = db.transaction(_storeName.toJS, 'readonly');
    final r = await _request(tx.objectStore(_storeName).getAllKeys());
    if (r.isUndefinedOrNull) return <String>[];
    return (r as JSArray<JSString>).toDart.map((k) => k.toDart).toList();
  });

  Future<void> putText(String key, String value) =>
      _write((s) => s.put(value.toJS, key.toJS));

  Future<void> putBytes(String key, Uint8List value) =>
      _write((s) => s.put(value.toJS, key.toJS));

  Future<void> delete(String key) => _write((s) => s.delete(key.toJS));

  /// Zápis je hotový, až keď prehliadač potvrdí celú transakciu.
  Future<void> _write(void Function(web.IDBObjectStore store) op) => _run((db) {
    final c = Completer<void>();
    final tx = db.transaction(_storeName.toJS, 'readwrite');
    tx.oncomplete = ((web.Event _) {
      if (!c.isCompleted) c.complete();
    }).toJS;
    tx.onerror = ((web.Event _) {
      if (!c.isCompleted) c.completeError(StateError(tx.error?.message ?? 'Chyba úložiska'));
    }).toJS;
    tx.onabort = ((web.Event _) {
      if (!c.isCompleted) c.completeError(StateError(tx.error?.message ?? 'Zápis bol zrušený'));
    }).toJS;
    op(tx.objectStore(_storeName));
    return c.future;
  });
}

Future<JSAny?> _request(web.IDBRequest req) {
  final c = Completer<JSAny?>();
  req.onsuccess = ((web.Event _) {
    if (!c.isCompleted) c.complete(req.result);
  }).toJS;
  req.onerror = ((web.Event _) {
    if (!c.isCompleted) c.completeError(StateError(req.error?.message ?? 'Chyba úložiska'));
  }).toJS;
  return c.future;
}

/// Uloží súbor do zariadenia – prehliadač ho stiahne medzi Stiahnuté súbory
/// (na iPhone sa ponúkne „Uložiť do Súborov“).
void downloadFile(String fileName, Uint8List bytes, String mimeType) {
  final blob = web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final a = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body!.appendChild(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}

/// Stiahne obsah adresy priamo prehliadačom. Väčšina stránok to cudzej
/// aplikácii nepovolí (ochrana CORS) – vtedy to skončí chybou.
Future<Uint8List> fetchBytes(String url) async {
  final res = await web.window.fetch(url.toJS).toDart;
  if (!res.ok) throw StateError('HTTP ${res.status}');
  final buffer = await res.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}

/// „Displej nezhasína“ počas varenia (Screen Wake Lock API).
/// Keď sa prepneš do inej aplikácie, prehliadač zámok uvoľní –
/// po návrate ho znova zapneme.
class ScreenWakeLock {
  static web.WakeLockSentinel? _sentinel;
  static bool _wanted = false;
  static JSFunction? _onVisibility;

  /// Vráti false, ak to prehliadač nepodporuje.
  static Future<bool> enable() async {
    _wanted = true;
    if (_onVisibility == null) {
      _onVisibility = ((web.Event _) {
        if (_wanted && web.document.visibilityState == 'visible') _acquire();
      }).toJS;
      web.document.addEventListener('visibilitychange', _onVisibility);
    }
    return _acquire();
  }

  static Future<bool> _acquire() async {
    try {
      _sentinel = await web.window.navigator.wakeLock.request('screen').toDart;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> disable() async {
    _wanted = false;
    final s = _sentinel;
    _sentinel = null;
    try {
      if (s != null && !s.released) await s.release().toDart;
    } catch (_) {}
  }
}
