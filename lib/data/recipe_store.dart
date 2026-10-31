import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../models/recipe.dart';
import 'platform/photo_resize.dart';
import 'platform/web_platform.dart';

/// Uchováva recepty lokálne v zariadení (súbor recipes.json + priečinok s fotkami).
///
/// Pri prvom spustení sa recepty načítajú z assets/recipes.json.
///
/// Vo webovej verzii (iPhone) sa namiesto súborov používa úložisko
/// prehliadača (IndexedDB) – recepty pod kľúčom `recipes`, fotky pod `img:<názov>`.
class RecipeStore extends ChangeNotifier {
  final List<Recipe> _recipes = [];
  late Directory _dir;
  late Directory _imagesDir;
  bool loaded = false;

  /// Nastaví sa, keď sa uložené recepty nepodarilo prečítať. Pôvodný súbor
  /// zostane odložený vedľa (recepty-poskodene-*.json) a apka naštartuje
  /// s predvolenými receptami, nech sa nezasekne na úvodnej obrazovke.
  bool loadFailed = false;

  /// Názvy fotiek, ktoré naozaj existujú. Drží sa v pamäti, aby sa pri
  /// kreslení zoznamu nemusel pre každú dlaždicu čítať disk.
  final Set<String> _imageNames = {};

  // ---- len web
  static const _kRecipes = 'recipes';
  static const _kImagePrefix = 'img:';
  static const _kBackupDate = 'meta:backupDate';
  WebDb? _web; // null, ak prehliadač úložisko nepovolí
  /// Fotky držané len v pamäti – použijú sa, keď prehliadač úložisko nepovolí.
  final Map<String, Uint8List> _webMemory = {};

  /// Web: dátum zálohy, ktorá bola naposledy načítaná (null = ešte žiadna).
  DateTime? lastBackupDate;

  /// Jazyk aplikácie: 'sk' alebo 'en'. Mení sa cez [setLanguage].
  /// Kým si jazyk nezmeníš, riadi sa jazykom zariadenia (slovenčina/čeština → SK, inak EN).
  final ValueNotifier<String> language = ValueNotifier(_deviceLanguage());

  static String _deviceLanguage() {
    final code = PlatformDispatcher.instance.locale.languageCode;
    return (code == 'sk' || code == 'cs') ? 'sk' : 'en';
  }

  Future<void> setLanguage(String code) async {
    if (language.value == code) return;
    language.value = code;
    await _writeSetting('language', code);
  }

  /// Vzhľad aplikácie: 'system' (podľa zariadenia), 'light' alebo 'dark'.
  /// Ukladá sa ako text, aby dátová vrstva nemusela poznať widgety.
  final ValueNotifier<String> theme = ValueNotifier('system');

  static const themeOptions = ['system', 'light', 'dark'];

  Future<void> setTheme(String mode) async {
    if (theme.value == mode || !themeOptions.contains(mode)) return;
    theme.value = mode;
    await _writeSetting('theme', mode);
  }

  List<Recipe> get recipes => List.unmodifiable(_recipes);

  File get _dataFile => File('${_dir.path}${Platform.pathSeparator}recipes.json');

  Future<void> load() async {
    try {
      if (kIsWeb) {
        await _openWeb();
      } else {
        final base = await getApplicationSupportDirectory();
        _dir = Directory('${base.path}${Platform.pathSeparator}recepty');
        _imagesDir = Directory('${_dir.path}${Platform.pathSeparator}fotky');
        await _imagesDir.create(recursive: true);
        await _indexImages();
      }

      final lang = await _readSetting('language');
      if (lang == 'sk' || lang == 'en') language.value = lang!; // tvoja voľba
      final mode = await _readSetting('theme');
      if (mode != null && themeOptions.contains(mode)) theme.value = mode;

      final stored = await _readData();
      if (stored != null) {
        _replaceAll(stored);
      } else {
        await _loadDefaults();
        await _save();
      }
    } catch (e) {
      // Poškodený alebo nečitateľný súbor nesmie apku zablokovať na úvodnej
      // obrazovke. Odložíme ho bokom a pokračujeme s predvolenými receptami.
      debugPrint('Recepty sa nepodarilo načítať: $e');
      loadFailed = true;
      await _setAsideBrokenData();
      try {
        await _loadDefaults();
      } catch (e2) {
        debugPrint('Ani predvolené recepty sa nepodarilo načítať: $e2');
        _recipes.clear();
      }
    } finally {
      loaded = true;
      notifyListeners();
    }
  }

  void _replaceAll(String json) {
    final data = jsonDecode(json) as List;
    _recipes
      ..clear()
      ..addAll(data.map((e) => Recipe.fromJson(e as Map<String, dynamic>)));
  }

