import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../l10n/strings.dart';
import '../models/recipe.dart';
import 'platform/photo_resize.dart';
import 'platform/web_platform.dart';
import 'recipe_store.dart';

/// Chyba pri načítaní receptu z webu (text je určený pre používateľa).
class WebImportException implements Exception {
  final String message;
  WebImportException(this.message);
  @override
  String toString() => message;
}

/// Načíta recept z webovej stránky bez AI.
///
/// Väčšina receptových stránok má v kóde stránky recept v štandardnom
/// formáte schema.org/Recipe (JSON-LD) – ten istý, ktorý číta Google.
/// Z neho sa vytiahne názov, suroviny, postup a fotka.
///
/// Vráti návrh receptu (ešte neuložený) – používateľ ho skontroluje
/// na obrazovke úprav a až potom uloží.
Future<Recipe> importRecipeFromUrl(
  String rawUrl, {
  required String category,
  required RecipeStore store,
  required S s,
}) async {
  final uri = _parseUrl(rawUrl, s);
  final html = await _download(uri, s);

  final data = _findRecipeJson(html);
  if (data == null) throw WebImportException(s.webNoRecipe);

  final title = _clean(_asString(data['name']) ?? '');
  final ingredients = _asList(data['recipeIngredient'] ?? data['ingredients'])
      .map((e) => _normalizeIngredient(_clean(_asString(e) ?? '')))
      .whereType<String>()
      .toList();
  final steps = _instructions(data['recipeInstructions']);

  if (title.isEmpty && ingredients.isEmpty && steps.isEmpty) {
    throw WebImportException(s.webEmpty);
  }

  // Poznámky: počet porcií, čas a zdroj.
  final notes = <String>[];
  final yield_ = _asList(data['recipeYield']).map((e) => _clean('$e')).where((s) => s.isNotEmpty);
  if (yield_.isNotEmpty) notes.add(s.servings(yield_.first));
  final total = _duration(_asString(data['totalTime']));
  if (total != null) notes.add(s.totalTime(total));
  notes.add(s.source('$uri'));

  // Fotka (ak sa nepodarí stiahnuť, recept sa načíta aj bez nej).
  String? imagePath;
  final imageUrl = _imageUrl(data['image']);
  if (imageUrl != null) {
    try {
      final imgUri = uri.resolve(imageUrl);
      final bytes = await _downloadBytes(imgUri, s);
      final small = await shrinkPhoto(bytes);
      imagePath = small != null
          ? await store.importImageBytes(small.bytes, small.ext)
          : await store.importImageBytes(bytes, _imageExt(imgUri.path));
    } catch (_) {
      imagePath = null;
    }
  }

  return Recipe(
    id: store.newId(),
    title: title.isEmpty ? s.webRecipeTitle : title,
    category: category,
    ingredients: ingredients,
    steps: steps,
    notes: notes.join('\n'),
    imagePath: imagePath,
  );
}

// ------------------------------------------------------------ sťahovanie

Uri _parseUrl(String raw, S s) {
  var url = raw.trim();
  if (url.isEmpty) throw WebImportException(s.webEnterLink);
  if (!url.startsWith(RegExp(r'https?://', caseSensitive: false))) url = 'https://$url';
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) throw WebImportException(s.webInvalidLink);
  return uri;
}

Future<Uint8List> _downloadBytes(Uri uri, S s) async {
  // Vo webovej verzii sťahuje stránku samotný prehliadač. Väčšina stránok to
  // cudzej apke nepovolí (ochrana CORS) – vtedy to skončí chybou a používateľ
  // dostane ponuku vložiť recept cez AI alebo ako text.
  if (kIsWeb) return fetchBytes('$uri');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final req = await client.getUrl(uri);
    req.followRedirects = true;
    req.headers.set(HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36');
    req.headers.set(HttpHeaders.acceptLanguageHeader, s.acceptLanguage);
    final res = await req.close().timeout(const Duration(seconds: 30));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw WebImportException(s.webHttpError(res.statusCode));
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in res.timeout(const Duration(seconds: 30))) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  } finally {
    client.close(force: true);
  }
}

Future<String> _download(Uri uri, S s) async {
  try {
    final bytes = await _downloadBytes(uri, s);
    return utf8.decode(bytes, allowMalformed: true);
  } on WebImportException {
    rethrow;
  } on SocketException {
    throw WebImportException(s.webOffline);
  } catch (e) {
    throw WebImportException(kIsWeb ? s.webBlockedByBrowser : s.webDownloadFailed(e));
  }
}

// ------------------------------------------------------------ JSON-LD

Map<String, dynamic>? _findRecipeJson(String html) {
  final re = RegExp(
    r'''<script[^>]*type\s*=\s*["']?application/ld\+json["']?[^>]*>([\s\S]*?)</script>''',
    caseSensitive: false,
  );
  for (final m in re.allMatches(html)) {
    final text = m.group(1)!.trim();
    dynamic json;
    try {
      json = jsonDecode(text);
    } catch (_) {
      try {
        // Niektoré stránky majú v JSON neplatné zalomenia riadkov.
        json = jsonDecode(text.replaceAll(RegExp(r'[\r\n\t]+'), ' '));
      } catch (_) {
        continue;
      }
    }
    final found = _searchRecipe(json);
    if (found != null) return found;
  }
  return null;
}

