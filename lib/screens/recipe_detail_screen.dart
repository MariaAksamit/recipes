import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../data/platform/web_platform.dart';
import '../l10n/strings.dart';
import '../main.dart';
import '../models/categories.dart';
import '../models/recipe.dart';
import '../utils/share_recipe.dart';
import '../utils/text_utils.dart';
import '../widgets/recipe_image.dart';
import 'recipe_edit_screen.dart';

/// Detail receptu ako samostatná obrazovka (mobil).
class RecipeDetailScreen extends StatelessWidget {
  final String recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: RecipeDetailView(recipeId: recipeId, embedded: false));
  }
}

/// Obsah detailu receptu – používa sa na mobile aj v pravom paneli na PC.
class RecipeDetailView extends StatefulWidget {
  final String recipeId;
  final bool embedded;
  const RecipeDetailView({super.key, required this.recipeId, required this.embedded});

  @override
  State<RecipeDetailView> createState() => _RecipeDetailViewState();
}

class _RecipeDetailViewState extends State<RecipeDetailView> {
  static const _factors = [0.5, 1.0, 1.5, 2.0, 3.0];
  double _factor = 1.0;
  final Set<int> _checked = {}; // odškrtnuté suroviny
  bool _cooking = false; // režim varenia (displej nezhasína, väčšie písmo)

  Future<void> _toggleCooking() async {
    final on = !_cooking;
    setState(() => _cooking = on);
    if (on) {
      final ok = await ScreenWakeLock.enable();
      if (!mounted) return;
      final s = S.of(context);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(ok ? s.cookingOn : s.cookingOnNoWakeLock),
      ));
    } else {
      await ScreenWakeLock.disable();
    }
  }

  @override
  void dispose() {
    if (_cooking) ScreenWakeLock.disable();
    super.dispose();
  }

  Future<void> _edit(Recipe r) async {
    await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => RecipeEditScreen(recipe: r)),
    );
  }

  Future<void> _delete(Recipe r) async {
    final store = StoreScope.read(context);
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteRecipeTitle),
        content: Text(s.deleteRecipeBody(r.title)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.delete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (!widget.embedded) Navigator.of(context).pop();
    await store.delete(r);
  }

  String _factorLabel(double f) {
    if (f == 0.5) return '½×';
    if (f == 1.5) return '1½×';
    return '${f.toInt()}×';
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final r = store.byId(widget.recipeId);
    if (r == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    final info = categoryInfo(r.category);
    final hasImage = store.hasImage(r);
    // Na úzkej obrazovke (mobil) sa Upraviť a Vymazať schovajú do menu ⋮,
    // aby sa názov receptu nestratil medzi ikonami.
    final narrow = MediaQuery.sizeOf(context).width < 600;

    final view = CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          automaticallyImplyLeading: !widget.embedded,
          title: Text(r.title),
          actions: [
            IconButton(
              tooltip: r.favorite ? s.removeFavorite : s.addFavorite,
              icon: Icon(r.favorite ? Icons.favorite : Icons.favorite_border),
              color: r.favorite ? scheme.primary : null,
              onPressed: () => store.toggleFavorite(r),
            ),
            IconButton(
              tooltip: _cooking ? s.cookingModeOff : s.cookingMode,
              icon: Icon(_cooking ? Icons.soup_kitchen : Icons.soup_kitchen_outlined),
              color: _cooking ? scheme.primary : null,
              isSelected: _cooking,
              onPressed: _toggleCooking,
            ),
            Builder(
              builder: (btnCtx) => IconButton(
                tooltip: s.share,
                icon: const Icon(Icons.share_outlined),
                onPressed: () async {
                  // V prehliadači fotka nie je súbor – priloží sa z pamäte.
                  final bytes = kIsWeb ? await store.imageBytes(r) : null;
                  if (!btnCtx.mounted) return;
                  await showShareRecipe(
                    btnCtx,
                    r,
                    store.imageFile(r),
                    imageBytes: bytes,
                    imageName: r.imagePath,
                  );
                },
              ),
            ),
            if (!narrow) ...[
              IconButton(
                tooltip: s.edit,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _edit(r),
              ),
              IconButton(
                tooltip: s.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(r),
              ),
            ] else
              PopupMenuButton<String>(
                tooltip: s.more,
                onSelected: (v) => v == 'edit' ? _edit(r) : _delete(r),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(s.edit)),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: Text(s.delete),
                    ),
                  ),
                ],
              ),
          ],
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasImage) ...[
                      AspectRatio(
                        aspectRatio: kRecipeImageAspect,
                        child: RecipeImage(recipe: r, borderRadius: BorderRadius.circular(20)),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Chip(
                      avatar: Icon(info.icon, size: 18, color: info.color),
                      label: Text(s.category(r.category)),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(s.portion, style: theme.textTheme.titleSmall),
                        SegmentedButton<double>(
                          showSelectedIcon: false,
                          segments: [
                            for (final f in _factors)
                              ButtonSegment(value: f, label: Text(_factorLabel(f))),
                          ],
                          selected: {_factor},
                          onSelectionChanged: (s) => setState(() => _factor = s.first),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, c) {
                        final ingredients = _IngredientsCard(
                          lines: r.ingredients,
                          factor: _factor,
                          checked: _checked,
                          onToggle: (i) => setState(() {
                            _checked.contains(i) ? _checked.remove(i) : _checked.add(i);
                          }),
                        );
                        final steps = _StepsSection(steps: r.steps);
                        if (c.maxWidth >= 720) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: ingredients),
                              const SizedBox(width: 24),
                              Expanded(flex: 3, child: steps),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [ingredients, const SizedBox(height: 24), steps],
                        );
                      },
                    ),
                    if (r.notes.trim().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Card(
                        color: scheme.tertiaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lightbulb_outline, color: scheme.onTertiaryContainer),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  r.notes,
                                  style: TextStyle(color: scheme.onTertiaryContainer),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (!_cooking) return view;
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * 1.3)),
      child: view,
    );
  }
}

