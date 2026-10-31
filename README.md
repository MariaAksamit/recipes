# Moje recepty

Osobná kuchárka pre počítač a mobil, napísaná vo Flutteri.
Recepty ostávajú v zariadení — žiadny účet, žiadny server, funguje aj bez internetu.

*A personal cookbook for desktop and mobile, written in Flutter.
Recipes stay on the device — no account, no server, works offline.*

---

## Slovensky

### Čo to je

Aplikácia na vlastnú zbierku receptov. Beží ako program na Windows, ako apka
na Androide a zároveň ako webová aplikácia (PWA), ktorú si na telefóne (aj na
iPhone) pridáš na plochu a potom funguje rovnako ako nainštalovaná apka.

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
- **Režim varenia** — displej počas varenia nezhasne.

Na širokej obrazovke sú kategórie, zoznam a detail vedľa seba; na mobile sa
prechádza po jednotlivých obrazovkách.

### Inštalácia

**Windows** — v časti [Releases](../../releases) stiahni ZIP, rozbaľ ho celý
a spusti `recepty.exe`. Program nie je podpísaný certifikátom, takže Windows
pri prvom spustení ukáže hlášku SmartScreen: *Ďalšie informácie → Spustiť aj tak*.
Súbor `recepty.exe` sa musí spúšťať z rozbaleného priečinka — bez súborov,
ktoré sú vedľa neho, sa nespustí.

**Android** — v časti [Releases](../../releases) stiahni súbor `.apk` a otvor ho
v telefóne. Android sa spýta, či povoliť inštaláciu z tohto zdroja — treba
potvrdiť, lebo apka nie je z Obchodu Play. Aktualizácia sa inštaluje cez
predchádzajúcu verziu, recepty v nej ostanú.

**iPhone, tablet, iný počítač** — otvor webovú verziu a pridaj si ju na plochu:

- iPhone (Safari): *Zdieľať → Pridať na plochu*
- Android (Chrome): *⋮ → Pridať na plochu*
- Počítač (Chrome/Edge): ikona *Inštalovať* v adresnom riadku

Po prvom otvorení apka funguje aj bez internetu.

> **Webovú verziu si na telefóne naozaj pridaj na plochu a otváraj ju odtiaľ.**
> Recepty sú v úložisku prehliadača a to nie je trvalé:
>
> - **Safari zmaže dáta stránky, ktorú si 7 dní neotvorila** — potichu, bez
>   upozornenia. Apky pridanej na plochu sa to netýka.
> - **„Vymazať históriu a dáta webov“ v nastaveniach Safari** recepty zmaže.
>   V Chrome ich zmaže až voľba *Súbory cookie a dáta stránok* — samotná
>   história nie.
> - Apka si pri štarte pýta od prehliadača trvalé úložisko, čo riziko znižuje,
>   ale nie je to záruka.
>
> Apka pridaná na plochu a tá istá stránka otvorená v prehliadači môžu mať
> **oddelené úložiská** — po pridaní na plochu teda môže byť apka prázdna
> a recepty do nej načítaš zo zálohy.
>
> Na Androide je spoľahlivejšia nainštalovaná `.apk` verzia a na Windows
> program — tie majú recepty v súboroch zariadenia a prehliadač ich nemaže.
> Nech už apku používaš kdekoľvek, **z času na čas si ulož zálohu**.

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
flutter build apk --release
```

Výsledok je v `build\windows\x64\runner\Release\`, v `build\web\`,
respektíve v `build\app\outputs\flutter-apk\`.
Parameter `--base-href` musí sedieť s cestou, na ktorej bude webová verzia
bežať; pri GitHub Pages je to názov repozitára.

#### Podpisovací kľúč pre Android

Android APK musí byť podpísané. Kľúč sa vyrába **raz** a potom sa odkladá —
bez neho sa už vydaná apka nedá aktualizovať, iba preinštalovať (a recepty
v nej by sa stratili). Vyrob si ho takto:

```
keytool -genkeypair -v -keystore recepty.jks -storetype PKCS12 ^
  -keyalg RSA -keysize 2048 -validity 10000 -alias recepty
