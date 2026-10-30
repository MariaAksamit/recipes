import '../l10n/strings.dart';
import '../models/recipe.dart';
import '../utils/text_utils.dart';
import 'recipe_store.dart';

// Pokyn pre AI (ChatGPT, Gemini…) je v l10n/strings.dart – S.aiPrompt().

/// Recept ako čitateľný text – na zdieľanie (e-mail, správa).
/// Tento istý tvar vie aplikácia znova načítať cez „Vytvoriť recept z textu“
/// (v slovenčine aj v angličtine).
String recipeToText(Recipe r, S s) {
  final sb = StringBuffer()
    ..writeln('${s.hTitle}: ${r.title}')
    ..writeln('${s.hCategory}: ${s.category(r.category)}')
    ..writeln()
    ..writeln('${s.hIngredients}:');
  for (final i in r.ingredients) {
    sb.writeln(i);
  }
  if (r.steps.isNotEmpty) {
    sb
      ..writeln()
      ..writeln('${s.hSteps}:');
    for (var i = 0; i < r.steps.length; i++) {
      sb.writeln('${i + 1}. ${r.steps[i]}');
    }
  }
  if (r.notes.trim().isNotEmpty) {
    sb
      ..writeln()
      ..writeln('${s.hNotes}:')
      ..writeln(r.notes.trim());
  }
  return sb.toString().trimRight();
}

class TextImportException implements Exception {
  final String message;
  TextImportException(this.message);
  @override
  String toString() => message;
}

enum _Section { none, title, ingredients, steps, notes }

// Nadpisy častí receptu (bez diakritiky, malými písmenami) – SK aj EN.
const _titleKeys = {'nazov', 'nazov receptu', 'recept', 'title', 'name', 'recipe', 'recipe name'};
const _ingredientKeys = {
  'suroviny', 'ingrediencie', 'potrebujeme', 'ingredients', 'you need', 'you will need',
};
const _stepKeys = {
  'postup', 'priprava', 'postup pripravy', 'method', 'directions', 'instructions', 'steps',
  'preparation',
};
const _noteKeys = {'poznamky', 'poznamka', 'tipy', 'notes', 'note', 'tips'};
const _categoryKeys = {'kategoria', 'category'};

/// Načíta recept z textu (odpoveď od AI alebo zdieľaný recept).
Recipe parseRecipeText(
  String text, {
  required String category,
  required RecipeStore store,
  required S s,
}) {
  var title = '';
  final ingredients = <String>[];
  final steps = <String>[];
  final notes = <String>[];
  final before = <String>[]; // riadky pred prvou sekciou (náhradný názov)
  var section = _Section.none;

  for (final rawLine in text.split(RegExp(r'\r?\n'))) {
    // Odstráni formátovanie Markdownu (**tučné**, # nadpisy).
    final line = rawLine.replaceAll('**', '').replaceAll('__', '').replaceFirst(RegExp(r'^\s*#+\s*'), '').trim();
    if (line.isEmpty) continue;
    if (line.startsWith('```')) continue; // ohraničenie bloku kódu od AI

    final header = RegExp(r'^([^:]{2,20}):\s*(.*)$').firstMatch(line);
    if (header != null) {
      final key = normalize(header.group(1)!.trim());
      final rest = header.group(2)!.trim();
      _Section? found;
      if (_titleKeys.contains(key)) {
        found = _Section.title;
      } else if (_ingredientKeys.contains(key)) {
        found = _Section.ingredients;
      } else if (_stepKeys.contains(key)) {
        found = _Section.steps;
      } else if (_noteKeys.contains(key)) {
        found = _Section.notes;
      } else if (_categoryKeys.contains(key)) {
        continue; // kategóriu vyberáš v aplikácii
      }
      if (found != null) {
        section = found;
        if (found == _Section.title) {
          if (rest.isNotEmpty) title = rest;
        } else if (rest.isNotEmpty) {
          _add(found, rest, ingredients, steps, notes);
        }
        continue;
      }
    }

    switch (section) {
      case _Section.none:
        before.add(line);
      case _Section.title:
        if (title.isEmpty) title = line;
      default:
        _add(section, line, ingredients, steps, notes);
    }
  }

  if (title.isEmpty && before.isNotEmpty) title = before.first;
  if (ingredients.isEmpty && steps.isEmpty) {
    throw TextImportException(s.textNoContent);
  }

  return Recipe(
    id: store.newId(),
    title: title.isEmpty ? s.untitledRecipe : title,
    category: category,
    ingredients: ingredients,
    steps: steps,
    notes: notes.join('\n'),
  );
}

