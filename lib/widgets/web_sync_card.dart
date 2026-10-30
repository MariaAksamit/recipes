import 'package:flutter/material.dart';

import '../l10n/strings.dart';

/// Web (iPhone): odkiaľ sú recepty a tlačidlo na ich aktualizáciu.
class WebSyncCard extends StatelessWidget {
  final DateTime? lastBackup;
  final VoidCallback onImport;

  const WebSyncCard({super.key, required this.lastBackup, required this.onImport});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    final d = lastBackup?.toLocal();
    final text = d == null ? s.webSyncFirst : s.webSyncLast(d);
    return Card(
      color: scheme.secondaryContainer,
      margin: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSecondaryContainer),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.sync),
                label: Text(d == null ? s.loadBackup : s.update),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
