import 'package:flutter/widgets.dart';

/// Texty aplikácie v slovenčine a angličtine.
///
/// Použitie vo widgete: `final s = S.of(context);` a potom `s.save`, `s.recipeCount(3)`…
/// Recepty samotné sa neprekladajú – ostávajú tak, ako ich napíšeš.
///
/// Nový text pridáš tak, že ho dopíšeš do [S] a do oboch tried [SSk] a [SEn]
/// (kompilátor upozorní, ak niekde chýba).
abstract class S {
  const S();

  static const supportedLanguages = ['sk', 'en'];

  static S of(BuildContext context) => forLanguage(Localizations.localeOf(context).languageCode);

  static S forLanguage(String code) => code == 'en' ? const SEn() : const SSk();

  String get languageCode;
  String get languageName; // názov jazyka v ňom samom

  // ---------------------------------------------------------------- všeobecné
  String get appTitle;
  String get cancel;
  String get save;
  String get delete;
  String get edit;
  String get share;
  String get more;
  String get clear;
  String get language;
  String get dataLoadFailed;
  String get appearance;
  String get themeSystem;
  String get themeLight;
  String get themeDark;
  String get aboutApp;
  String get aboutBody;
  String get aboutAuthor;
  String recipeCount(int n);
  String ingredientCount(int n);
  String date(DateTime d);

  /// Zobrazovaný názov kategórie (uložený názov je vždy slovenský).
  String category(String storedName);

  // ---------------------------------------------------------------- domov
  String get categories;
  String get favorites;
  String get all;
  String get allRecipes;
  String get searchHint;
  String get nothingFound;
  String get pickRecipe;
  String get newRecipe;
  String get writeManually;
  String get writeManuallySubtitle;
  String get loadRecipe;
  String get loadRecipeSubtitle;
  String get exportWord;
  String get saveBackup;
  String get loadBackup;
  String get loadBackupTooltip;
  String get saveBackupDialog;
  String get pickBackupDialog;
  String get backupSaved;
  String backupSaveFailed(Object e);
  String recipesLoaded(int n);
  String fileLoadFailed(Object e);
  String get searchResults;
  String onlyShown(String label);
  String get nothingToExport;
  String get saveWordDialog;
  String get wordSaved;
  String wordFailed(Object e);
  String get backupFileName;
  String get wordFileName;

  // web (iPhone)

  // ---------------------------------------------------------------- detail
  String get addFavorite;
  String get removeFavorite;
  String get deleteRecipeTitle;
  String deleteRecipeBody(String title);
  String get portion;
  String get ingredients;
  String get noIngredients;
  String get steps;
  String get noSteps;
  String get cookingMode;
  String get cookingModeOff;
  String get cookingOn;
  String get cookingOnNoWakeLock;

  // ---------------------------------------------------------------- úprava
  String get editRecipe;
  String get pickPhotoDialog;
  String photoLoadFailed(Object e);
  String recipeSaveFailed(Object e);
  String get dragPhotoHint;
  String get remove;
  String get addPhoto;
  String get changePhoto;
  String get recipeName;
  String get enterName;
  String get categoryLabel;
  String get ingredientsHelp;
  String get ingredientsHint;
  String get stepsHelp;
  String get stepsHint;
  String get notes;
  String get notesHint;

  // ---------------------------------------------------------------- zdieľanie
  String get shareSystem;
  String get shareSystemSubtitle;
  String get shareEmail;
  String get copyText;
  String get copied;
  String shareFailed(Object e);
  String emailSubject(String title);
  String get emailFailed;

  // ---------------------------------------------------------------- načítanie receptu
  String get loading;
  String get loadFromLink;
  String get createFromText;
  String get linkLabel;
  String get loadIntro;
  String get writeRecipeManually;
  String get loadViaAi;
  String get aiStep1;
  String get aiStep1Help;
  String get copyAiPrompt;
  String get copiedShort;
  String get aiStep2;
  String get textHint;
  String loadFailed(Object e);

