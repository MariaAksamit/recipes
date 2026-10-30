import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/text_import.dart';
import '../data/web_import.dart';
import '../l10n/strings.dart';
import '../main.dart';
import '../models/categories.dart';
import '../models/recipe.dart';

/// Dialóg „Načítať recept“: odkaz na web, alebo text / fotka cez AI.
/// Vráti načítaný (ešte neuložený) recept.
class ImportRecipeDialog extends StatefulWidget {
  final String initialCategory;
  const ImportRecipeDialog({super.key, required this.initialCategory});

  @override
  State<ImportRecipeDialog> createState() => _ImportRecipeDialogState();
}

class _ImportRecipeDialogState extends State<ImportRecipeDialog> {
  final _url = TextEditingController();
  final _text = TextEditingController();
  late String _category = widget.initialCategory;
  bool _loading = false;
  bool _copied = false;
  bool _loadFailed = false; // odkaz sa nepodarilo načítať
  String? _error;
  String? _textError;

  @override
  void dispose() {
    _url.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final store = StoreScope.read(context);
    final s = S.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await importRecipeFromUrl(_url.text, category: _category, store: store, s: s);
      if (!mounted) {
        await store.cleanupImage(r.imagePath);
        return;
      }
      Navigator.of(context).pop(r);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
        _error = e is WebImportException ? e.message : s.loadFailed(e);
      });
    }
  }

  Future<void> _copyPrompt() async {
    await Clipboard.setData(ClipboardData(text: S.of(context).aiPrompt(_url.text)));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  /// Prázdny recept na ručné vyplnenie (odkaz sa uloží ako zdroj).
  void _manual() {
    final store = StoreScope.read(context);
    final url = _url.text.trim();
    Navigator.of(context).pop(
      Recipe(
        id: store.newId(),
        title: '',
        category: _category,
        notes: url.isEmpty ? '' : S.of(context).source(url),
      ),
    );
  }

  void _fromText() {
    final store = StoreScope.read(context);
    final s = S.of(context);
    try {
      final r = parseRecipeText(_text.text, category: _category, store: store, s: s);
      final url = _url.text.trim();
      if (url.isNotEmpty && !r.notes.contains(url)) {
        r.notes = [if (r.notes.isNotEmpty) r.notes, s.source(url)].join('\n');
      }
      Navigator.of(context).pop(r);
    } catch (e) {
      setState(() => _textError = e is TextImportException ? e.message : '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    final small = theme.textTheme.bodySmall?.copyWith(color: scheme.outline);
    // Hlavné (plné) tlačidlo: keď je vložený text, „Vytvoriť recept z textu“,
    // inak „Načítať z odkazu“.
    final textFirst = _text.text.trim().isNotEmpty;

    final loadIcon = _loading
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.download);
    final loadLabel = Text(_loading ? s.loading : s.loadFromLink);
    const textIcon = Icon(Icons.playlist_add);
    final textLabel = Text(s.createFromText);

    return AlertDialog(
      title: Text(s.loadRecipe),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          // Miesto hore pre popis prvého poľa (pri písaní sa presunie nad pole).
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _url,
                autofocus: true,
                enabled: !_loading,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: s.linkLabel,
                  hintText: 'https://…',
                  prefixIcon: const Icon(Icons.link),
                ),
                onChanged: (_) {
                  if (_copied) setState(() => _copied = false);
                },
                onSubmitted: (_) => _loading ? null : _load(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: InputDecoration(labelText: s.categoryLabel),
                items: [
                  for (final c in kCategories)
                    DropdownMenuItem(
                      value: c.name,
                      child: Row(
                        children: [
                          Icon(c.icon, size: 20, color: c.color),
                          const SizedBox(width: 10),
                          Text(s.category(c.name)),
                        ],
                      ),
                    ),
                ],
                onChanged: _loading ? null : (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 12),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: scheme.error)),
                const SizedBox(height: 16),
              ] else
                Text(s.loadIntro, style: small),
              if (_loadFailed) ...[
                FilledButton.tonalIcon(
                  onPressed: _loading ? null : _manual,
                  icon: const Icon(Icons.edit_note),
                  label: Text(s.writeRecipeManually),
                ),
              ],
              const SizedBox(height: 16),
              Card(
                color: scheme.surfaceContainerHigh,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, color: scheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(s.loadViaAi, style: theme.textTheme.titleSmall),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(s.aiStep1, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text(s.aiStep1Help, style: small),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: _copyPrompt,
                        icon: Icon(_copied ? Icons.check : Icons.copy),
                        label: Text(_copied ? s.copiedShort : s.copyAiPrompt),
                      ),
                      const SizedBox(height: 14),
                      Text(s.aiStep2, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _text,
                        minLines: 5,
                        maxLines: 12,
                        decoration: InputDecoration(hintText: s.textHint),
                        onChanged: (_) => setState(() => _textError = null),
                      ),
                      if (_textError != null) ...[
                        const SizedBox(height: 8),
                        Text(_textError!, style: TextStyle(color: scheme.error)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        if (textFirst) ...[
          FilledButton.icon(
            onPressed: _loading ? null : _fromText,
            icon: textIcon,
            label: textLabel,
          ),
          FilledButton.tonalIcon(
            onPressed: _loading ? null : _load,
            icon: loadIcon,
            label: loadLabel,
          ),
        ] else ...[
          FilledButton.tonalIcon(
            onPressed: _loading ? null : _fromText,
            icon: textIcon,
            label: textLabel,
          ),
          FilledButton.icon(onPressed: _loading ? null : _load, icon: loadIcon, label: loadLabel),
        ],
      ],
    );
  }
}
