import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../main.dart';
import '../models/categories.dart';
import '../models/recipe.dart';
import '../widgets/recipe_image.dart';

/// Pridanie nového alebo úprava existujúceho receptu.
/// Po uložení vráti (Navigator.pop) ID receptu.
class RecipeEditScreen extends StatefulWidget {
  final Recipe? recipe;
  final String? initialCategory;

  /// Predvyplnený nový recept (napr. načítaný z webu) – uloží sa ako nový.
  final Recipe? draft;
  const RecipeEditScreen({super.key, this.recipe, this.initialCategory, this.draft});

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends State<RecipeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _ingredients;
  late final TextEditingController _steps;
  late final TextEditingController _notes;
  late String _category;
  String? _imagePath; // aktuálne zvolená fotka
  double _imageX = 0, _imageY = 0; // výrez fotky (posun)
  final List<String> _pickedImages = []; // fotky vybrané počas úprav
  bool _saving = false;

  bool get _isNew => widget.recipe == null;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe ?? widget.draft;
    _title = TextEditingController(text: r?.title ?? '');
    _ingredients = TextEditingController(text: r?.ingredients.join('\n') ?? '');
    _steps = TextEditingController(text: r?.steps.join('\n\n') ?? '');
    _notes = TextEditingController(text: r?.notes ?? '');
    _category = r?.category ?? widget.initialCategory ?? kCategories.first.name;
    _imagePath = r?.imagePath;
    _imageX = r?.imageX ?? 0;
    _imageY = r?.imageY ?? 0;
    // Fotka stiahnutá z webu sa zmaže, ak recept nakoniec neuložíš.
    if (widget.recipe == null && widget.draft?.imagePath != null) {
      _pickedImages.add(widget.draft!.imagePath!);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _ingredients.dispose();
    _steps.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<String> _lines(String text) =>
      text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  /// Kroky postupu sú oddelené prázdnym riadkom (alebo každý na novom riadku).
  List<String> _paragraphs(String text) => text
      .split(RegExp(r'\n\s*\n|\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  Future<void> _pickImage() async {
    final store = StoreScope.read(context);
    final s = S.of(context);
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        dialogTitle: s.pickPhotoDialog,
        // V prehliadači sa k fotke nedostaneme cez cestu – načíta sa do pamäte.
        withData: kIsWeb,
      );
      final file = res?.files.single;
      if (file == null) return;
      final path = kIsWeb ? null : file.path;
      final bytes = file.bytes;
      if (path == null && bytes == null) return;
      final name = path != null
          ? await store.importImage(path)
          : await store.importPickedBytes(bytes!, (file.extension ?? 'jpg').toLowerCase());
      _pickedImages.add(name);
      if (!mounted) {
        await store.cleanupImage(name);
        return;
      }
      setState(() {
        _imagePath = name;
        _imageX = 0;
        _imageY = 0;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.photoLoadFailed(e))));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final store = StoreScope.read(context);
    final s = S.of(context);
    final old = widget.recipe;
    final recipe = Recipe(
      id: old?.id ?? store.newId(),
      title: _title.text.trim(),
      category: _category,
      ingredients: _lines(_ingredients.text),
      steps: _paragraphs(_steps.text),
      notes: _notes.text.trim(),
      favorite: old?.favorite ?? false,
      imagePath: _imagePath,
      imageX: _imageX,
      imageY: _imageY,
    );
    try {
      await store.upsert(recipe);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.recipeSaveFailed(e))));
      return;
    }
    // Uprace fotky, ktoré už nie sú použité (stará alebo vybrané a zahodené).
    await store.cleanupImage(old?.imagePath);
    for (final p in _pickedImages) {
      await store.cleanupImage(p);
    }
    if (!mounted) return;
    Navigator.of(context).pop(recipe.id);
  }

  Future<void> _discardPicked() async {
    final store = StoreScope.read(context);
    for (final p in _pickedImages) {
      await store.cleanupImage(p);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = S.of(context);
    final categories = <String>{
      ...kCategories.map((c) => c.name),
      ...store.usedCategories,
      _category,
    }.toList();
    final preview = Recipe(
      id: '_',
      title: '',
      category: _category,
      imagePath: _imagePath,
      imageX: _imageX,
      imageY: _imageY,
    );

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && result == null) _discardPicked();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? s.newRecipe : s.editRecipe),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check),
                label: Text(s.save),
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ---- fotka (rovnaký pomer strán ako v detaile receptu)
                  AspectRatio(
                    aspectRatio: kRecipeImageAspect,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _ImageFramer(
                            image: store.imageProvider(preview),
                            x: _imageX,
                            y: _imageY,
                            onChanged: (x, y) => setState(() {
                              _imageX = x;
                              _imageY = y;
                            }),
                            child: RecipeImage(
                              recipe: preview,
                              iconSize: 56,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        if (_imagePath != null)
                          Positioned(
                            left: 12,
                            top: 12,
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.open_with, size: 16, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Text(s.dragPhotoHint,
                                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Row(
                            children: [
                              if (_imagePath != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilledButton.tonalIcon(
                                    onPressed: () => setState(() {
                                      _imagePath = null;
                                      _imageX = 0;
                                      _imageY = 0;
                                    }),
                                    icon: const Icon(Icons.delete_outline),
                                    label: Text(s.remove),
                                  ),
                                ),
                              FilledButton.tonalIcon(
                                onPressed: _pickImage,
                                icon: const Icon(Icons.photo_camera_outlined),
                                label: Text(_imagePath == null ? s.addPhoto : s.changePhoto),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: s.recipeName),
                    validator: (v) => (v == null || v.trim().isEmpty) ? s.enterName : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: InputDecoration(labelText: s.categoryLabel),
                    items: [
                      for (final c in categories)
                        DropdownMenuItem(
                          value: c,
                          child: Row(
                            children: [
                              Icon(categoryInfo(c).icon, size: 20, color: categoryInfo(c).color),
                              const SizedBox(width: 10),
                              Text(s.category(c)),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _category = v ?? _category),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle(context, s.ingredients, s.ingredientsHelp),
                  TextFormField(
                    controller: _ingredients,
                    minLines: 6,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(hintText: s.ingredientsHint),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle(context, s.steps, s.stepsHelp),
                  TextFormField(
                    controller: _steps,
                    minLines: 6,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(hintText: s.stepsHint),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle(context, s.notes, null),
                  TextFormField(
                    controller: _notes,
                    minLines: 2,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(hintText: s.notesHint),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, String? help) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (help != null)
            Text(help, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

/// Umožní ťahaním posúvať výrez fotky (BoxFit.cover + Alignment).
/// Posúvať sa dá len v smere, kde fotka presahuje rámček.
class _ImageFramer extends StatefulWidget {
  final ImageProvider? image;
  final double x, y;
  final void Function(double x, double y) onChanged;
  final Widget child;

  const _ImageFramer({
    required this.image,
    required this.x,
    required this.y,
    required this.onChanged,
    required this.child,
  });

  @override
  State<_ImageFramer> createState() => _ImageFramerState();
}

class _ImageFramerState extends State<_ImageFramer> {
  Size? _imageSize;
  ImageProvider? _resolvedFor;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  void _resolve() {
    final image = widget.image;
    if (image == _resolvedFor) return;
    _resolvedFor = image;
    _stopListening();
    _imageSize = null;
    if (image == null) return;
    _stream = image.resolve(ImageConfiguration.empty);
    var sync = true; // fotka z cache sa ohlási hneď, ešte počas build()
    _listener = ImageStreamListener((info, _) {
      final size = Size(info.image.width.toDouble(), info.image.height.toDouble());
      if (sync) {
        _imageSize = size;
      } else if (mounted) {
        setState(() => _imageSize = size);
      }
    }, onError: (_, _) {});
    _stream!.addListener(_listener!);
    sync = false;
  }

  void _stopListening() {
    if (_stream != null && _listener != null) _stream!.removeListener(_listener!);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _resolve();
    final img = _imageSize;
    if (widget.image == null || img == null) return widget.child;

    return LayoutBuilder(builder: (context, c) {
      final box = c.biggest;
      final scale = (box.width / img.width) > (box.height / img.height)
          ? box.width / img.width
          : box.height / img.height;
      final overX = img.width * scale - box.width; // o koľko fotka presahuje
      final overY = img.height * scale - box.height;
      final canMove = overX > 1 || overY > 1;

      return MouseRegion(
        cursor: canMove ? SystemMouseCursors.move : MouseCursor.defer,
        child: GestureDetector(
          // Samostatne vodorovný a zvislý ťah – vyhrajú nad posúvaním stránky.
          // Smer, v ktorom fotka nepresahuje, sa nechytá (stránka sa normálne posúva).
          onHorizontalDragUpdate: overX > 1
              ? (d) => widget.onChanged(
                    (widget.x - d.delta.dx * 2 / overX).clamp(-1.0, 1.0).toDouble(), widget.y)
              : null,
          onVerticalDragUpdate: overY > 1
              ? (d) => widget.onChanged(
                    widget.x, (widget.y - d.delta.dy * 2 / overY).clamp(-1.0, 1.0).toDouble())
              : null,
          onDoubleTap: canMove ? () => widget.onChanged(0, 0) : null,
          child: widget.child,
        ),
      );
    });
  }
}
