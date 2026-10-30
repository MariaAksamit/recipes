# Moje recepty

Osobná kuchárka pre počítač a mobil, napísaná vo Flutteri.
Recepty ostávajú v zariadení — žiadny účet, žiadny server, funguje aj bez internetu.

*A personal cookbook for desktop and mobile, written in Flutter.
Recipes stay on the device — no account, no server, works offline.*

---

## Slovensky

### Čo to je

Aplikácia na vlastnú zbierku receptov. Beží ako program na Windows a zároveň ako
webová aplikácia (PWA), ktorú si na telefóne pridáš na plochu a potom funguje
rovnako ako nainštalovaná apka.

V aplikácii je **šesť ukážkových receptov**, aby bolo vidieť, ako to vyzerá.
Vlastné recepty si pridáš sám a uložia sa len u teba — nikam sa neodosielajú.

### Čo vie

- **Vyhľadávanie** podľa názvu aj surovín, bez ohľadu na diakritiku — „gulas“ nájde „Guláš“.
- **Kategórie** a označovanie receptov ako obľúbených.
- **Prepočet dávky** ½×, 1×, 1½×, 2×, 3× — množstvá sa prepočítajú vrátane zlomkov a rozsahov („3–4 zemiaky“).
- **Odškrtávanie surovín** pri varení.
- **Fotka ku každému receptu**, s voliteľným výrezom.
- **Pridanie receptu** ručne, vložením textu alebo z odkazu na webovú stránku.
- **Export do Wordu** — titulná strana, obsah s číslami strán, každý recept na samostatnej strane.
- **Záloha a obnova** všetkých receptov aj s fotkami do jedného súboru; takto sa recepty prenesú medzi počítačom a telefónom.
- **Svetlý a tmavý vzhľad**, alebo podľa nastavenia zariadenia.
- **Slovenčina a angličtina.**
- **Režim varenia** (vo webovej verzii) — displej počas varenia nezhasne.

Na širokej obrazovke sú kategórie, zoznam a detail vedľa seba; na mobile sa
prechádza po jednotlivých obrazovkách.

### Inštalácia

**Windows** — v časti [Releases](../../releases) stiahni ZIP, rozbaľ ho celý
a spusti `recepty.exe`. Program nie je podpísaný certifikátom, takže Windows
pri prvom spustení ukáže hlášku SmartScreen: *Ďalšie informácie → Spustiť aj tak*.
Súbor `recepty.exe` sa musí spúšťať z rozbaleného priečinka — bez súborov,
ktoré sú vedľa neho, sa nespustí.

**Telefón a tablet** — otvor webovú verziu a pridaj si ju na plochu:

- iPhone (Safari): *Zdieľať → Pridať na plochu*
- Android (Chrome): *⋮ → Pridať na plochu*
- Počítač (Chrome/Edge): ikona *Inštalovať* v adresnom riadku

Po prvom otvorení apka funguje aj bez internetu.

### Vývoj a build

Treba Flutter 3.35 alebo novší ([návod na inštaláciu](https://docs.flutter.dev/get-started/install)).

```
git clone https://github.com/MariaAksamit/recipes.git
cd recipes
flutter pub get
flutter test
```

Spustenie:

```
flutter run -d windows     # alebo -d chrome
```

Build:

```
flutter build windows --release
flutter build web --release --base-href /recipes/
```

Výsledok je v `build\windows\x64\runner\Release\`, respektíve v `build\web\`.
Parameter `--base-href` musí sedieť s cestou, na ktorej bude webová verzia
bežať; pri GitHub Pages je to názov repozitára.

> **Nespúšťaj `flutter create` v tomto priečinku.** Systémové priečinky
> (`windows/`, `android/`…) sú súčasťou repozitára a `flutter create` by
> prepísal úpravy v `windows/runner/`.

### Štruktúra

| Priečinok | Čo v ňom je |
|---|---|
| `lib/data/` | ukladanie receptov, zálohy, import z textu a z webu |
| `lib/screens/` | hlavná obrazovka, detail a úprava receptu |
| `lib/widgets/` | zoznam, panel kategórií, fotka, podpis autora |
| `lib/l10n/` | všetky texty v slovenčine a angličtine |
| `lib/utils/` | export do Wordu, zdieľanie, prepočet množstiev |
| `tool/gen_logo.py` | prevedie SVG loga na cesty v `lib/widgets/theemis_logo_paths.dart` |

### Autor

Dizajn a vývoj **Theemis**.

Kód je voľný na použitie a úpravu. Logo Theemis a názov sú autorské —
ak si apku upravíš a budeš ju šíriť ďalej, nahraď ich, prosím, svojimi.

---

## English

### What it is

An app for your own recipe collection. It runs as a Windows program and as a
web app (PWA) that installs to the home screen of a phone and behaves like a
native app from then on.

The app ships with **six sample recipes** so you can see how it looks.
Your own recipes are stored only on your device — nothing is uploaded anywhere.

### Features

- **Search** by title and by ingredients, accent-insensitive — "gulas" finds "Guláš".
- **Categories** and favourites.
- **Batch scaling** ½×, 1×, 1½×, 2×, 3× — quantities are recalculated, including fractions and ranges ("3–4 potatoes").
- **Tick off ingredients** while cooking.
- **A photo per recipe**, with an adjustable crop.
- **Add a recipe** by hand, by pasting text, or from a web link.
- **Word export** — title page, table of contents with page numbers, one recipe per page.
- **Backup and restore** of all recipes including photos in a single file; this is how recipes move between computer and phone.
- **Light and dark theme**, or follow the device setting.
- **Slovak and English.**
- **Cooking mode** (web version) — keeps the screen awake while you cook.

On a wide screen the categories, list and detail sit side by side; on a phone
you move between separate screens.

### Install

**Windows** — download the ZIP from [Releases](../../releases), extract the whole
folder and run `recepty.exe`. The program is not code-signed, so Windows shows a
SmartScreen prompt on first run: *More info → Run anyway*. `recepty.exe` must be
started from the extracted folder — it will not run without the files next to it.

**Phone and tablet** — open the web version and add it to your home screen:

- iPhone (Safari): *Share → Add to Home Screen*
- Android (Chrome): *⋮ → Add to Home screen*
- Desktop (Chrome/Edge): the *Install* icon in the address bar

After the first visit the app works offline.

### Development

Requires Flutter 3.35 or newer ([install guide](https://docs.flutter.dev/get-started/install)).

```
git clone https://github.com/MariaAksamit/recipes.git
cd recipes
flutter pub get
flutter test
flutter run -d windows     # or -d chrome
```

Builds:

```
flutter build windows --release
flutter build web --release --base-href /recipes/
```

Output lands in `build\windows\x64\runner\Release\` and `build\web\`.
`--base-href` must match the path the web version is served from; on GitHub
Pages that is the repository name.

> **Do not run `flutter create` in this folder.** The platform directories
> (`windows/`, `android/`…) are part of the repository and `flutter create`
> would overwrite the changes in `windows/runner/`.

### Author

Design and development by **Theemis**.

The code is free to use and modify. The Theemis logo and name are not —
if you fork the app and publish it, please replace them with your own.
