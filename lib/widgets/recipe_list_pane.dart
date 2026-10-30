import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/recipe.dart';
import 'recipe_image.dart';

/// Vyhľadávanie a zoznam receptov.
class RecipeListPane extends StatelessWidget {
  final String title;
  final List<Recipe> recipes;
  final TextEditingController searchCtrl;
  final String? selectedId;
  final ValueChanged<String> onQuery;
  final ValueChanged<Recipe> onOpen;

  const RecipeListPane({
    super.key,
    required this.title,
    required this.recipes,
    required this.searchCtrl,
    required this.selectedId,
    required this.onQuery,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = S.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: searchCtrl,
            onChanged: onQuery,
            decoration: InputDecoration(
              hintText: s.searchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: s.clear,
                      onPressed: () {
                        searchCtrl.clear();
                        onQuery('');
                      },
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                s.recipeCount(recipes.length),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.outline),
              ),
            ],
          ),
        ),
        Expanded(
          child: recipes.isEmpty
              ? Center(child: Text(s.nothingFound))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                  itemCount: recipes.length,
                  itemBuilder: (_, i) => RecipeTile(
                    recipe: recipes[i],
                    selected: recipes[i].id == selectedId,
                    onTap: () => onOpen(recipes[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class RecipeTile extends StatelessWidget {
  final Recipe recipe;
  final bool selected;
  final VoidCallback onTap;

  const RecipeTile({super.key, required this.recipe, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = S.of(context);
    final count = recipe.ingredients.where((l) => !Recipe.isGroupHeader(l)).length;
    return Card(
      color: selected ? scheme.secondaryContainer : scheme.surfaceContainerLow,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: RecipeImage(
                  recipe: recipe,
                  iconSize: 28,
                  decodeSize: 64, // náhľad – fotka sa nenačíta v plnej veľkosti
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: selected ? scheme.onSecondaryContainer : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${s.category(recipe.category)} · ${s.ingredientCount(count)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline),
                    ),
                  ],
                ),
              ),
              if (recipe.favorite)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.favorite, color: scheme.primary, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