class _IngredientsCard extends StatelessWidget {
  final List<String> lines;
  final double factor;
  final Set<int> checked;
  final ValueChanged<int> onToggle;

  const _IngredientsCard({
    required this.lines,
    required this.factor,
    required this.checked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    return Card(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.ingredients, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            if (lines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(s.noIngredients, style: TextStyle(color: scheme.outline)),
              ),
            for (var i = 0; i < lines.length; i++)
              if (Recipe.isGroupHeader(lines[i]))
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 4),
                  child: Text(
                    lines[i].trim().replaceAll(RegExp(r':$'), ''),
                    style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
                  ),
                )
              else
                _IngredientRow(
                  line: lines[i],
                  factor: factor,
                  checked: checked.contains(i),
                  onTap: () => onToggle(i),
                ),
          ],
        ),
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  final String line;
  final double factor;
  final bool checked;
  final VoidCallback onTap;

  const _IngredientRow({
    required this.line,
    required this.factor,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts = splitIngredient(line, factor);
    final base = Theme.of(context).textTheme.bodyLarge!.copyWith(
          decoration: checked ? TextDecoration.lineThrough : null,
          color: checked ? scheme.outline : null,
        );
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              checked ? Icons.check_circle : Icons.circle_outlined,
              size: 20,
              color: checked ? scheme.primary : scheme.outlineVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: base,
                  children: [
                    if (parts.qty != null)
                      TextSpan(
                        text: '${parts.qty} ',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: checked
                              ? scheme.outline
                              : (factor != 1 ? scheme.primary : null),
                        ),
                      ),
                    TextSpan(text: parts.rest),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepsSection extends StatelessWidget {
  final List<String> steps;
  const _StepsSection({required this.steps});

  static final _header = RegExp(r'^([^:.]{1,40}):\s+');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.steps, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (steps.isEmpty) Text(s.noSteps, style: TextStyle(color: scheme.outline)),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _stepText(context, steps[i])),
              ],
            ),
          ),
      ],
    );
  }

  Widget _stepText(BuildContext context, String step) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5);
    final m = _header.firstMatch(step);
    if (m == null) return Text(step, style: style);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: '${m.group(1)}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: step.substring(m.end)),
        ],
      ),
    );
  }
}