  // text receptu (zdieľanie, AI) – nadpisy, ktoré vie aplikácia znova načítať
  String get hTitle;
  String get hCategory;
  String get hIngredients;
  String get hSteps;
  String get hNotes;
  String aiPrompt(String? url);
  String get textNoContent;
  String get untitledRecipe;

  // recept z webu
  String get webNoRecipe;
  String get webEmpty;
  String get webEnterLink;
  String get webInvalidLink;
  String webHttpError(int code);
  String get webOffline;
  String get webBlockedByBrowser;
  String webDownloadFailed(Object e);
  String get webRecipeTitle;
  String servings(String v);
  String totalTime(String v);
  String source(String url);
  String get acceptLanguage;

  // Word
  String get wordContents;
  String get wordNote;
}

// ============================================================================
// Slovenčina
// ============================================================================

class SSk extends S {
  const SSk();

  @override
  String get languageCode => 'sk';
  @override
  String get languageName => 'Slovenčina';

  @override
  String get appTitle => 'Moje recepty';
  @override
  String get cancel => 'Zrušiť';
  @override
  String get save => 'Uložiť';
  @override
  String get delete => 'Vymazať';
  @override
  String get edit => 'Upraviť';
  @override
  String get share => 'Zdieľať';
  @override
  String get more => 'Viac';
  @override
  String get clear => 'Vymazať';
  @override
  String get language => 'Jazyk';
  @override
  String get dataLoadFailed =>
      'Uložené recepty sa nepodarilo prečítať. Poškodený súbor je odložený '
      'v priečinku aplikácie a apka začala s ukážkovými receptami – '
      'načítaj poslednú zálohu.';
  @override
  String get appearance => 'Vzhľad';
  @override
  String get themeSystem => 'Podľa zariadenia';
  @override
  String get themeLight => 'Svetlý';
  @override
  String get themeDark => 'Tmavý';
  @override
  String get aboutApp => 'O aplikácii';
  @override
  String get aboutBody =>
      'Osobná kuchárka pre mobil aj počítač. Recepty sú uložené len '
      'v tomto zariadení – zálohu si vieš kedykoľvek vytvoriť cez menu.';
  @override
  String get aboutAuthor => 'Dizajn a vývoj';

  @override
  String recipeCount(int n) {
    if (n == 1) return '1 recept';
    if (n >= 2 && n <= 4) return '$n recepty';
    return '$n receptov';
  }

  @override
  String ingredientCount(int n) {
    if (n == 1) return '1 surovina';
    if (n >= 2 && n <= 4) return '$n suroviny';
    return '$n surovín';
  }

  @override
  String date(DateTime d) => '${d.day}. ${d.month}. ${d.year}';

  @override
  String category(String storedName) => storedName;

  @override
  String get categories => 'Kategórie';
  @override
  String get favorites => 'Obľúbené';
  @override
  String get all => 'Všetky';
  @override
  String get allRecipes => 'Všetky recepty';
  @override
  String get searchHint => 'Hľadať recept alebo surovinu…';
  @override
  String get nothingFound => 'Nič sa nenašlo.';
  @override
  String get pickRecipe => 'Vyber si recept zo zoznamu';
  @override
  String get newRecipe => 'Nový recept';
  @override
  String get writeManually => 'Napísať ručne';
  @override
  String get writeManuallySubtitle => 'Prázdny recept na vyplnenie';
  @override
  String get loadRecipe => 'Načítať recept';
  @override
  String get loadRecipeSubtitle => 'Z odkazu na web, z textu alebo fotky pomocou AI';
  @override
  String get exportWord => 'Export do Wordu';
  @override
  String get saveBackup => 'Uložiť zálohu';
  @override
  String get loadBackup => 'Načítať zálohu';
  @override
  String get loadBackupTooltip => 'Načítať recepty zo zálohy';
  @override
  String get saveBackupDialog => 'Uložiť zálohu receptov';
  @override
  String get pickBackupDialog => 'Vyber zálohu receptov';
  @override
  String get backupSaved => 'Záloha uložená.';
  @override
  String backupSaveFailed(Object e) => 'Zálohu sa nepodarilo uložiť: $e';
  @override
  String recipesLoaded(int n) => 'Načítané recepty: $n';
  @override
  String fileLoadFailed(Object e) => 'Súbor sa nepodarilo načítať: $e';
  @override
  String get searchResults => 'Výsledky hľadania';
  @override
  String onlyShown(String label) => 'Len zobrazené: $label';
  @override
  String get nothingToExport => 'Nie sú tu žiadne recepty na export.';
  @override
  String get saveWordDialog => 'Uložiť recepty do Wordu';
  @override
  String get wordSaved => 'Recepty sú uložené vo Worde.';
  @override
  String wordFailed(Object e) => 'Export do Wordu sa nepodaril: $e';
  @override
  String get backupFileName => 'recepty_zaloha';
  @override
  String get wordFileName => 'moje_recepty';