Map<String, dynamic>? _searchRecipe(dynamic node) {
  if (node is List) {
    for (final n in node) {
      final f = _searchRecipe(n);
      if (f != null) return f;
    }
  } else if (node is Map) {
    final map = Map<String, dynamic>.from(node);
    final type = map['@type'];
    final types = type is List ? type.map((e) => '$e') : [if (type != null) '$type'];
    if (types.any((t) => t.toLowerCase() == 'recipe' || t.endsWith('/Recipe'))) return map;
    for (final key in ['@graph', 'mainEntity', 'mainEntityOfPage', 'itemListElement', 'item']) {
      if (map[key] != null) {
        final f = _searchRecipe(map[key]);
        if (f != null) return f;
      }
    }
  }
  return null;
}

List<String> _instructions(dynamic node) {
  final out = <String>[];
  void walk(dynamic n) {
    if (n == null) return;
    if (n is String) {
      // Postup ako jeden text – rozdelíme podľa riadkov.
      final text = _clean(n, keepLines: true);
      out.addAll(text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty));
    } else if (n is List) {
      n.forEach(walk);
    } else if (n is Map) {
      final type = '${n['@type'] ?? ''}';
      if (type.contains('HowToSection')) {
        final name = _clean(_asString(n['name']) ?? '');
        if (name.isNotEmpty) out.add('$name:');
        walk(n['itemListElement']);
      } else if (n['text'] != null) {
        walk(n['text']);
      } else if (n['name'] != null) {
        walk(n['name']);
      } else if (n['itemListElement'] != null) {
        walk(n['itemListElement']);
      }
    }
  }

  walk(node);
  return out;
}

String? _imageUrl(dynamic node) {
  if (node == null) return null;
  if (node is String) return node.isEmpty ? null : node;
  if (node is List) {
    for (final n in node) {
      final u = _imageUrl(n);
      if (u != null) return u;
    }
    return null;
  }
  if (node is Map) return _imageUrl(node['url'] ?? node['contentUrl'] ?? node['@id']);
  return null;
}

String _imageExt(String path) {
  final m = RegExp(r'\.(jpe?g|png|webp|gif)$', caseSensitive: false).firstMatch(path);
  return (m?.group(1) ?? 'jpg').toLowerCase();
}

/// ISO 8601 trvanie (napr. PT1H30M) → „1 h 30 min“.
String? _duration(String? iso) {
  if (iso == null) return null;
  final m = RegExp(r'P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?').firstMatch(iso);
  if (m == null) return null;
  final d = int.tryParse(m.group(1) ?? '') ?? 0;
  final h = (int.tryParse(m.group(2) ?? '') ?? 0) + d * 24;
  final min = int.tryParse(m.group(3) ?? '') ?? 0;
  if (h == 0 && min == 0) return null;
  return [if (h > 0) '$h h', if (min > 0) '$min min'].join(' ');
}

// ------------------------------------------------------------ suroviny

final _amountFirst = RegExp(r'^(.+?)\s*,\s*((?:\d|[½¼¾⅓⅔]).*)$');
final _parens = RegExp(r'\(([^)]*)\)');
final _nameless = RegExp(
  r'^(podľa chuti|podľa potreby|na ozdobu|na zdobenie|trocha|štipka|to taste|as needed|for garnish|a pinch)$',
  caseSensitive: false,
);

/// Upraví surovinu do tvaru, aký používa aplikácia: množstvo na začiatku.
///
/// Napr. Varecha.sk: „maliny, 200-250 g mrazené“ → „200-250 g mrazené maliny“,
/// „košíčky na tartaletky, 15 ks (hotové)“ → „15 ks košíčky na tartaletky (hotové)“.
/// Riadky bez názvu suroviny (len „podľa chuti“) sa vynechajú.
String? _normalizeIngredient(String line) {
  final t = line.trim();
  if (t.isEmpty || _nameless.hasMatch(t)) return null;
  final m = _amountFirst.firstMatch(t);
  if (m == null) return t;
  final name = m.group(1)!.trim();
  final amount = m.group(2)!;
  final notes = _parens.allMatches(amount).map((p) => p.group(1)!.trim()).where((n) => n.isNotEmpty);
  final bare = amount.replaceAll(_parens, '').replaceAll(RegExp(r'\s+'), ' ').trim();
  final extra = notes.isEmpty ? '' : ' (${notes.join(', ')})';
  return '$bare $name$extra';
}

// ------------------------------------------------------------ text

String? _asString(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  if (v is List && v.isNotEmpty) return _asString(v.first);
  if (v is Map) return _asString(v['name'] ?? v['text']);
  return '$v';
}

List<dynamic> _asList(dynamic v) {
  if (v == null) return const [];
  if (v is List) return v;
  return [v];
}

/// Odstráni HTML značky, dekóduje entity (&amp; …) a upraví medzery.
String _clean(String s, {bool keepLines = false}) {
  var t = s
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</(p|li|div|h\d)>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  t = _decodeEntities(t);
  if (keepLines) {
    return t
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'[ \t ]+'), ' ').trim())
        .where((l) => l.isNotEmpty)
        .join('\n');
  }
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _decodeEntities(String s) {
  const named = {
    'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'", 'nbsp': ' ',
    'frac12': '½', 'frac14': '¼', 'frac34': '¾', 'deg': '°', 'ndash': '–',
    'mdash': '—', 'hellip': '…', 'times': '×',
  };
  return s.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z]+\d*);'), (m) {
    final e = m.group(1)!;
    if (e.startsWith('#x') || e.startsWith('#X')) {
      final c = int.tryParse(e.substring(2), radix: 16);
      return c == null ? m.group(0)! : String.fromCharCode(c);
    }
    if (e.startsWith('#')) {
      final c = int.tryParse(e.substring(1));
      return c == null ? m.group(0)! : String.fromCharCode(c);
    }
    return named[e] ?? m.group(0)!;
  });
}
