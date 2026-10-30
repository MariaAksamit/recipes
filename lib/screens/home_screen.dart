import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/platform/web_platform.dart';
import '../data/recipe_store.dart';
import '../l10n/strings.dart';
import '../main.dart';
import '../models/categories.dart';
import '../models/recipe.dart';
import '../utils/text_utils.dart';
import '../utils/word_export.dart';
import '../widgets/category_pane.dart';
import '../widgets/import_recipe_dialog.dart';
import '../widgets/recipe_list_pane.dart';
import '../widgets/theemis_mark.dart';
import '../widgets/web_sync_card.dart';
import 'recipe_detail_screen.dart';
import 'recipe_edit_screen.dart';

/// Šírka okna, od ktorej sa zobrazí zoznam a detail vedľa seba (PC, tablet).
const kWideLayout = 900.0;

/// Ako dlho zostane úvodné logo na obrazovke aj keď sú recepty načítané skôr.
/// Nastav na Duration.zero, ak nechceš žiadne zdržanie.
const kSplashMinDuration = Duration(milliseconds: 1400);

/// Verzia vypísaná v dialógu „O aplikácii“ (drž ju zhodnú s pubspec.yaml).
const kAppVersion = '1.0.0';

/// Text na vyhľadávanie (bez diakritiky) – počíta sa raz pre každý recept.
final _searchText = Expando<String>('searchText');
final _sortKey = Expando<String>('sortKey');

String _searchable(Recipe r) =>
    _searchText[r] ??= normalize('${r.title}\n${r.ingredients.join('\n')}');
