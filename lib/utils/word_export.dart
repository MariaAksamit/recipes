import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../l10n/strings.dart';
import '../models/recipe.dart';

/// Export receptov do Wordu (.docx).
///
/// Úvodná strana s obsahom, potom každý recept na samostatnej strane:
/// kategória, názov, fotka (výrez ako v aplikácii), vľavo suroviny,
/// vpravo postup a nakoniec poznámky. Dole číslo strany.
///
/// [categoryColors] – farba kategórie ako hex bez '#', napr. 'B5523B'.
/// [images] – fotky receptov podľa ID receptu.
/// [strings] – jazyk nadpisov (Obsah, Suroviny, Postup…).
/// [logo] – PNG podpisu autora na titulnej strane (voliteľné).
Uint8List buildRecipesDocx({
  required List<Recipe> recipes,
  required String title,
  String? subtitle,
  Map<String, String> categoryColors = const {},
  Map<String, Uint8List> images = const {},
  Uint8List? logo,
  S strings = const SSk(),
}) {
  return _DocxBuilder(
    recipes: recipes,
    title: title,
    subtitle: subtitle,
    categoryColors: categoryColors,
    images: images,
    logo: logo,
    s: strings,
  ).build();
}

// ---------------------------------------------------------------------------
// Rozmery (twip = 1/20 bodu, EMU = 1/914400 palca)
// ---------------------------------------------------------------------------

const _pageW = 11906; // A4
const _pageH = 16838;
const _margin = 1134; // 2 cm
const _contentW = _pageW - 2 * _margin; // 9638
const _leftColW = 3700; // suroviny
const _rightColW = _contentW - _leftColW; // postup
const _emuPerCm = 360000;
const _logoW = 25 * _emuPerCm ~/ 10; // podpis autora v pätke prvej strany (2,5 cm)
const _photoW = 13 * _emuPerCm;
const _photoH = _photoW * 9 ~/ 16; // rovnaký pomer 16:9 ako v aplikácii

const _textColor = '2B2B2B';
const _mutedColor = '7A7A7A';
const _defaultColor = '5B6B7A';
const _headFont = 'Georgia';
const _bodyFont = 'Calibri';

class _Img {
  final String name; // image1.jpg
  final String relId;
  final Uint8List bytes;
  final int w, h;
  _Img(this.name, this.relId, this.bytes, this.w, this.h);
}

class _DocxBuilder {
  final List<Recipe> recipes;
  final String title;
  final String? subtitle;
  final Map<String, String> categoryColors;
  final Map<String, Uint8List> images;
  final Uint8List? logo;
  final S s;

  final _imgs = <_Img>[];
  _Img? _logoImg; // podpis v pätke prvej strany – vlastný vzťah vo footer2
  final _imgExt = <String>{};
  var _drawingId = 1;

  _DocxBuilder({
    required this.recipes,
    required this.title,
    required this.subtitle,
    required this.categoryColors,
    required this.images,
    required this.logo,
    required this.s,
  });

  String _color(String category) => categoryColors[category] ?? _defaultColor;