  @override
  String get addFavorite => 'Pridať do obľúbených';
  @override
  String get removeFavorite => 'Odobrať z obľúbených';
  @override
  String get deleteRecipeTitle => 'Vymazať recept?';
  @override
  String deleteRecipeBody(String title) => 'Recept „$title“ sa natrvalo vymaže.';
  @override
  String get portion => 'Dávka:';
  @override
  String get ingredients => 'Suroviny';
  @override
  String get noIngredients => 'Bez surovín';
  @override
  String get steps => 'Postup';
  @override
  String get noSteps => 'Postup zatiaľ nie je zapísaný.';
  @override
  String get cookingMode => 'Režim varenia';
  @override
  String get cookingModeOff => 'Vypnúť režim varenia';
  @override
  String get cookingOn => 'Režim varenia: displej nezhasne a písmo je väčšie.';
  @override
  String get cookingOnNoWakeLock =>
      'Režim varenia: písmo je väčšie. Tento prehliadač nevie nechať displej zapnutý.';

  @override
  String get editRecipe => 'Upraviť recept';
  @override
  String get pickPhotoDialog => 'Vyber fotku jedla';
  @override
  String photoLoadFailed(Object e) => 'Fotku sa nepodarilo načítať: $e';
  @override
  String recipeSaveFailed(Object e) => 'Recept sa nepodarilo uložiť: $e';
  @override
  String get dragPhotoHint => 'Potiahni fotku a posuň výrez';
  @override
  String get remove => 'Odstrániť';
  @override
  String get addPhoto => 'Pridať fotku';
  @override
  String get changePhoto => 'Zmeniť fotku';
  @override
  String get recipeName => 'Názov receptu';
  @override
  String get enterName => 'Zadaj názov';
  @override
  String get categoryLabel => 'Kategória';
  @override
  String get ingredientsHelp =>
      'Každá surovina na nový riadok, napr. „500 g hladká múka“. '
      'Skupinu označ riadkom s dvojbodkou, napr. „Cesto:“.';
  @override
  String get ingredientsHint => 'Cesto:\n500 g hladká múka\n2 vajcia\n½ droždie';
  @override
  String get stepsHelp => 'Každý krok na nový riadok.';
  @override
  String get stepsHint => 'Zmiesiť cesto a nechať nakysnúť.\n\nPiecť 30 minút na 180 °C.';
  @override
  String get notes => 'Poznámky';
  @override
  String get notesHint => 'Tipy, obmeny, odkiaľ je recept…';

  @override
  String get shareSystem => 'Zdieľať…';
  @override
  String get shareSystemSubtitle => 'WhatsApp, Messenger, e-mail, správa…';
  @override
  String get shareEmail => 'Poslať e-mailom';
  @override
  String get copyText => 'Kopírovať text receptu';
  @override
  String get copied => 'Recept je skopírovaný – môžeš ho vložiť kamkoľvek.';
  @override
  String shareFailed(Object e) => 'Zdieľanie sa nepodarilo: $e';
  @override
  String emailSubject(String title) => 'Recept: $title';
  @override
  String get emailFailed =>
      'E-mailová aplikácia sa neotvorila – text receptu je skopírovaný v schránke.';