```

`keytool` je súčasť JDK, ktoré prišlo s Android Studiom – býva v
`C:\Program Files\Android\Android Studio\jbr\bin\`. Keď tam nie je, cestu
vypíše `flutter doctor -v` v riadku *Java binary at*. V PowerShelli treba pred
cestu v úvodzovkách napísať `&`, inak ju berie ako text.

Súbor `recepty.jks` **nedávaj do repozitára** a odlož si ho aj s heslami
niekam, kde ho o rok nájdeš.

Aby ho použil lokálny build, vytvor súbor `android/key.properties`:

```
storeFile=C:\\cesta\\k\\recepty.jks
storePassword=...
keyAlias=recepty
keyPassword=...
```

Aby ho použil GitHub Actions, pridaj v *Settings → Secrets and variables →
Actions* štyri tajomstvá:

| Tajomstvo | Hodnota |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | obsah `recepty.jks` v base64 — v PowerShelli `[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:/dev/recepty-kluc/recepty.jks")) \| Set-Clipboard` a rovno vlož |
| `ANDROID_KEYSTORE_PASSWORD` | heslo k úložisku |
| `ANDROID_KEY_ALIAS` | `recepty` |
| `ANDROID_KEY_PASSWORD` | heslo ku kľúču |

Vydanie potom vznikne označením verzie:

```
git tag v1.0.1
git push --tags
```

Actions postavia APK a priložia ho k vydaniu. Webová verzia sa nasadzuje
sama po každom pushi do `main`.

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
| `android/` | nastavenie Android apky (ID `com.theemis.recepty`, ikona, podpis) |
| `.github/workflows/` | nasadenie webu na Pages a build APK k vydaniu |

### Autor

Dizajn a vývoj **Theemis**.

Kód je voľný na použitie a úpravu. Logo Theemis a názov sú autorské —
ak si apku upravíš a budeš ju šíriť ďalej, nahraď ich, prosím, svojimi.

---

## English

### What it is

An app for your own recipe collection. It runs as a Windows program, as an
Android app, and as a web app (PWA) that installs to the home screen of a phone
— iPhone included — and behaves like a native app from then on.

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
- **Cooking mode** — keeps the screen awake while you cook.

On a wide screen the categories, list and detail sit side by side; on a phone
you move between separate screens.

### Install

**Windows** — download the ZIP from [Releases](../../releases), extract the whole
folder and run `recepty.exe`. The program is not code-signed, so Windows shows a
SmartScreen prompt on first run: *More info → Run anyway*. `recepty.exe` must be
started from the extracted folder — it will not run without the files next to it.

**Android** — download the `.apk` from [Releases](../../releases) and open it on
the phone. Android will ask you to allow installation from this source, because
the app does not come from the Play Store. Updates install over the previous
version and keep your recipes.

**iPhone, tablet, other computers** — open the web version and add it to the
home screen:

- iPhone (Safari): *Share → Add to Home Screen*
- Android (Chrome): *⋮ → Add to Home screen*
- Desktop (Chrome/Edge): the *Install* icon in the address bar

After the first visit the app works offline.

> **On a phone, do add the web version to the home screen and open it from
> there.** Recipes live in browser storage, which is not permanent:
>
> - **Safari deletes the data of a site you have not opened for 7 days** —
>   silently. An app added to the home screen is exempt.
> - **"Clear History and Website Data" in Safari settings** deletes the
>   recipes. In Chrome only *Cookies and other site data* does; history alone
>   does not.
> - The app asks the browser for persistent storage at startup, which lowers
>   the risk but is not a guarantee.
>
> An app on the home screen and the same page in the browser may use
> **separate storage**, so a freshly added app can start out empty — load a
> backup into it.
>
> The installed `.apk` on Android and the Windows program are the safer
> places: they keep recipes in device files that no browser clears. Wherever
> you use the app, **save a backup now and then**.

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
flutter build apk --release
```

Output lands in `build\windows\x64\runner\Release\`, `build\web\` and
`build\app\outputs\flutter-apk\`.
`--base-href` must match the path the web version is served from; on GitHub
Pages that is the repository name.

#### Android signing key

An Android APK has to be signed. Create the key **once** and keep it — without
it a published app can no longer be updated, only reinstalled, which loses the
recipes stored in it.

```
keytool -genkeypair -v -keystore recepty.jks -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 -alias recepty
```

Never commit `recepty.jks`. For local builds create `android/key.properties`
with `storeFile`, `storePassword`, `keyAlias` and `keyPassword`. For GitHub
Actions add the secrets `ANDROID_KEYSTORE_BASE64` (the `.jks` base64-encoded),
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`.

A release is then cut by tagging:

```
git tag v1.0.1
git push --tags
```

Actions build the APK and attach it to the release. The web version deploys
itself on every push to `main`.

> **Do not run `flutter create` in this folder.** The platform directories
> (`windows/`, `android/`…) are part of the repository and `flutter create`
> would overwrite the changes in `windows/runner/`.

### Author

Design and development by **Theemis**.

The code is free to use and modify. The Theemis logo and name are not —
if you fork the app and publish it, please replace them with your own.