  /// Premenuje nečitateľný súbor s receptami, nech sa dá ešte zachrániť.
  Future<void> _setAsideBrokenData() async {
    if (kIsWeb) return;
    try {
      if (!await _dataFile.exists()) return;
      final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      await _dataFile.rename('${_dir.path}${Platform.pathSeparator}recepty-poskodene-$stamp.json');
    } catch (e) {
      debugPrint('Poškodený súbor sa nepodarilo odložiť: $e');
    }
  }

  // ------------------------------------------- úložisko (súbory / prehliadač)

  /// Raz pri štarte si zapíše, ktoré fotky v priečinku naozaj sú.
  Future<void> _indexImages() async {
    _imageNames.clear();
    try {
      await for (final e in _imagesDir.list()) {
        if (e is File) _imageNames.add(e.uri.pathSegments.last);
      }
    } catch (e) {
      debugPrint('Priečinok s fotkami sa nepodarilo prečítať: $e');
    }
  }

  Future<void> _openWeb() async {
    try {
      // Nech prehliadač recepty nezmaže sám od seba (pozri
      // requestPersistentStorage). Keď nepovolí, apka beží ďalej.
      await requestPersistentStorage();
      final db = await WebDb.open();
      // Čítajú sa len názvy – bajty sa načítajú, až keď fotku treba vykresliť.
      for (final k in await db.keys()) {
        if (k.startsWith(_kImagePrefix)) {
          _imageNames.add(k.substring(_kImagePrefix.length));
        }
      }
      final d = await db.getText(_kBackupDate);
      lastBackupDate = d == null ? null : DateTime.tryParse(d);
      _web = db;
    } catch (e) {
      debugPrint('Úložisko prehliadača nie je dostupné: $e');
      _web = null;
    }
  }

  Future<String?> _readData() async {
    if (kIsWeb) return _web?.getText(_kRecipes);
    if (!await _dataFile.exists()) return null;
    return _dataFile.readAsString();
  }

  // Nastavenia (jazyk, vzhľad): súbor settings.json / kľúč v prehliadači.
  File get _settingsFile => File('${_dir.path}${Platform.pathSeparator}settings.json');