  Uint8List build() {
    _prepareLogo();
    final body = StringBuffer();
    _cover(body);
    for (var i = 0; i < recipes.length; i++) {
      _recipe(body, recipes[i], i);
    }
    body.write(_sectionProps());

    final archive = Archive();
    void add(String name, String content) {
      final b = utf8.encode(content);
      archive.addFile(ArchiveFile(name, b.length, b));
    }

    add('[Content_Types].xml', _contentTypes());
    add('_rels/.rels', _rootRels);
    add('docProps/core.xml', _core());
    add('docProps/app.xml', _app);
    add('word/document.xml', _document(body.toString()));
    add('word/styles.xml', _styles);
    add('word/settings.xml', _settings);
    add('word/footer1.xml', _footer);
    add('word/_rels/document.xml.rels', _documentRels());
    final mark = _logoImg;
    if (mark != null) {
      add('word/footer2.xml', _logoFooter(mark));
      add('word/_rels/footer2.xml.rels',
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="${mark.relId}" '
          'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
          'Target="media/${mark.name}"/>'
          '</Relationships>');
      archive.addFile(
          ArchiveFile('word/media/${mark.name}', mark.bytes.length, mark.bytes));
    }
    for (final img in _imgs) {
      archive.addFile(ArchiveFile('word/media/${img.name}', img.bytes.length, img.bytes));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  // ------------------------------------------------------------ úvodná strana

  void _cover(StringBuffer b) {
    b.write(_p('', spacingBefore: 2600));
    b.write(_p(_run(title, size: 64, color: _textColor, font: _headFont),
        align: 'center', spacingAfter: 120));
    b.write(_p('', align: 'center', borderBottom: 'B5523B', spacingAfter: 160, indLeft: 3600, indRight: 3600));
    if (subtitle != null && subtitle!.isNotEmpty) {
      b.write(_p(_run(subtitle!, size: 24, color: _mutedColor, italic: true),
          align: 'center', spacingAfter: 600));
    }

    // Obsah začína na vlastnej strane; podpis autora je v pätke prvej strany.
    b.write(_p(_run(s.wordContents, size: 30, color: _textColor, font: _headFont, bold: true),
        spacingAfter: 200, keepNext: true, pageBreakBefore: true));
    String? lastCat;
    for (var i = 0; i < recipes.length; i++) {
      final r = recipes[i];
      if (r.category != lastCat) {
        lastCat = r.category;
        b.write(_p(
          _run(s.category(r.category).toUpperCase(), size: 18, color: _color(r.category), bold: true, spacing: 20),
          spacingBefore: 200,
          spacingAfter: 60,
          keepNext: true,
        ));
      }
      b.write(_p(
        '<w:hyperlink w:anchor="${_bookmark(i)}" w:history="1">'
        '${_run(r.title, size: 21, color: _textColor)}</w:hyperlink>'
        '<w:r><w:tab/></w:r>'
        '${_pageRef(_bookmark(i))}',
        spacingAfter: 20,
        indLeft: 284,
        tabRight: _contentW,
      ));
    }
  }

  /// Pole, ktoré Word nahradí číslom strany so záložkou [name]. Číslo sa
  /// doplní pri otvorení dokumentu – v settings.xml je na to updateFields.
  String _pageRef(String name) {
    const rpr = '<w:rPr><w:color w:val="$_mutedColor"/><w:sz w:val="20"/></w:rPr>';
    return '<w:r>$rpr<w:fldChar w:fldCharType="begin"/></w:r>'
        '<w:r>$rpr<w:instrText xml:space="preserve"> PAGEREF $name \\h </w:instrText></w:r>'
        '<w:r>$rpr<w:fldChar w:fldCharType="separate"/></w:r>'
        '<w:r>$rpr<w:t>–</w:t></w:r>'
        '<w:r>$rpr<w:fldChar w:fldCharType="end"/></w:r>';
  }

  // ------------------------------------------------------------ recept

  String _bookmark(int i) => 'recept_${i + 1}';

  void _recipe(StringBuffer b, Recipe r, int index) {
    final color = _color(r.category);
    final tint = _mix(color, 0.08);

    // Kategória
    b.write(_p(
      '<w:bookmarkStart w:id="$index" w:name="${_bookmark(index)}"/>'
      '<w:bookmarkEnd w:id="$index"/>'
      '${_run(s.category(r.category).toUpperCase(), size: 18, color: color, bold: true, spacing: 30)}',
      pageBreakBefore: true,
      spacingAfter: 40,
      keepNext: true,
    ));
    // Názov (štýl Nadpis 1 – zobrazí sa aj v navigačnej table Wordu)
    b.write('<w:p><w:pPr><w:pStyle w:val="Heading1"/>'
        '<w:pBdr><w:bottom w:val="single" w:sz="12" w:space="6" w:color="$color"/></w:pBdr>'
        '</w:pPr>${_run(r.title)}</w:p>');

    // Fotka
    final img = _image(r);
    if (img != null) {
      b.write(_p(_drawing(img, r), align: 'center', spacingBefore: 120, spacingAfter: 240));
    }

    final hasIngredients = r.ingredients.any((l) => l.trim().isNotEmpty);
    final steps = r.steps.where((s) => s.trim().isNotEmpty).toList();

    final left = StringBuffer();
    if (hasIngredients) {
      left.write(_sectionHeading(s.ingredients, color));
      for (final line in r.ingredients) {
        final t = line.trim();
        if (t.isEmpty) continue;
        if (Recipe.isGroupHeader(t)) {
          left.write(_p(_run(t.substring(0, t.length - 1), size: 20, bold: true, color: color),
              spacingBefore: 140, spacingAfter: 40, keepNext: true));
        } else {
          left.write(_p(
            '${_run('•', color: color, bold: true)}<w:r><w:tab/></w:r>${_run(t, size: 20)}',
            spacingAfter: 50,
            indLeft: 227,
            hanging: 227,
            tab: 227,
          ));
        }
      }
    }

    final right = StringBuffer();
    if (steps.isNotEmpty) {
      right.write(_sectionHeading(s.steps, color));
      for (var i = 0; i < steps.length; i++) {
        right.write(_p(
          '${_run('${i + 1}.', color: color, bold: true, font: _headFont)}<w:r><w:tab/></w:r>${_run(steps[i].trim())}',
          spacingAfter: 140,
          indLeft: 397,
          hanging: 397,
          tab: 397,
        ));
      }
    }

    if (hasIngredients && steps.isNotEmpty) {
      b.write(_twoColumns(left.toString(), right.toString(), tint));
    } else if (hasIngredients) {
      b.write(_oneBox(left.toString(), tint));
    } else if (steps.isNotEmpty) {
      b.write(right.toString());
    }

    // Poznámky
    final notes = r.notes.trim();
    if (notes.isNotEmpty) {
      b.write(_p('', spacingAfter: 120));
      final lines = notes.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final text = i == 0
            ? '${_run('${s.wordNote}  ', bold: true, color: color, size: 20)}${_run(lines[i], size: 20, italic: true)}'
            : _run(lines[i], size: 20, italic: true);
        b.write(_p(text,
            shade: tint, borderLeft: color, spacingAfter: 0, indLeft: 170, indRight: 0));
      }
    }
  }

  String _sectionHeading(String text, String color) => _p(
        _run(text.toUpperCase(), size: 20, bold: true, color: color, spacing: 30),
        spacingAfter: 120,
        keepNext: true,
      );

  String _twoColumns(String left, String right, String tint) =>
      '<w:tbl><w:tblPr><w:tblW w:w="$_contentW" w:type="dxa"/>'
      '<w:tblLayout w:type="fixed"/>'
      '<w:tblBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/>'
      '<w:right w:val="nil"/><w:insideH w:val="nil"/><w:insideV w:val="nil"/></w:tblBorders>'
      '<w:tblCellMar><w:top w:w="0" w:type="dxa"/><w:left w:w="0" w:type="dxa"/>'
      '<w:bottom w:w="0" w:type="dxa"/><w:right w:w="0" w:type="dxa"/></w:tblCellMar>'
      '<w:tblLook w:val="0000"/></w:tblPr>'
      '<w:tblGrid><w:gridCol w:w="$_leftColW"/><w:gridCol w:w="$_rightColW"/></w:tblGrid>'
      '<w:tr>'
      '<w:tc><w:tcPr><w:tcW w:w="$_leftColW" w:type="dxa"/>'
      '<w:shd w:val="clear" w:color="auto" w:fill="$tint"/>'
      '<w:tcMar><w:top w:w="200" w:type="dxa"/><w:left w:w="220" w:type="dxa"/>'
      '<w:bottom w:w="200" w:type="dxa"/><w:right w:w="200" w:type="dxa"/></w:tcMar>'
      '</w:tcPr>$left</w:tc>'
      '<w:tc><w:tcPr><w:tcW w:w="$_rightColW" w:type="dxa"/>'
      '<w:tcMar><w:top w:w="200" w:type="dxa"/><w:left w:w="400" w:type="dxa"/>'
      '<w:bottom w:w="0" w:type="dxa"/><w:right w:w="0" w:type="dxa"/></w:tcMar>'
      '</w:tcPr>$right</w:tc>'
      '</w:tr></w:tbl>';

  String _oneBox(String content, String tint) =>
      '<w:tbl><w:tblPr><w:tblW w:w="$_contentW" w:type="dxa"/>'
      '<w:tblLayout w:type="fixed"/>'
      '<w:tblCellMar><w:top w:w="200" w:type="dxa"/><w:left w:w="220" w:type="dxa"/>'
      '<w:bottom w:w="200" w:type="dxa"/><w:right w:w="220" w:type="dxa"/></w:tblCellMar>'
      '<w:tblLook w:val="0000"/></w:tblPr>'
      '<w:tblGrid><w:gridCol w:w="$_contentW"/></w:tblGrid>'
      '<w:tr><w:tc><w:tcPr><w:tcW w:w="$_contentW" w:type="dxa"/>'
      '<w:shd w:val="clear" w:color="auto" w:fill="$tint"/></w:tcPr>$content</w:tc></w:tr></w:tbl>';

  // ------------------------------------------------------------ fotky

  _Img? _image(Recipe r) {
    final bytes = images[r.id];
    if (bytes == null) return null;
    return _addImage(bytes); // null = nepodporovaný formát (napr. HEIC, WebP)
  }

  /// Pridá obrázok do balíka a vráti jeho popis (alebo null, ak sa nedá čítať).
  _Img? _addImage(Uint8List bytes) {
    final info = _imageInfo(bytes);
    if (info == null) return null;
    final n = _imgs.length + 1;
    _imgExt.add(info.$1);
    final img = _Img('image$n.${info.$1}', 'rIdImg$n', bytes, info.$2, info.$3);
    _imgs.add(img);
    return img;
  }

  /// Obrázok bez výrezu, v zadanej šírke a s dopočítanou výškou.
  String _plainDrawing(_Img img, int width, String name) {
    final id = _drawingId++;
    final height = width * img.h ~/ img.w;
    return '<w:r><w:drawing>'
        '<wp:inline distT="0" distB="0" distL="0" distR="0">'
        '<wp:extent cx="$width" cy="$height"/>'
        '<wp:effectExtent l="0" t="0" r="0" b="0"/>'
        '<wp:docPr id="$id" name="${_esc(name)} $id"/>'
        '<wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/></wp:cNvGraphicFramePr>'
        '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic><pic:nvPicPr><pic:cNvPr id="$id" name="${img.name}"/><pic:cNvPicPr/></pic:nvPicPr>'
        '<pic:blipFill><a:blip r:embed="${img.relId}"/>'
        '<a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
        '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$width" cy="$height"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
        '</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>';
  }

  /// Pripraví podpis autora ako obrázok pätky prvej strany.
  void _prepareLogo() {
    final bytes = logo;
    if (bytes == null) return;
    final info = _imageInfo(bytes);
    if (info == null) return; // nepodporovaný formát – export beží bez podpisu
    _imgExt.add(info.$1);
    _logoImg = _Img('logo.${info.$1}', 'rIdLogo', bytes, info.$2, info.$3);
  }

  /// Pätka prvej strany: logo dole v strede, bez čísla strany.
  String _logoFooter(_Img mark) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
      'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
      '<w:p><w:pPr><w:jc w:val="center"/></w:pPr>'
      '${_plainDrawing(mark, _logoW, 'Theemis')}'
      '</w:p></w:ftr>';

  /// Vlastnosti sekcie – prvá strana má pätku s logom, ostatné s číslom strany.
  String _sectionProps() =>
      '<w:sectPr>'
      '<w:footerReference w:type="default" r:id="rIdFooter1"/>'
      '${_logoImg == null ? '' : '<w:footerReference w:type="first" r:id="rIdFooter2"/>'}'
      '<w:pgSz w:w="$_pageW" w:h="$_pageH"/>'
      '<w:pgMar w:top="$_margin" w:right="$_margin" w:bottom="$_margin" w:left="$_margin" '
      'w:header="567" w:footer="567" w:gutter="0"/>'
      '<w:titlePg/>'
      '</w:sectPr>';

  String _drawing(_Img img, Recipe r) {
    final id = _drawingId++;
    // Výrez ako v aplikácii (BoxFit.cover + zarovnanie imageX/imageY).
    const target = 16 / 9;
    final aspect = img.w / img.h;
    var l = 0, t = 0, rr = 0, bb = 0;
    if (aspect > target) {
      final excess = 1 - target / aspect;
      final left = excess * (r.imageX.clamp(-1.0, 1.0) + 1) / 2;
      l = (left * 100000).round();
      rr = ((excess - left) * 100000).round();
    } else if (aspect < target) {
      final excess = 1 - aspect / target;
      final top = excess * (r.imageY.clamp(-1.0, 1.0) + 1) / 2;
      t = (top * 100000).round();
      bb = ((excess - top) * 100000).round();
    }
    final name = _esc(r.title);
    return '<w:r><w:drawing>'
        '<wp:inline distT="0" distB="0" distL="0" distR="0">'
        '<wp:extent cx="$_photoW" cy="$_photoH"/>'
        '<wp:effectExtent l="0" t="0" r="0" b="0"/>'
        '<wp:docPr id="$id" name="Fotka $id" descr="$name"/>'
        '<wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/></wp:cNvGraphicFramePr>'
        '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic><pic:nvPicPr><pic:cNvPr id="$id" name="${img.name}"/><pic:cNvPicPr/></pic:nvPicPr>'
        '<pic:blipFill><a:blip r:embed="${img.relId}"/>'
        '<a:srcRect l="$l" t="$t" r="$rr" b="$bb"/>'
        '<a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
        '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$_photoW" cy="$_photoH"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
        '</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>';
  }

  // ------------------------------------------------------------ súčasti balíka

  String _contentTypes() {
    final sb = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>',
    );
    for (final ext in _imgExt) {
      sb.write('<Default Extension="$ext" ContentType="${_mime[ext]}"/>');
    }
    sb.write(
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
      '<Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>'
      '<Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>'
      '${_logoImg == null ? '' : '<Override PartName="/word/footer2.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>'}'
      '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
      '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
      '</Types>',
    );
    return sb.toString();
  }

