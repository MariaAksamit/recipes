import 'package:flutter/material.dart';

import '../main.dart';
import '../models/categories.dart';
import '../models/recipe.dart';

/// Pomer strán veľkej fotky – rovnaký v úprave aj v detaile receptu.
const double kRecipeImageAspect = 16 / 9;

/// Fotka receptu, alebo farebná ikonka kategórie, ak fotka chýba.
class RecipeImage extends StatelessWidget {
  final Recipe recipe;
  final double iconSize;
  final BorderRadius? borderRadius;

  /// Pre malé náhľady (zoznam receptov): približná veľkosť v bodoch.
  /// Fotka sa potom načíta zmenšená – menej pamäte a rýchlejšie posúvanie,
  /// hlavne na iPhone a pri veľkých fotkách.
  final double? decodeSize;

  const RecipeImage({
    super.key,
    required this.recipe,
    this.iconSize = 40,
    this.borderRadius,
    this.decodeSize,
  });

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    var image = store.imageProvider(recipe);
    if (image != null && decodeSize != null) {
      // 2× rezerva: fotka na šírku musí vyplniť aj štvorcový rámček (BoxFit.cover).
      final px = (decodeSize! * MediaQuery.devicePixelRatioOf(context) * 2).round();
      image = ResizeImage(image, width: px, allowUpscaling: false);
    }
    final info = categoryInfo(recipe.category);

    Widget child;
    if (image != null) {
      child = Image(
        image: image,
        fit: BoxFit.cover,
        alignment: Alignment(recipe.imageX, recipe.imageY),
        gaplessPlayback: true,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => _placeholder(info),
      );
    } else {
      child = _placeholder(info);
    }
    return ClipRRect(borderRadius: borderRadius ?? BorderRadius.zero, child: child);
  }

  Widget _placeholder(CategoryInfo info) => Container(
    width: double.infinity,
    height: double.infinity,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [info.color.withValues(alpha: 0.85), info.color.withValues(alpha: 0.55)],
      ),
    ),
    child: Center(
      child: Icon(info.icon, size: iconSize, color: Colors.white.withValues(alpha: 0.9)),
    ),
  );
}