  @override
  String get loading => 'Načítavam…';
  @override
  String get loadFromLink => 'Načítať z odkazu';
  @override
  String get createFromText => 'Vytvoriť recept z textu';
  @override
  String get linkLabel => 'Odkaz na recept (nepovinné)';
  @override
  String get loadIntro =>
      'S odkazom sa recept načíta zo stránky a otvorí sa na úpravu. '
      'Ak sa načítať nedá, pomôže AI – postup je nižšie.';
  @override
  String get writeRecipeManually => 'Napísať recept ručne';
  @override
  String get loadViaAi => 'Načítať cez AI';
  @override
  String get aiStep1 =>
      '1. Skopíruj pokyn a vlož ho do ChatGPT, Gemini, Copilota alebo Clauda – '
      'stačí bezplatná verzia.';
  @override
  String get aiStep1Help =>
      'Ak je vyššie vyplnený odkaz, pokyn ho už obsahuje a AI recept '
      'otvorí. Ak odkaz nie je, pošli AI spolu s pokynom aj fotku '
      'alebo text receptu – AI ho prepíše do správnej podoby.';
  @override
  String get copyAiPrompt => 'Skopírovať pokyn pre AI';
  @override
  String get copiedShort => 'Skopírované';
  @override
  String get aiStep2 =>
      '2. Odpoveď od AI skopíruj a vlož sem. Dá sa sem vložiť aj recept '
      'poslaný z tejto aplikácie.';
  @override
  String get textHint => 'NÁZOV: …\nSUROVINY:\n…\nPOSTUP:\n…';
  @override
  String loadFailed(Object e) => 'Recept sa nepodarilo načítať: $e';

  @override
  String get hTitle => 'NÁZOV';
  @override
  String get hCategory => 'Kategória';
  @override
  String get hIngredients => 'SUROVINY';
  @override
  String get hSteps => 'POSTUP';
  @override
  String get hNotes => 'POZNÁMKY';

  @override
  String aiPrompt(String? url) {
    final source = (url == null || url.trim().isEmpty)
        ? 'Prepíš tento recept (vložím ho nižšie ako text alebo fotku)'
        : 'Otvor tento recept: ${url.trim()}\n\nPrepíš ho';
    return '''$source do slovenčiny presne v tomto tvare:

NÁZOV: názov receptu
SUROVINY:
200 g hladká múka
2 PL olej
POSTUP:
1. prvý krok
2. druhý krok
POZNÁMKY: počet porcií, čas prípravy, tipy (ak nejaké sú)

Pravidlá:
- celý recept daj do JEDNÉHO bloku kódu (```), aby sa pri kopírovaní nespojili riadky
- každá surovina na samostatnom riadku, množstvo a jednotka vždy na začiatku (g, kg, ml, l, PL, ČL, ks)
- ak má recept viac častí (napr. cesto a krém), napíš pred ich suroviny nadpis s dvojbodkou na samostatný riadok, napr. „Cesto:“
- postup rozdeľ na rozumné kroky: súvisiace vety spoj do jedného kroku (radšej 4 – 8 dlhších krokov ako každá veta zvlášť); pri viacerých častiach môže krok začínať napr. „Krém: …“
- nepíš nič iné – žiadny úvod ani záver, nepoužívaj tučné písmo ani odrážky''';
  }

  @override
  String get textNoContent =>
      'V texte sa nenašli suroviny ani postup. Skontroluj, či obsahuje riadky „SUROVINY:“ a „POSTUP:“.';
  @override
  String get untitledRecipe => 'Nový recept';

