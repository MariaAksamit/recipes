// Zmenšenie fotky pri pridaní k receptu – PC, mobil aj prehliadač.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

// Dlhšia strana zmenšenej fotky v pixeloch – stačí aj na veľký monitor.
const _maxSide = 1600;

/// Menšie fotky sa nechajú tak, ako sú.
const _keepBelowBytes = 400 * 1024;

/// Zmenší veľkú fotku (napr. 4000 × 3000 z mobilu, 5 MB) na rozumnú veľkosť
/// (zvyčajne 200 – 400 kB). Vďaka tomu je záloha menšia a apka – hlavne
/// na iPhone – rýchlejšia. Vráti null, ak fotku netreba alebo nejde zmenšiť
/// (vtedy sa použije pôvodná).
///
/// Balík `image` je čistý Dart, takže to funguje aj vo webovej verzii.
/// V prehliadači beží zmenšenie priamo v apke (compute tam nemá vlákno navyše),
/// pri veľkej fotke preto môže na chvíľu zatuhnúť – trvá to zlomok sekundy.
Future<({Uint8List bytes, String ext})?> shrinkPhoto(Uint8List bytes) async {
  if (bytes.length <= _keepBelowBytes) return null;
  try {
    return await compute(_shrink, bytes); // na pozadí, aby apka nezamrzla
  } catch (e) {
    debugPrint('Fotku sa nepodarilo zmenšiť: $e');
    return null;
  }
}

({Uint8List bytes, String ext})? _shrink(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded); // fotka z mobilu ostane správne otočená
  if (math.max(image.width, image.height) > _maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: _maxSide, interpolation: img.Interpolation.average)
        : img.copyResize(image, height: _maxSide, interpolation: img.Interpolation.average);
  }
  final png = image.hasAlpha; // priehľadné obrázky ostanú PNG
  final out = png ? img.encodePng(image) : img.encodeJpg(image, quality: 85);
  if (out.length >= bytes.length) return null;
  return (bytes: out, ext: png ? 'png' : 'jpg');
}
