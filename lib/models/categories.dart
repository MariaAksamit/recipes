import 'package:flutter/material.dart';

class CategoryInfo {
  final String name;
  final IconData icon;
  final Color color;
  const CategoryInfo(this.name, this.icon, this.color);
}

const kCategories = <CategoryInfo>[
  CategoryInfo('Hlavné jedlá', Icons.restaurant, Color(0xFFB5523B)),
  CategoryInfo('Polievky', Icons.soup_kitchen, Color(0xFFC98A2B)),
  CategoryInfo('Múčne jedlá a iné', Icons.ramen_dining, Color(0xFF7A8B3C)),
  CategoryInfo('Marinády a omáčky', Icons.water_drop, Color(0xFF9C6B30)),
  CategoryInfo('Koláče a dezerty', Icons.cake, Color(0xFFB04A72)),
  CategoryInfo('Krémy', Icons.icecream, Color(0xFFC77D9E)),
  CategoryInfo('Pečivo', Icons.bakery_dining, Color(0xFF8A6A45)),
  CategoryInfo('Ostatné', Icons.menu_book, Color(0xFF5B6B7A)),
];

CategoryInfo categoryInfo(String name) => kCategories.firstWhere(
      (c) => c.name == name,
      orElse: () => CategoryInfo(name, Icons.menu_book, const Color(0xFF5B6B7A)),
    );