  @override
  String get webNoRecipe =>
      'Na tejto stránke sa nenašiel recept v štandardnom formáte. '
      'Recept sa dá pridať ručne alebo ho prepíše AI – postup je nižšie.';
  @override
  String get webEmpty => 'Recept na stránke je prázdny.';
  @override
  String get webEnterLink => 'Zadaj odkaz na recept.';
  @override
  String get webInvalidLink => 'Toto nie je platný odkaz.';
  @override
  String webHttpError(int code) => 'Stránka vrátila chybu $code.';
  @override
  String get webOffline => 'Stránku sa nepodarilo otvoriť. Skontroluj internet a odkaz.';
  @override
  String get webBlockedByBrowser =>
      'Prehliadač nepustil túto stránku (ochrana CORS). Skús to v aplikácii na počítači, '
      'alebo nižšie skopíruj pokyn pre AI a vlož sem text receptu.';
  @override
  String webDownloadFailed(Object e) => 'Stránku sa nepodarilo stiahnuť ($e).';
  @override
  String get webRecipeTitle => 'Recept z webu';
  @override
  String servings(String v) => 'Počet porcií: $v';
  @override
  String totalTime(String v) => 'Celkový čas: $v';
  @override
  String source(String url) => 'Zdroj: $url';
  @override
  String get acceptLanguage => 'sk,cs;q=0.9,en;q=0.8';

  @override
  String get wordContents => 'Obsah';
  @override
  String get wordNote => 'Poznámka:';
}

// ============================================================================
// English
// ============================================================================

class SEn extends S {
  const SEn();

  @override
  String get languageCode => 'en';
  @override
  String get languageName => 'English';

  @override
  String get appTitle => 'My Recipes';
  @override
  String get cancel => 'Cancel';
  @override
  String get save => 'Save';
  @override
  String get delete => 'Delete';
  @override
  String get edit => 'Edit';
  @override
  String get share => 'Share';
  @override
  String get more => 'More';
  @override
  String get clear => 'Clear';
  @override
  String get language => 'Language';
  @override
  String get dataLoadFailed =>
      'Stored recipes could not be read. The damaged file was set aside and '
      'the app started with the sample recipes – load your latest backup.';
  @override
  String get appearance => 'Appearance';
  @override
  String get themeSystem => 'Match device';
  @override
  String get themeLight => 'Light';
  @override
  String get themeDark => 'Dark';
  @override
  String get aboutApp => 'About';
  @override
  String get aboutBody =>
      'A personal cookbook for phone and computer. Recipes are stored on '
      'this device only – a backup can be made any time from the menu.';
  @override
  String get aboutAuthor => 'Design and development';

  @override
  String recipeCount(int n) => n == 1 ? '1 recipe' : '$n recipes';
  @override
  String ingredientCount(int n) => n == 1 ? '1 ingredient' : '$n ingredients';
  @override
  String date(DateTime d) => '${d.day}/${d.month}/${d.year}';

  static const _categories = {
    'Hlavné jedlá': 'Main dishes',
    'Polievky': 'Soups',
    'Múčne jedlá a iné': 'Flour dishes & more',
    'Marinády a omáčky': 'Marinades & sauces',
    'Koláče a dezerty': 'Cakes & desserts',
    'Krémy': 'Creams & fillings',
    'Pečivo': 'Bread & pastries',
    'Ostatné': 'Other',
  };

  @override
  String category(String storedName) => _categories[storedName] ?? storedName;

