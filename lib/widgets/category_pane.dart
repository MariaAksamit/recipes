import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/categories.dart';

/// Zvislý zoznam kategórií (Obľúbené, Všetky, jednotlivé kategórie).
class CategoryPane extends StatelessWidget {
  final List<String> categories;
  final Map<String, int> counts;
  final int total;
  final int favorites;
  final String? category;
  final bool favoritesOnly;
  final bool large; // mobil: väčšie položky so šípkou
  final VoidCallback onAll;
  final VoidCallback onFavorites;
  final ValueChanged<String> onCategory;

  const CategoryPane({
    super.key,
    required this.categories,
    required this.counts,
    required this.total,
    required this.favorites,
    required this.category,
    required this.favoritesOnly,
    this.large = false,
    required this.onAll,
    required this.onFavorites,
    required this.onCategory,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = S.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Text(
            s.categories,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.outline),
          ),
        ),
        _item(
          context,
          label: s.favorites,
          icon: Icons.favorite,
          color: scheme.primary,
          count: favorites,
          selected: favoritesOnly,
          onTap: onFavorites,
        ),
        _item(
          context,
          label: s.all,
          icon: Icons.menu_book,
          count: total,
          selected: !favoritesOnly && category == null,
          onTap: onAll,
        ),
        const Divider(height: 16, indent: 12, endIndent: 12),
        for (final c in categories)
          _item(
            context,
            label: s.category(c),
            icon: categoryInfo(c).icon,
            color: categoryInfo(c).color,
            count: counts[c] ?? 0,
            selected: !favoritesOnly && category == c,
            onTap: () => onCategory(c),
          ),
      ],
    );
  }

  Widget _item(
    BuildContext context, {
    required String label,
    required IconData icon,
    Color? color,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        dense: !large,
        contentPadding: large ? const EdgeInsets.symmetric(horizontal: 16, vertical: 4) : null,
        selected: selected,
        selectedTileColor: scheme.secondaryContainer,
        selectedColor: scheme.onSecondaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected && Theme.of(context).brightness == Brightness.dark
              ? BorderSide(color: scheme.onSecondaryContainer, width: 1)
              : BorderSide.none,
        ),
        leading: Icon(icon, size: large ? 26 : 20, color: selected ? null : color),
        title: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: large ? Theme.of(context).textTheme.titleMedium : null,
        ),
        trailing: large
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? scheme.onSecondaryContainer : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right),
                ],
              )
            : Text(
                '$count',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? scheme.onSecondaryContainer : null,
                ),
              ),
        onTap: onTap,
      ),
    );
  }
}
