import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/text_import.dart';
import '../l10n/strings.dart';
import '../models/recipe.dart';

/// Ponuka zdieľania receptu: systémové zdieľanie (WhatsApp, Messenger,
/// e-mail…), e-mail alebo skopírovanie textu.
///
/// Fotka sa priloží buď ako súbor [image] (PC, mobil), alebo – vo webovej
/// verzii, kde fotky nie sú súbory – ako [imageBytes] s názvom [imageName].
Future<void> showShareRecipe(
  BuildContext context,
  Recipe recipe,
  File? image, {
  Uint8List? imageBytes,
  String? imageName,
}) {
  final s = S.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.share),
            title: Text(s.shareSystem),
            subtitle: Text(s.shareSystemSubtitle),
            onTap: () async {
              Navigator.pop(sheetCtx);
              await _shareSystem(context, recipe, image, imageBytes, imageName);
            },
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: Text(s.shareEmail),
            onTap: () async {
              Navigator.pop(sheetCtx);
              await _shareEmail(context, recipe);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: Text(s.copyText),
            onTap: () async {
              Navigator.pop(sheetCtx);
              await Clipboard.setData(ClipboardData(text: recipeToText(recipe, s)));
              if (!context.mounted) return;
              _snack(context, s.copied);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Fotka na priloženie: súbor (PC, mobil) alebo bajty z pamäte (web).
List<XFile>? _imageFiles(File? image, Uint8List? bytes, String? name) {
  if (image != null) return [XFile(image.path)];
  if (bytes == null) return null;
  final mime = (name ?? '').toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
  return [XFile.fromData(bytes, name: name ?? 'fotka.jpg', mimeType: mime)];
}

Future<void> _shareSystem(
  BuildContext context,
  Recipe r,
  File? image,
  Uint8List? imageBytes,
  String? imageName,
) async {
  final s = S.of(context);
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  try {
    await SharePlus.instance.share(ShareParams(
      title: r.title,
      subject: r.title,
      text: recipeToText(r, s),
      files: _imageFiles(image, imageBytes, imageName),
      sharePositionOrigin: origin,
    ));
  } catch (e) {
    if (context.mounted) _snack(context, s.shareFailed(e));
  }
}

Future<void> _shareEmail(BuildContext context, Recipe r) async {
  final s = S.of(context);
  final text = recipeToText(r, s);
  final uri = Uri.parse(
    'mailto:?subject=${Uri.encodeComponent(s.emailSubject(r.title))}'
    '&body=${Uri.encodeComponent(text)}',
  );
  var ok = false;
  try {
    ok = await launchUrl(uri);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) _snack(context, s.emailFailed);
  }
}

void _snack(BuildContext context, String msg) {
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(msg)));
}