  @override
  String get categories => 'Categories';
  @override
  String get favorites => 'Favourites';
  @override
  String get all => 'All';
  @override
  String get allRecipes => 'All recipes';
  @override
  String get searchHint => 'Search recipes or ingredients…';
  @override
  String get nothingFound => 'Nothing found.';
  @override
  String get pickRecipe => 'Pick a recipe from the list';
  @override
  String get newRecipe => 'New recipe';
  @override
  String get writeManually => 'Write it yourself';
  @override
  String get writeManuallySubtitle => 'An empty recipe to fill in';
  @override
  String get loadRecipe => 'Import a recipe';
  @override
  String get loadRecipeSubtitle => 'From a web link, from text or from a photo using AI';
  @override
  String get exportWord => 'Export to Word';
  @override
  String get saveBackup => 'Save backup';
  @override
  String get loadBackup => 'Load backup';
  @override
  String get loadBackupTooltip => 'Load recipes from a backup';
  @override
  String get saveBackupDialog => 'Save recipe backup';
  @override
  String get pickBackupDialog => 'Choose a recipe backup';
  @override
  String get backupSaved => 'Backup saved.';
  @override
  String backupSaveFailed(Object e) => 'Could not save the backup: $e';
  @override
  String recipesLoaded(int n) => 'Recipes loaded: $n';
  @override
  String fileLoadFailed(Object e) => 'Could not load the file: $e';
  @override
  String get searchResults => 'Search results';
  @override
  String onlyShown(String label) => 'Only shown: $label';
  @override
  String get nothingToExport => 'There are no recipes to export.';
  @override
  String get saveWordDialog => 'Save recipes to Word';
  @override
  String get wordSaved => 'Recipes saved to Word.';
  @override
  String wordFailed(Object e) => 'Export to Word failed: $e';
  @override
  String get backupFileName => 'recipes_backup';
  @override
  String get wordFileName => 'my_recipes';


  @override
  String get addFavorite => 'Add to favourites';
  @override
  String get removeFavorite => 'Remove from favourites';
  @override
  String get deleteRecipeTitle => 'Delete recipe?';
  @override
  String deleteRecipeBody(String title) => 'The recipe “$title” will be deleted permanently.';
  @override
  String get portion => 'Amount:';
  @override
  String get ingredients => 'Ingredients';
  @override
  String get noIngredients => 'No ingredients';
  @override
  String get steps => 'Method';
  @override
  String get noSteps => 'The method has not been written yet.';
  @override
  String get cookingMode => 'Cooking mode';
  @override
  String get cookingModeOff => 'Turn off cooking mode';
  @override
  String get cookingOn => 'Cooking mode: the screen stays on and the text is larger.';
  @override
  String get cookingOnNoWakeLock =>
      'Cooking mode: the text is larger. This browser cannot keep the screen on.';

  @override
  String get editRecipe => 'Edit recipe';
  @override
  String get pickPhotoDialog => 'Choose a photo of the dish';
  @override
  String photoLoadFailed(Object e) => 'Could not load the photo: $e';
  @override
  String recipeSaveFailed(Object e) => 'Could not save the recipe: $e';
  @override
  String get dragPhotoHint => 'Drag the photo to adjust the crop';
  @override
  String get remove => 'Remove';
  @override
  String get addPhoto => 'Add photo';
  @override
  String get changePhoto => 'Change photo';
  @override
  String get recipeName => 'Recipe name';
  @override
  String get enterName => 'Enter a name';
  @override
  String get categoryLabel => 'Category';
  @override
  String get ingredientsHelp =>
      'One ingredient per line, e.g. “500 g plain flour”. '
      'Mark a group with a line ending in a colon, e.g. “Dough:”.';
  @override
  String get ingredientsHint => 'Dough:\n500 g plain flour\n2 eggs\n½ yeast';
  @override
  String get stepsHelp => 'One step per line.';
  @override
  String get stepsHint => 'Knead the dough and let it rise.\n\nBake for 30 minutes at 180 °C.';
  @override
  String get notes => 'Notes';
  @override
  String get notesHint => 'Tips, variations, where the recipe comes from…';

  @override
  String get shareSystem => 'Share…';
  @override
  String get shareSystemSubtitle => 'WhatsApp, Messenger, e-mail, message…';
  @override
  String get shareEmail => 'Send by e-mail';
  @override
  String get copyText => 'Copy recipe text';
  @override
  String get copied => 'Recipe copied – you can paste it anywhere.';
  @override
  String shareFailed(Object e) => 'Sharing failed: $e';
  @override
  String emailSubject(String title) => 'Recipe: $title';
  @override
  String get emailFailed => 'The e-mail app did not open – the recipe text is in the clipboard.';

