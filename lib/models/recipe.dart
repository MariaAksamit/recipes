/// Premenované kategórie (staré meno → nové) – platí aj pre staré zálohy.
const _renamedCategories = {'Pečivo a cestoviny': 'Pečivo'};

/// Jeden recept.
///
/// Suroviny sú uložené ako riadky textu (napr. "500 g hladká múka").
/// Riadok končiaci dvojbodkou (napr. "Cesto:") je nadpis skupiny surovín.
class Recipe {
  final String id;
  String title;
  String category;
  List<String> ingredients;
  List<String> steps;
  String notes;
  bool favorite;
  String? imagePath;

  /// Výrez fotky: -1 = úplne vľavo/hore, 0 = stred, 1 = vpravo/dole.
  double imageX;
  double imageY;
  DateTime updatedAt;

  Recipe({
    required this.id,
    required this.title,
    required this.category,
    List<String>? ingredients,
    List<String>? steps,
    this.notes = '',
    this.favorite = false,
    this.imagePath,
    this.imageX = 0,
    this.imageY = 0,
    DateTime? updatedAt,
  })  : ingredients = ingredients ?? [],
        steps = steps ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        category: _renamedCategories[j['category']] ?? (j['category'] ?? 'Ostatné') as String,
        ingredients: List<String>.from((j['ingredients'] ?? const []) as List),
        steps: List<String>.from((j['steps'] ?? const []) as List),
        notes: (j['notes'] ?? '') as String,
        favorite: (j['favorite'] ?? false) as bool,
        imagePath: j['imagePath'] as String?,
        imageX: ((j['imageX'] ?? 0) as num).toDouble(),
        imageY: ((j['imageY'] ?? 0) as num).toDouble(),
        updatedAt: DateTime.tryParse((j['updatedAt'] ?? '') as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'ingredients': ingredients,
        'steps': steps,
        'notes': notes,
        'favorite': favorite,
        'imagePath': imagePath,
        'imageX': imageX,
        'imageY': imageY,
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Je daný riadok surovín nadpisom skupiny (napr. "Cesto:")?
  static bool isGroupHeader(String line) {
    final t = line.trim();
    return t.endsWith(':') && t.length <= 45;
  }
}