  String _documentRels() {
    final sb = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '<Relationship Id="rIdSettings" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>'
      '<Relationship Id="rIdFooter1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>',
    );
    if (_logoImg != null) {
      sb.write('<Relationship Id="rIdFooter2" '
          'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" '
          'Target="footer2.xml"/>');
    }
    for (final img in _imgs) {
      sb.write('<Relationship Id="${img.relId}" '
          'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
          'Target="media/${img.name}"/>');
    }
    sb.write('</Relationships>');
    return sb.toString();
  }

  String _core() {
    final now = DateTime.now().toUtc().toIso8601String().split('.').first;
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        '<dc:title>${_esc(title)}</dc:title><dc:creator>Moje recepty</dc:creator>'
        '<dcterms:created xsi:type="dcterms:W3CDTF">${now}Z</dcterms:created>'
        '<dcterms:modified xsi:type="dcterms:W3CDTF">${now}Z</dcterms:modified>'
        '</cp:coreProperties>';
  }

  String _document(String body) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
      'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
      '<w:body>$body</w:body></w:document>';
}

// ---------------------------------------------------------------------------
// Pomocné funkcie pre XML
// ---------------------------------------------------------------------------

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    // znaky, ktoré XML nepovoľuje
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

/// Úsek textu. [size] je v polovičných bodoch (22 = 11 pt).
String _run(
  String text, {
  int? size,
  String? color,
  String? font,
  bool bold = false,
  bool italic = false,
  int? spacing,
}) {
  final pr = StringBuffer();
  if (font != null) pr.write('<w:rFonts w:ascii="$font" w:hAnsi="$font" w:cs="$font"/>');
  if (bold) pr.write('<w:b/>');
  if (italic) pr.write('<w:i/>');
  if (color != null) pr.write('<w:color w:val="$color"/>');
  if (spacing != null) pr.write('<w:spacing w:val="$spacing"/>');
  if (size != null) pr.write('<w:sz w:val="$size"/><w:szCs w:val="$size"/>');
  final rPr = pr.isEmpty ? '' : '<w:rPr>$pr</w:rPr>';
  return '<w:r>$rPr<w:t xml:space="preserve">${_esc(text)}</w:t></w:r>';
}