  @override
  String get loading => 'Loading…';
  @override
  String get loadFromLink => 'Load from link';
  @override
  String get createFromText => 'Create recipe from text';
  @override
  String get linkLabel => 'Recipe link (optional)';
  @override
  String get loadIntro =>
      'With a link, the recipe is loaded from the page and opened for editing. '
      'If that does not work, AI can help – see below.';
  @override
  String get writeRecipeManually => 'Write the recipe yourself';
  @override
  String get loadViaAi => 'Import with AI';
  @override
  String get aiStep1 =>
      '1. Copy the prompt and paste it into ChatGPT, Gemini, Copilot or Claude – '
      'the free version is enough.';
  @override
  String get aiStep1Help =>
      'If a link is filled in above, the prompt already contains it and the AI '
      'will open the recipe. Without a link, send the AI a photo or the text of the '
      'recipe together with the prompt – it will rewrite it into the right format.';
  @override
  String get copyAiPrompt => 'Copy AI prompt';
  @override
  String get copiedShort => 'Copied';
  @override
  String get aiStep2 =>
      '2. Copy the AI’s answer and paste it here. You can also paste a recipe '
      'shared from this app.';
  @override
  String get textHint => 'TITLE: …\nINGREDIENTS:\n…\nMETHOD:\n…';
  @override
  String loadFailed(Object e) => 'Could not load the recipe: $e';

  @override
  String get hTitle => 'TITLE';
  @override
  String get hCategory => 'Category';
  @override
  String get hIngredients => 'INGREDIENTS';
  @override
  String get hSteps => 'METHOD';
  @override
  String get hNotes => 'NOTES';

  @override
  String aiPrompt(String? url) {
    final source = (url == null || url.trim().isEmpty)
        ? 'Rewrite this recipe (I will paste it below as text or a photo)'
        : 'Open this recipe: ${url.trim()}\n\nRewrite it';
    return '''$source in English in exactly this format:

TITLE: recipe name
INGREDIENTS:
200 g plain flour
2 tbsp oil
METHOD:
1. first step
2. second step
NOTES: servings, preparation time, tips (if any)

Rules:
- put the whole recipe in ONE code block (```) so that the lines are not joined when copying
- each ingredient on its own line, always with the amount and unit first (g, kg, ml, l, tbsp, tsp, pcs)
- if the recipe has several parts (e.g. dough and filling), write a heading ending with a colon on its own line before their ingredients, e.g. “Dough:”
- split the method into sensible steps: join related sentences into one step (4–8 longer steps rather than every sentence separately); with several parts a step may start e.g. “Filling: …”
- do not write anything else – no introduction or conclusion, no bold text or bullet points''';
  }

  @override
  String get textNoContent =>
      'No ingredients or method were found in the text. Check that it contains the lines “INGREDIENTS:” and “METHOD:”.';
  @override
  String get untitledRecipe => 'New recipe';

  @override
  String get webNoRecipe =>
      'No recipe in the standard format was found on this page. '
      'You can add the recipe yourself or let AI rewrite it – see below.';
  @override
  String get webEmpty => 'The recipe on the page is empty.';
  @override
  String get webEnterLink => 'Enter a link to the recipe.';
  @override
  String get webInvalidLink => 'This is not a valid link.';
  @override
  String webHttpError(int code) => 'The page returned error $code.';
  @override
  String get webOffline => 'Could not open the page. Check your internet connection and the link.';
  @override
  String get webBlockedByBrowser =>
      'The browser blocked this page (CORS protection). Try the desktop app, or copy the AI '
      'prompt below and paste the recipe text here.';
  @override
  String webDownloadFailed(Object e) => 'Could not download the page ($e).';
  @override
  String get webRecipeTitle => 'Recipe from the web';
  @override
  String servings(String v) => 'Servings: $v';
  @override
  String totalTime(String v) => 'Total time: $v';
  @override
  String source(String url) => 'Source: $url';
  @override
  String get acceptLanguage => 'en;q=1.0,sk;q=0.8,cs;q=0.7';

  @override
  String get wordContents => 'Contents';
  @override
  String get wordNote => 'Note:';
}
