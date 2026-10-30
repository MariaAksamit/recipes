import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recepty/data/recipe_store.dart';
import 'package:recepty/data/text_import.dart';
import 'package:recepty/l10n/strings.dart';
import 'package:recepty/models/recipe.dart';
import 'package:recepty/screens/home_screen.dart';
import 'package:recepty/utils/text_utils.dart';
import 'package:recepty/utils/word_export.dart';

void main() {
  test('vyhľadávanie ignoruje diakritiku', () {
    expect(normalize('Bryndzové Halušky'), 'bryndzove halusky');
  });

  test('prepočet množstiev', () {
    expect(splitIngredient('700 g zemiaky', 2).qty, '1400');
    expect(splitIngredient('½ droždie', 2).qty, '1');
    expect(splitIngredient('1 ½ PL olej', 2).qty, '3');
    expect(splitIngredient('0,3 l mlieko', 0.5).qty, '0,15');
    expect(splitIngredient('3-4 stredné zemiaky', 2).qty, '6–8');
    expect(splitIngredient('75 (150) g múka', 2).qty, '150 (300)');
    expect(splitIngredient('2 vajcia', 1.5).qty, '3');
    expect(splitIngredient('soľ', 2).qty, null);
    expect(splitIngredient('500 g hladká múka', 1).rest, 'g hladká múka');
  });

  test('export do Wordu vytvorí .docx', () {
    final bytes = buildRecipesDocx(
      title: 'Moje recepty',
      recipes: [
        Recipe(id: 'a', title: 'Guláš & <knedľa>', category: 'Hlavné jedlá',
            ingredients: ['Cesto:', '500 g múka'], steps: ['Uvariť.'], notes: 'Chutí.'),
        Recipe(id: 'b', title: 'Bez postupu', category: 'Pečivo', ingredients: ['soľ']),
      ],
    );
    expect(bytes.sublist(0, 2), [0x50, 0x4B]); // ZIP
  });

  test('export do Wordu po anglicky', () {
    final bytes = buildRecipesDocx(
      title: 'My Recipes',
      strings: const SEn(),
      recipes: [Recipe(id: 'a', title: 'Guláš', category: 'Hlavné jedlá', ingredients: ['soľ'])],
    );
    expect(bytes.sublist(0, 2), [0x50, 0x4B]);
  });

  test('texty: počty a kategórie', () {
    const sk = SSk(), en = SEn();
    expect(sk.recipeCount(1), '1 recept');
    expect(sk.recipeCount(3), '3 recepty');
    expect(sk.recipeCount(5), '5 receptov');
    expect(en.recipeCount(5), '5 recipes');
    expect(en.ingredientCount(1), '1 ingredient');
    expect(en.category('Polievky'), 'Soups');
    expect(en.category('Moja kategória'), 'Moja kategória');
    expect(sk.category('Polievky'), 'Polievky');
  });

  test('recept z textu – slovenské aj anglické nadpisy', () {
    final store = RecipeStore();
    for (final s in const <S>[SSk(), SEn()]) {
      final r = Recipe(
        id: 'x',
        title: 'Palacinky',
        category: 'Múčne jedlá a iné',
        ingredients: ['Cesto:', '250 g hladká múka', '2 vajcia'],
        steps: ['Zmiešať.', 'Piecť.'],
        notes: 'Na 4 porcie.',
      );
      final back = parseRecipeText(recipeToText(r, s), category: 'Polievky', store: store, s: s);
      expect(back.title, 'Palacinky');
      expect(back.ingredients, ['Cesto:', '250 g hladká múka', '2 vajcia']);
      expect(back.steps, ['Zmiešať.', 'Piecť.']);
      expect(back.notes, 'Na 4 porcie.');
      expect(back.category, 'Polievky');
    }
    final en = parseRecipeText(
      'TITLE: Pancakes\nINGREDIENTS:\n250 g flour 2 tbsp sugar\nMETHOD:\n1. Mix.\n2. Fry.',
      category: 'Ostatné',
      store: store,
      s: const SEn(),
    );
    expect(en.ingredients, ['250 g flour', '2 tbsp sugar']);
    expect(en.steps, ['Mix.', 'Fry.']);
  });

  test('verzia v dialógu „O aplikácii“ sedí s pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)', multiLine: true)
        .firstMatch(pubspec);
    expect(m, isNotNull, reason: 'v pubspec.yaml chýba riadok version:');
    expect(
      kAppVersion,
      m!.group(1),
      reason: 'kAppVersion v home_screen.dart sa rozišla s pubspec.yaml',
    );
  });

  test('ukážková náplň obsahuje len recepty určené na zverejnenie', () {
    final raw = File('assets/recipes.json').readAsStringSync();
    final ids = (jsonDecode(raw) as List)
        .map((e) => (e as Map)['id'] as String)
        .toList();
    expect(
      ids.toSet(),
      {'r001', 'r006-01', 'r012', 'r017', 'r066', 'r074'},
      reason: 'V assets/recipes.json má byť šestica ukážkových receptov. '
          'Osobná zbierka sa do zverejneného buildu dostať nesmie.',
    );
  });
}