String _p(
  String runs, {
  String? align,
  int? spacingBefore,
  int? spacingAfter,
  int? indLeft,
  int? indRight,
  int? hanging,
  int? tab,
  int? tabRight,
  bool keepNext = false,
  bool pageBreakBefore = false,
  String? shade,
  String? borderLeft,
  String? borderBottom,
}) {
  final pr = StringBuffer();
  if (keepNext) pr.write('<w:keepNext/>');
  if (pageBreakBefore) pr.write('<w:pageBreakBefore/>');
  if (borderLeft != null || borderBottom != null) {
    pr.write('<w:pBdr>');
    if (borderLeft != null) {
      pr.write('<w:left w:val="single" w:sz="24" w:space="8" w:color="$borderLeft"/>');
    }
    if (borderBottom != null) {
      pr.write('<w:bottom w:val="single" w:sz="12" w:space="1" w:color="$borderBottom"/>');
    }
    pr.write('</w:pBdr>');
  }
  if (shade != null) pr.write('<w:shd w:val="clear" w:color="auto" w:fill="$shade"/>');
  if (tab != null || tabRight != null) {
    pr.write('<w:tabs>');
    if (tab != null) pr.write('<w:tab w:val="left" w:pos="$tab"/>');
    if (tabRight != null) {
      pr.write('<w:tab w:val="right" w:leader="dot" w:pos="$tabRight"/>');
    }
    pr.write('</w:tabs>');
  }
  if (spacingBefore != null || spacingAfter != null) {
    pr.write('<w:spacing');
    if (spacingBefore != null) pr.write(' w:before="$spacingBefore"');
    if (spacingAfter != null) pr.write(' w:after="$spacingAfter"');
    pr.write('/>');
  }
  if (indLeft != null || indRight != null || hanging != null) {
    pr.write('<w:ind');
    if (indLeft != null) pr.write(' w:left="$indLeft"');
    if (indRight != null) pr.write(' w:right="$indRight"');
    if (hanging != null) pr.write(' w:hanging="$hanging"');
    pr.write('/>');
  }
  if (align != null) pr.write('<w:jc w:val="$align"/>');
  final pPr = pr.isEmpty ? '' : '<w:pPr>$pr</w:pPr>';
  return '<w:p>$pPr$runs</w:p>';
}