String _sortable(Recipe r) => _sortKey[r] ??= normalize(r.title);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _category; // null = všetky
  bool _favoritesOnly = false;
  String? _selectedId; // vybraný recept v širokom rozložení
  bool _mobileShowRecipes = false; // mobil: true = zoznam receptov, false = kategórie
  bool _splashHold = true; // úvodné logo nech nezabliká, keď sa načíta hneď
  bool _warnedLoadFailed = false;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _splashTimer = Timer(kSplashMinDuration, () {
      if (mounted) setState(() => _splashHold = false);
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Recipe> _filtered(List<Recipe> all) {
    final q = normalize(_query.trim());
    final list = all.where((r) {
      if (_category != null && r.category != _category) return false;
      if (_favoritesOnly && !r.favorite) return false;
      return q.isEmpty || _searchable(r).contains(q);
    }).toList();
    list.sort((a, b) => _sortable(a).compareTo(_sortable(b)));
    return list;
  }

  List<String> _categories(Set<String> used) {
    final names = kCategories.map((c) => c.name).toList();
    names.addAll(used.where((u) => !names.contains(u)));
    return names;
  }

  /// Na PC sa recept zobrazí vpravo, na mobile na celú obrazovku.
  Future<void> _show(String id, bool wide) async {
    if (wide) {
      setState(() => _selectedId = id);
    } else {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: id)));
    }
  }

  /// Otvorí úpravu receptu; po uložení zobrazí uložený recept.
  Future<void> _editNew(RecipeEditScreen screen, bool wide) async {
    final id = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => screen));
    if (id == null || !mounted) return;
    await _show(id, wide);
  }

  /// Tlačidlo „Nový recept“ – výber, ako recept pridať.
  Future<void> _chooseNewRecipe(bool wide) async {
    final s = S.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  s.newRecipe,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: Text(s.writeManually),
              subtitle: Text(s.writeManuallySubtitle),
              onTap: () => Navigator.pop(ctx, 'manual'),
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: Text(s.loadRecipe),
              subtitle: Text(s.loadRecipeSubtitle),
              onTap: () => Navigator.pop(ctx, 'load'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'manual':
        await _editNew(RecipeEditScreen(initialCategory: _category), wide);
      case 'load':
        final draft = await showDialog<Recipe>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ImportRecipeDialog(initialCategory: _category ?? kCategories.first.name),
        );
        if (draft == null || !mounted) return;
        await _editNew(RecipeEditScreen(draft: draft), wide);
    }
  }

  // ------------------------------------------------------ súbory

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String _mimeType(String? extension) => switch (extension) {
    'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'json' => 'application/json',
    _ => 'application/octet-stream',
  };

  /// Uloží súbor cez dialóg „Uložiť ako“. Vráti false, ak to používateľ zrušil.
  Future<bool> _saveFile({
    required String dialogTitle,
    required String fileName,
    required Uint8List bytes,
    String? extension,
  }) async {
    // V prehliadači (webová apka) dialóg „Uložiť ako“ nie je – súbor sa stiahne
    // medzi Stiahnuté súbory, na iPhone sa ponúkne „Uložiť do Súborov“.
    if (kIsWeb) {
      downloadFile(fileName, bytes, _mimeType(extension ?? fileName.split('.').last));
      return true;
    }
    final path = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: extension == null ? FileType.any : FileType.custom,
      allowedExtensions: extension == null ? null : [extension],
      bytes: bytes,
    );
    if (path == null) return false;
    // Na počítači súbor zapíšeme sami (na mobile ho zapíše file_picker).
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final target = extension == null || path.toLowerCase().endsWith('.$extension')
          ? path
          : '$path.$extension';
      await File(target).writeAsBytes(bytes);
    }
    return true;
  }

  Future<void> _export() async {
    final store = StoreScope.read(context);
    final s = S.of(context);
    try {
      final bytes = await store.exportBackup();
      if (!mounted) return;
      final saved = await _saveFile(
        dialogTitle: s.saveBackupDialog,
        fileName: '${s.backupFileName}_${_today()}.json',
        bytes: bytes,
      );
      if (saved) _snack(s.backupSaved);
    } catch (e) {
      _snack(s.backupSaveFailed(e));
    }
  }

  /// Export receptov do Wordu – každý recept na samostatnej strane.
  Future<void> _exportWord() async {
    final store = StoreScope.read(context);
    final s = S.of(context);
    final all = store.recipes.toList();
    var chosen = all;
    String? subsetName;

    // Ak je zapnutý filter (kategória, obľúbené, hľadanie), opýtame sa.
    final shown = _filtered(all);
    if (shown.length != all.length) {
      final label = _query.trim().isNotEmpty ? s.searchResults : _filterTitle(s);
      final pick = await showDialog<bool>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(s.exportWord),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, false),
              child: ListTile(
                leading: const Icon(Icons.menu_book),
                title: Text(s.allRecipes),
                subtitle: Text(s.recipeCount(all.length)),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, true),
              child: ListTile(
                leading: const Icon(Icons.filter_list),
                title: Text(s.onlyShown(label)),
                subtitle: Text(s.recipeCount(shown.length)),
              ),
            ),
          ],
        ),
      );
      if (pick == null) return;
      if (pick) {
        chosen = shown;
        subsetName = label;
      }
    }
    if (chosen.isEmpty) {
      _snack(s.nothingToExport);
      return;
    }

    // Poradie: podľa kategórií ako v aplikácii, v nich podľa abecedy.
    final order = kCategories.map((c) => c.name).toList();
    int catIndex(String c) {
      final i = order.indexOf(c);
      return i < 0 ? order.length : i;
    }

    chosen = chosen.toList()
      ..sort((a, b) {
        final c = catIndex(a.category).compareTo(catIndex(b.category));
        if (c != 0) return c;
        final n = normalize(a.category).compareTo(normalize(b.category));
        if (n != 0) return n;
        return _sortable(a).compareTo(_sortable(b));
      });

    try {
      final images = <String, Uint8List>{};
      for (final r in chosen) {
        final b = await store.imageBytes(r);
        if (b != null) images[r.id] = b;
      }
      final colors = <String, String>{
        for (final c in kCategories)
          c.name: (c.color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase(),
      };
      // Podpis autora na titulnú stranu; keď asset chýba, export beží bez neho.
      Uint8List? logo;
      try {
        logo = (await rootBundle.load('assets/brand/theemis_logo.png'))
            .buffer
            .asUint8List();
      } catch (_) {
        logo = null;
      }
      final bytes = buildRecipesDocx(
        recipes: chosen,
        title: s.appTitle,
        subtitle: [?subsetName, s.recipeCount(chosen.length), s.date(DateTime.now())].join('  ·  '),
        categoryColors: colors,
        images: images,
        logo: logo,
        strings: s,
      );
      if (!mounted) return;
      final saved = await _saveFile(
        dialogTitle: s.saveWordDialog,
        fileName: '${s.wordFileName}_${_today()}.docx',
        extension: 'docx',
        bytes: bytes,
      );
      if (saved) _snack(s.wordSaved);
    } catch (e) {
      _snack(s.wordFailed(e));
    }
  }

  Future<void> _import() async {
    final store = StoreScope.read(context);
    final s = S.of(context);
    try {
      final res = await FilePicker.platform.pickFiles(
        dialogTitle: s.pickBackupDialog,
        type: FileType.any,
        withData: true,
      );
      final file = res?.files.single;
      if (file == null) return;
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      // Recepty s rovnakým ID sa prepíšu novšou verziou, nové sa pridajú –
      // rovnako na počítači aj v mobile, takže sa nič nestratí.
      final n = await store.importBackup(bytes);
      _snack(s.recipesLoaded(n));
    } catch (e) {
      _snack(s.fileLoadFailed(e));
    }
  }

  Future<void> _chooseLanguage() async {
    final store = StoreScope.read(context);
    final s = S.of(context);
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(s.language),
        children: [
          for (final l in S.supportedLanguages)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, l),
              child: ListTile(
                leading: Icon(
                  l == s.languageCode ? Icons.radio_button_checked : Icons.radio_button_off,
                ),
                title: Text(S.forLanguage(l).languageName),
              ),
            ),
        ],
      ),
    );
    if (code != null) await store.setLanguage(code);
  }

  /// Výber vzhľadu: podľa zariadenia, svetlý alebo tmavý.
  Future<void> _chooseTheme() async {
    final store = StoreScope.read(context);
    final s = S.of(context);
    const icons = {
      'system': Icons.brightness_auto_outlined,
      'light': Icons.light_mode_outlined,
      'dark': Icons.dark_mode_outlined,
    };
    final labels = {
      'system': s.themeSystem,
      'light': s.themeLight,
      'dark': s.themeDark,
    };
    final current = store.theme.value;
    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(s.appearance),
        children: [
          for (final m in RecipeStore.themeOptions)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, m),
              child: ListTile(
                leading: Icon(
                  m == current ? Icons.radio_button_checked : Icons.radio_button_off,
                ),
                title: Text(labels[m]!),
                trailing: Icon(icons[m]),
              ),
            ),
        ],
      ),
    );
    if (mode != null) await store.setTheme(mode);
  }

  /// Dialóg „O aplikácii“ – ikona apky zostáva, podpis autora je pod textom.
  void _showAbout() {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    showAboutDialog(
      context: context,
      applicationName: s.appTitle,
      applicationVersion: kAppVersion,
      applicationIcon: Image.asset(
        'assets/brand/app_icon.png',
        width: 56,
        height: 56,
        errorBuilder: (context, error, stack) =>
            Icon(Icons.menu_book, size: 48, color: scheme.primary),
      ),
      children: [
        const SizedBox(height: 8),
        Text(s.aboutBody, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 28),
        Text(
          s.aboutAuthor,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.outline,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        // AboutDialog natiahne deti na celú šírku; Align to uvoľní,
        // inak logo ignoruje zadanú šírku a roztiahne sa cez celý dialóg.
        Align(
          alignment: Alignment.centerLeft,
          child: TheemisMark(width: 140, color: scheme.onSurface),
        ),
      ],
    );
  }

  // ------------------------------------------------------ UI

  void _selectAll() => setState(() {
    _category = null;
    _favoritesOnly = false;
  });

  void _selectFavorites() => setState(() {
    _category = null;
    _favoritesOnly = true;
  });

  void _selectCategory(String c) => setState(() {
    _category = c;
    _favoritesOnly = false;
  });

  String _filterTitle(S s) {
    if (_favoritesOnly) return s.favorites;
    return _category == null ? s.allRecipes : s.category(_category!);
  }

  Widget _menu(S s) {
    PopupMenuItem<String> item(String value, IconData icon, String text) => PopupMenuItem(
      value: value,
      child: ListTile(leading: Icon(icon), title: Text(text)),
    );
    // Vlastná čiara: predvolená je v tmavej téme takmer neviditeľná.
    final lineColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12);
    PopupMenuDivider line() => PopupMenuDivider(
      height: 9,
      thickness: 1,
      indent: 12,
      endIndent: 12,
      color: lineColor,
    );
    return PopupMenuButton<String>(
      tooltip: s.more,
      onSelected: (v) {
        switch (v) {
          case 'word':
            _exportWord();
          case 'export':
            _export();
          case 'import':
            _import();
          case 'language':
            _chooseLanguage();
          case 'theme':
            _chooseTheme();
          case 'about':
            _showAbout();
        }
      },
      itemBuilder: (_) => [
        item('word', Icons.description_outlined, s.exportWord),
        line(),
        item('export', Icons.upload_file, s.saveBackup),
        item('import', Icons.download, s.loadBackup),
        line(),
        item('language', Icons.language, s.language),
        item('theme', Icons.brightness_6_outlined, s.appearance),
        line(),
        item('about', Icons.info_outline, s.aboutApp),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = S.of(context);
    final wide = MediaQuery.sizeOf(context).width >= kWideLayout;

    if (!store.loaded || _splashHold) {
      return const _Splash();
    }

    // Ak sa uložené recepty nepodarilo prečítať, povedz to – raz.
    if (store.loadFailed && !_warnedLoadFailed) {
      _warnedLoadFailed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _snack(s.dataLoadFailed));
    }

    final all = store.recipes;
    final recipes = _filtered(all);
    final categories = _categories(store.usedCategories);
    if (_category != null && !categories.contains(_category)) _category = null;
    if (_selectedId != null && store.byId(_selectedId!) == null) _selectedId = null;

    final counts = <String, int>{for (final c in categories) c: 0};
    for (final r in all) {
      counts[r.category] = (counts[r.category] ?? 0) + 1;
    }

    // Na mobile sa po výbere kategórie prepne na zoznam receptov.
    void openList() {
      if (!wide) setState(() => _mobileShowRecipes = true);
    }

    final categoryPane = CategoryPane(
      header: kIsWeb ? WebSyncCard(lastBackup: store.lastBackupDate, onImport: _import) : null,
      categories: categories,
      counts: counts,
      total: all.length,
      favorites: all.where((r) => r.favorite).length,
      category: _category,
      favoritesOnly: _favoritesOnly,
      large: !wide,
      onAll: () {
        _selectAll();
        openList();
      },
      onFavorites: () {
        _selectFavorites();
        openList();
      },
      onCategory: (c) {
        _selectCategory(c);
        openList();
      },
    );

    final listPane = RecipeListPane(
      title: _filterTitle(s),
      recipes: recipes,
      searchCtrl: _searchCtrl,
      selectedId: wide ? _selectedId : null,
      onQuery: (q) => setState(() => _query = q),
      onOpen: (r) => _show(r.id, wide),
    );

    final showingRecipesOnMobile = !wide && _mobileShowRecipes;

    return PopScope(
      // Systémové „späť“ na mobile vráti zo zoznamu receptov na kategórie.
      canPop: !showingRecipesOnMobile,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _mobileShowRecipes = false);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: showingRecipesOnMobile
              ? BackButton(onPressed: () => setState(() => _mobileShowRecipes = false))
              : null,
          title: Text(showingRecipesOnMobile ? _filterTitle(s) : s.appTitle),
          actions: [
            if (kIsWeb)
              IconButton(
                tooltip: s.loadBackupTooltip,
                icon: const Icon(Icons.sync),
                onPressed: _import,
              ),
            _menu(s),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _chooseNewRecipe(wide),
          icon: const Icon(Icons.add),
          label: Text(s.newRecipe),
        ),
        body: wide
            ? Row(
                children: [
                  SizedBox(width: 210, child: categoryPane),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 330, child: listPane),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _selectedId == null
                        ? const _EmptyDetail()
                        : RecipeDetailView(
                            key: ValueKey(_selectedId),
                            recipeId: _selectedId!,
                            embedded: true,
                          ),
                  ),
                ],
              )
            : (showingRecipesOnMobile ? listPane : categoryPane),
      ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book, size: 88, color: scheme.outlineVariant),
          const SizedBox(height: 12),
          Text(S.of(context).pickRecipe, style: TextStyle(color: scheme.outline)),
          const SizedBox(height: 36),
          TheemisMark(width: 92, color: scheme.outline, opacity: 0.42),
        ],
      ),
    );
  }
}

/// Úvodná obrazovka: namiesto krúžiaceho indikátora pribúdajú písmená loga.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Na úzkom displeji sa logo zmestí menšie, ale nikdy pod čitateľnú hranicu.
    final markWidth = (width * 0.56).clamp(kTheemisMinWidth, 280.0);
    return Scaffold(
      body: Center(
        child: TheemisMarkAnimated(
          width: markWidth,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