void _add(_Section s, String line, List<String> ingredients, List<String> steps, List<String> notes) {
  final noBullet = line.replaceFirst(RegExp(r'^[-*•·–]\s+'), '');
  switch (s) {
    case _Section.ingredients:
      ingredients.addAll(splitIngredientLine(noBullet));
    case _Section.steps:
      final step = noBullet.replaceFirst(RegExp(r'^\d+\s*[.)]\s*'), '').trim();
      if (step.isNotEmpty) steps.add(step);
    case _Section.notes:
      notes.add(noBullet);
    default:
      break;
  }
}

// ---------------------------------------------------------------------------
// Oprava zlepených surovín
// ---------------------------------------------------------------------------
// Keď sa text kopíruje z okna AI (Copilot, ChatGPT…), riadky jedného odseku
// sa často spoja do jedného, napr.
//   „Cesto: 110 g maslo 250 g hnedý cukor 2 ks vajcia“
// Tu ich rozdelíme späť na nadpis skupiny a jednotlivé suroviny.

const _units = 'g|dkg|kg|mg|ml|cl|dl|l|PL|ČL|KL|ks|kus|kusy|kusov|štipka|štipky|'
    'lyžica|lyžice|lyžíc|lyžička|lyžičky|lyžičiek|hrnček|hrnčeky|hrnčekov|šálka|šálky|'
    'balíček|balíčky|balíčkov|balenie|balenia|bal|plátok|plátky|plátkov|strúčik|strúčiky|'
    'strúčikov|konzerva|konzervy|zväzok|zväzky|hrsť|kvapka|kvapky|kvapiek|vrecko|vrecká|'
    // anglické jednotky
    'tbsp|tsp|cup|cups|oz|lb|lbs|pinch|clove|cloves|can|cans|slice|slices|pcs|pc|piece|pieces|'
    'bunch|handful|drop|drops|packet|packets|sachet|sachets';

const _qty = r'(?:\d+(?:[.,]\d+)?(?:/\d+)?(?:\s*[½¼¾⅓⅔])?|[½¼¾⅓⅔])';

/// Miesto, kde začína ďalšia surovina: medzera, pred ňou nie číslo/pomlčka/zátvorka,
/// za ňou množstvo + jednotka, alebo slovo ako „niekoľko“, „štipka“…
final _gluedSplit = RegExp(
  '(?<=[^\\s\\d\\-–(/])\\s+(?=(?:$_qty\\s*(?:$_units)(?=[\\s.,)]|\$)|(?:niekoľko|pár|štipka|hrsť|trochu|a few|a pinch)\\s))',
  caseSensitive: false,
);

final _startsWithQty = RegExp('^$_qty\\s');

/// Nadpis skupiny zlepený so surovinami: „Cesto: 110 g maslo…“
final _groupWithItems = RegExp(r'^([^:\d]{2,40}):\s+(.+)$');

List<String> splitIngredientLine(String line) {
  final out = <String>[];
  var rest = line.trim();
  final g = _groupWithItems.firstMatch(rest);
  if (g != null && _startsWithQty.hasMatch(g.group(2)!.trim())) {
    out.add('${g.group(1)!.trim()}:');
    rest = g.group(2)!.trim();
  }
  if (_startsWithQty.hasMatch(rest)) {
    out.addAll(rest.split(_gluedSplit).map((e) => e.trim()).where((e) => e.isNotEmpty));
  } else if (rest.isNotEmpty) {
    out.add(rest);
  }
  return out;
}