/// Zmieša farbu s bielou – [amount] 0 = biela, 1 = pôvodná farba.
String _mix(String hex, double amount) {
  final v = int.tryParse(hex, radix: 16) ?? 0x5B6B7A;
  int ch(int shift) {
    final c = (v >> shift) & 0xFF;
    return (255 - (255 - c) * amount).round();
  }

  String h(int x) => x.toRadixString(16).padLeft(2, '0').toUpperCase();
  return '${h(ch(16))}${h(ch(8))}${h(ch(0))}';
}

const _mime = {'jpg': 'image/jpeg', 'png': 'image/png', 'gif': 'image/gif'};

/// Zistí formát a rozmery fotky (jpg / png / gif). Vráti null, ak ho nepozná.
(String, int, int)? _imageInfo(Uint8List b) {
  if (b.length > 24 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
    final w = (b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19];
    final h = (b[20] << 24) | (b[21] << 16) | (b[22] << 8) | b[23];
    return w > 0 && h > 0 ? ('png', w, h) : null;
  }
  if (b.length > 10 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) {
    final w = b[6] | (b[7] << 8);
    final h = b[8] | (b[9] << 8);
    return w > 0 && h > 0 ? ('gif', w, h) : null;
  }
  if (b.length > 4 && b[0] == 0xFF && b[1] == 0xD8) {
    var i = 2;
    while (i + 9 < b.length) {
      if (b[i] != 0xFF) {
        i++;
        continue;
      }
      final marker = b[i + 1];
      if (marker == 0xFF) {
        i++;
        continue;
      }
      if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
        i += 2;
        continue;
      }
      final len = (b[i + 2] << 8) | b[i + 3];
      final isSof = marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC;
      if (isSof) {
        final h = (b[i + 5] << 8) | b[i + 6];
        final w = (b[i + 7] << 8) | b[i + 8];
        if (w == 0 || h == 0) return null;
        // EXIF otočenie ignorujeme – fotky z mobilu môžu byť na výšku inak,
        // výrez 16:9 to však vo väčšine prípadov skryje.
        return ('jpg', w, h);
      }
      i += 2 + len;
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Statické časti dokumentu
// ---------------------------------------------------------------------------

const _rootRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
    '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
    '</Relationships>';

const _app = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">'
    '<Application>Moje recepty</Application></Properties>';

const _settings = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
    '<w:updateFields w:val="true"/>'
    '<w:defaultTabStop w:val="708"/>'
    '<w:characterSpacingControl w:val="doNotCompress"/>'
    '<w:compat><w:compatSetting w:name="compatibilityMode" '
    'w:uri="http://schemas.microsoft.com/office/word" w:val="15"/></w:compat>'
    '</w:settings>';

const _footer = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
    '<w:p><w:pPr><w:jc w:val="center"/></w:pPr>'
    '<w:r><w:rPr><w:color w:val="$_mutedColor"/><w:sz w:val="18"/></w:rPr><w:fldChar w:fldCharType="begin"/></w:r>'
    '<w:r><w:rPr><w:color w:val="$_mutedColor"/><w:sz w:val="18"/></w:rPr><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r>'
    '<w:r><w:rPr><w:color w:val="$_mutedColor"/><w:sz w:val="18"/></w:rPr><w:fldChar w:fldCharType="separate"/></w:r>'
    '<w:r><w:rPr><w:color w:val="$_mutedColor"/><w:sz w:val="18"/></w:rPr><w:t>1</w:t></w:r>'
    '<w:r><w:rPr><w:color w:val="$_mutedColor"/><w:sz w:val="18"/></w:rPr><w:fldChar w:fldCharType="end"/></w:r>'
    '</w:p></w:ftr>';

const _styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
    '<w:docDefaults>'
    '<w:rPrDefault><w:rPr>'
    '<w:rFonts w:ascii="$_bodyFont" w:hAnsi="$_bodyFont" w:eastAsia="$_bodyFont" w:cs="$_bodyFont"/>'
    '<w:color w:val="$_textColor"/>'
    '<w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="sk-SK"/>'
    '</w:rPr></w:rPrDefault>'
    '<w:pPrDefault><w:pPr><w:spacing w:after="0" w:line="264" w:lineRule="auto"/></w:pPr></w:pPrDefault>'
    '</w:docDefaults>'
    '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>'
    '<w:style w:type="paragraph" w:styleId="Heading1">'
    '<w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/>'
    '<w:pPr><w:keepNext/><w:spacing w:before="0" w:after="240"/><w:outlineLvl w:val="0"/></w:pPr>'
    '<w:rPr><w:rFonts w:ascii="$_headFont" w:hAnsi="$_headFont" w:cs="$_headFont"/>'
    '<w:color w:val="$_textColor"/><w:sz w:val="48"/><w:szCs w:val="48"/></w:rPr>'
    '</w:style>'
    '<w:style w:type="character" w:styleId="Hyperlink"><w:name w:val="Hyperlink"/></w:style>'
    '<w:style w:type="table" w:default="1" w:styleId="TableNormal"><w:name w:val="Normal Table"/>'
    '<w:tblPr><w:tblInd w:w="0" w:type="dxa"/><w:tblCellMar><w:top w:w="0" w:type="dxa"/>'
    '<w:left w:w="108" w:type="dxa"/><w:bottom w:w="0" w:type="dxa"/><w:right w:w="108" w:type="dxa"/>'
    '</w:tblCellMar></w:tblPr></w:style>'
    '</w:styles>';
