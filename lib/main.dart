import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/recipe_store.dart';
import 'l10n/strings.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = RecipeStore();
  runApp(RecipesApp(store: store));
  store.load();
}

/// Sprístupní [RecipeStore] celej aplikácii a prekreslí obrazovky pri zmene.
class StoreScope extends InheritedNotifier<RecipeStore> {
  const StoreScope({super.key, required RecipeStore store, required super.child})
      : super(notifier: store);

  static RecipeStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// Prístup bez odoberania zmien (napr. v obsluhe tlačidla).
  static RecipeStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

class RecipesApp extends StatelessWidget {
  final RecipeStore store;
  const RecipesApp({super.key, required this.store});

  ThemeData _theme(Brightness b) {
    final dark = b == Brightness.dark;
    var scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFB5523B),
      brightness: b,
    );
    if (dark) {
      // Tmavá téma: čierne pozadie, neutrálne sivé plochy, marhuľový akcent.
      scheme = scheme.copyWith(
        surface: const Color(0xFF000000), // 1 – hlavné pozadie
        surfaceContainerLow: const Color(0xFF141414), // 2 – karty receptov
        secondaryContainer: const Color(0xFF262626), // 4 – vybraná kategória
        onSecondaryContainer: const Color(0xFFFFB061), // 4 – text a ohraničenie výberu
        outlineVariant: const Color(0xFF242424), // deliace čiary
      );
    }
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      // Vo webovej verzii je tlačidlo „Nový recept“ o tretinu nižšie
      // (48 → 32), na dotykovom displeji inak zaberá priveľa miesta.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: dark ? const Color(0xFFFFB061) : null, // 5 – tlačidlo Nový recept
        foregroundColor: dark ? const Color(0xFF000000) : null,
        extendedSizeConstraints:
            kIsWeb ? const BoxConstraints.tightFor(height: 32) : null,
        extendedPadding: kIsWeb ? const EdgeInsets.symmetric(horizontal: 14) : null,
        extendedIconLabelSpacing: kIsWeb ? 6 : null,
        extendedTextStyle:
            kIsWeb ? const TextStyle(fontSize: 13, fontWeight: FontWeight.w500) : null,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1F1F1F) : null, // 3 – vyhľadávanie
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: ValueListenableBuilder<String>(
        valueListenable: store.language,
        builder: (context, lang, _) => ValueListenableBuilder<String>(
          valueListenable: store.theme,
          builder: (context, mode, _) => MaterialApp(
            onGenerateTitle: (context) => S.of(context).appTitle,
            debugShowCheckedModeBanner: false,
            theme: _theme(Brightness.light),
            darkTheme: _theme(Brightness.dark),
            // Voľba z menu; 'system' = podľa nastavenia zariadenia.
            themeMode: switch (mode) {
              'light' => ThemeMode.light,
              'dark' => ThemeMode.dark,
              _ => ThemeMode.system,
            },
            // Jazyk apky (SK/EN) – aj systémové texty (Kopírovať, Späť…).
            locale: Locale(lang),
            supportedLocales: [for (final l in S.supportedLanguages) Locale(l)],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const HomeScreen(),
          ),
        ),
      ),
    );
  }
}