  Future<String?> _readSetting(String name) async {
    try {
      if (kIsWeb) return await _web?.getText('setting:$name');
      if (!await _settingsFile.exists()) return null;
      final m = jsonDecode(await _settingsFile.readAsString());
      return m is Map ? m[name] as String? : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSetting(String name, String value) async {
    try {
      if (kIsWeb) {
        await _web?.putText('setting:$name', value);
        return;
      }
      Map<String, dynamic> m = {};
      if (await _settingsFile.exists()) {
        final old = jsonDecode(await _settingsFile.readAsString());
        if (old is Map) m = Map<String, dynamic>.from(old);
      }
      m[name] = value;
      await _settingsFile.writeAsString(jsonEncode(m));
    } catch (e) {
      debugPrint('Nastavenie sa nepodarilo uložiť: $e');
    }
  }

  Future<void> _loadDefaults() async {
    final raw = await rootBundle.loadString('assets/recipes.json');
    _replaceAll(raw);
  }

  Future<void> _saving = Future.value();

  /// Ukladanie ide postupne (jedno po druhom), aby sa zápisy neprekrývali.
  Future<void> _save() {
    _saving = _saving.catchError((_) {}).then((_) async {
      final json = const JsonEncoder.withIndent(' ')
          .convert(_recipes.map((r) => r.toJson()).toList());
      if (kIsWeb) {
        await _web?.putText(_kRecipes, json);
        return;
      }
      final tmp = File('${_dataFile.path}.tmp');
      await tmp.writeAsString(json, flush: true);
      await tmp.rename(_dataFile.path);
    });
    return _saving;
  }

  Recipe? byId(String id) {
    for (final r in _recipes) {
      if (r.id == id) return r;
    }
    return null;
  }

  String newId() => 'u${DateTime.now().microsecondsSinceEpoch}';

  /// Všetky kategórie, ktoré sa práve používajú.
  Set<String> get usedCategories => _recipes.map((r) => r.category).toSet();

  Future<void> upsert(Recipe recipe) async {
    recipe.updatedAt = DateTime.now();
    final i = _recipes.indexWhere((r) => r.id == recipe.id);
    if (i >= 0) {
      _recipes[i] = recipe;
    } else {
      _recipes.add(recipe);
    }
    notifyListeners();
    await _save();
  }

  Future<void> delete(Recipe recipe) async {
    _recipes.removeWhere((r) => r.id == recipe.id);
    await _deleteImage(recipe.imagePath);
    notifyListeners();
    await _save();
  }

  Future<void> toggleFavorite(Recipe recipe) async {
    recipe.favorite = !recipe.favorite;
    notifyListeners();
    await _save();
  }

  // --------------------------------------------------------------- fotky

  /// Súbor s fotkou receptu (alebo null). Na webe vždy null – tam použi
  /// [imageProvider] / [imageBytes]. Kontroluje disk, preto ho nevolaj
  /// pri kreslení; na to je [hasImage].
  File? imageFile(Recipe r) {
    if (kIsWeb || r.imagePath == null || !loaded) return null;
    final f = File('${_imagesDir.path}${Platform.pathSeparator}${r.imagePath}');
    return f.existsSync() ? f : null;
  }

  /// Má recept fotku? Odpovedá z pamäte, takže sa dá volať aj pri kreslení.
  bool hasImage(Recipe r) {
    final name = r.imagePath;
    return name != null && _imageNames.contains(name);
  }

  /// Fotka receptu pre widget Image (alebo null).
  ImageProvider? imageProvider(Recipe r) {
    final name = r.imagePath;
    if (name == null || !_imageNames.contains(name)) return null;
    if (kIsWeb) {
      final db = _web;
      if (db == null) {
        final b = _webMemory[name];
        return b == null ? null : MemoryImage(b);
      }
      return _WebDbImage(db, '$_kImagePrefix$name');
    }
    return FileImage(File('${_imagesDir.path}${Platform.pathSeparator}$name'));
  }

  /// Bajty fotky receptu (alebo null).
  Future<Uint8List?> imageBytes(Recipe r) async {
    final name = r.imagePath;
    if (name == null || !_imageNames.contains(name)) return null;
    if (kIsWeb) {
      return _webMemory[name] ?? await _web?.getBytes('$_kImagePrefix$name');
    }
    final f = imageFile(r);
    return f?.readAsBytes();
  }

  /// Skopíruje vybranú fotku do priečinka aplikácie a vráti jej názov.
  /// Veľké fotky sa pritom zmenšia (pozri [shrinkPhoto]).
  Future<String> importImage(String sourcePath) async {
    final small = await shrinkPhoto(await File(sourcePath).readAsBytes());
    if (small != null) return importImageBytes(small.bytes, small.ext);
    final ext = sourcePath.contains('.') ? sourcePath.split('.').last.toLowerCase() : 'jpg';
    final name = 'img_${DateTime.now().microsecondsSinceEpoch}.$ext';
    await File(sourcePath).copy('${_imagesDir.path}${Platform.pathSeparator}$name');
    _imageNames.add(name);
    return name;
  }

  /// Uloží vybranú fotku z pamäte (prehliadač, mobil) – vopred ju zmenší.
  Future<String> importPickedBytes(Uint8List bytes, String ext) async {
    final small = await shrinkPhoto(bytes);
    if (small != null) return importImageBytes(small.bytes, small.ext);
    return importImageBytes(bytes, ext.isEmpty ? 'jpg' : ext);
  }

  static int _imageSeq = 0;

  Future<String> importImageBytes(Uint8List bytes, String ext) async {
    // Prehliadač má čas len na milisekundy – poradové číslo zabráni
    // rovnakým názvom, keď sa naraz ukladá veľa fotiek (načítanie zálohy).
    final name = kIsWeb
        ? 'img_${DateTime.now().millisecondsSinceEpoch}_${_imageSeq++}.$ext'
        : 'img_${DateTime.now().microsecondsSinceEpoch}.$ext';
    if (kIsWeb) {
      if (_web == null) {
        _webMemory[name] = bytes;
      } else {
        await _web!.putBytes('$_kImagePrefix$name', bytes);
      }
      _imageNames.add(name);
      return name;
    }
    await File('${_imagesDir.path}${Platform.pathSeparator}$name').writeAsBytes(bytes);
    _imageNames.add(name);
    return name;
  }

  Future<void> _deleteImage(String? name) async {
    if (name == null) return;
    _imageNames.remove(name);
    if (kIsWeb) {
      _webMemory.remove(name);
      await _web?.delete('$_kImagePrefix$name');
      return;
    }
    final f = File('${_imagesDir.path}${Platform.pathSeparator}$name');
    if (await f.exists()) await f.delete();
  }

  /// Zmaže fotku, ktorá už nie je priradená žiadnemu receptu.
  Future<void> cleanupImage(String? name) async {
    if (name == null) return;
    if (_recipes.any((r) => r.imagePath == name)) return;
    await _deleteImage(name);
  }

  // ------------------------------------------------------ export / import

  /// Záloha všetkých receptov aj s fotkami do jedného JSON súboru.
  Future<Uint8List> exportBackup() async {
    final list = <Map<String, dynamic>>[];
    for (final r in _recipes) {
      final j = r.toJson();
      final img = await imageBytes(r);
      if (img != null) j['imageData'] = base64Encode(img);
      list.add(j);
    }
    final json = const JsonEncoder.withIndent(' ').convert({
      'app': 'recepty',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'recipes': list,
    });
    return Uint8List.fromList(utf8.encode(json));
  }

  /// Načíta zálohu. Recepty s rovnakým ID sa prepíšu novšou verziou,
  /// nové sa pridajú. Vráti počet pridaných/aktualizovaných receptov.
  ///
  /// [replace] = true (webová verzia): všetky recepty sa nahradia receptami
  /// zo zálohy – mobil je presná kópia počítača (aj vymazané recepty zmiznú).
  Future<int> importBackup(Uint8List bytes, {bool replace = false}) async {
    final data = jsonDecode(utf8.decode(bytes));
    final list = (data is Map ? data['recipes'] : data) as List;
    if (replace) {
      final exportedAt = data is Map ? DateTime.tryParse('${data['exportedAt']}') : null;
      return _replaceFromBackup(list, exportedAt);
    }
    var count = 0;
    for (final e in list) {
      final j = Map<String, dynamic>.from(e as Map);
      final incoming = Recipe.fromJson(j);
      final existing = byId(incoming.id);
      if (existing != null && !incoming.updatedAt.isAfter(existing.updatedAt)) continue;
      if (j['imageData'] is String && incoming.imagePath != null) {
        final ext = incoming.imagePath!.split('.').last;
        incoming.imagePath = await importImageBytes(base64Decode(j['imageData'] as String), ext);
      } else {
        incoming.imagePath = existing?.imagePath;
      }
      final i = _recipes.indexWhere((r) => r.id == incoming.id);
      if (i >= 0) {
        final oldImage = _recipes[i].imagePath;
        _recipes[i] = incoming;
        if (oldImage != incoming.imagePath) await cleanupImage(oldImage);
      } else {
        _recipes.add(incoming);
      }
      count++;
    }
    if (kIsWeb) {
      final exportedAt = data is Map ? DateTime.tryParse('${data['exportedAt']}') : null;
      lastBackupDate = exportedAt ?? DateTime.now();
      await _web?.putText(_kBackupDate, lastBackupDate!.toIso8601String());
    }
    notifyListeners();
    await _save();
    return count;
  }

  Future<int> _replaceFromBackup(List list, DateTime? exportedAt) async {
    // Najprv všetko prečítať – ak je súbor poškodený, nič sa nezmení.
    final incoming = <(Recipe, Uint8List?)>[];
    for (final e in list) {
      final j = Map<String, dynamic>.from(e as Map);
      final r = Recipe.fromJson(j);
      final img = j['imageData'] is String && r.imagePath != null
          ? base64Decode(j['imageData'] as String)
          : null;
      incoming.add((r, img));
    }
    if (incoming.isEmpty) throw const FormatException('V zálohe nie sú žiadne recepty / The backup has no recipes.');

    final oldImages = _recipes.map((r) => r.imagePath).whereType<String>().toList();
    final fresh = <Recipe>[];
    for (final (r, img) in incoming) {
      if (img != null) {
        r.imagePath = await importImageBytes(img, r.imagePath!.split('.').last);
      } else {
        r.imagePath = null;
      }
      fresh.add(r);
    }
    _recipes
      ..clear()
      ..addAll(fresh);
    for (final name in oldImages) {
      await cleanupImage(name);
    }
    if (kIsWeb) {
      // fotky, na ktoré už nič neodkazuje (napr. po prerušenom načítaní)
      final used = _recipes.map((r) => r.imagePath).toSet();
      for (final name in _imageNames.where((n) => !used.contains(n)).toList()) {
        await _deleteImage(name);
      }
      lastBackupDate = exportedAt ?? DateTime.now();
      await _web?.putText(_kBackupDate, lastBackupDate!.toIso8601String());
    }
    notifyListeners();
    await _save();
    return fresh.length;
  }
}

/// Fotka uložená v IndexedDB. Bajty si vypýta, až keď ju treba vykresliť –
/// vďaka tomu sa pri štarte webovej verzie nenačítavajú všetky fotky naraz.
class _WebDbImage extends ImageProvider<_WebDbImage> {
  final WebDb db;
  final String key;

  const _WebDbImage(this.db, this.key);

  @override
  Future<_WebDbImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_WebDbImage>(this);

  @override
  ImageStreamCompleter loadImage(_WebDbImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
        codec: _decode(decode),
        scale: 1,
        debugLabel: key.key,
      );

  Future<ui.Codec> _decode(ImageDecoderCallback decode) async {
    final bytes = await db.getBytes(key);
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Fotka $key nie je v úložisku prehliadača.');
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) => other is _WebDbImage && other.key == key;

  @override
  int get hashCode => key.hashCode;
}
