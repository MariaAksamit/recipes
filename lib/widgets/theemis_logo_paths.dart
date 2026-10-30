// GENEROVANE - neupravuj rucne.
// Zdroj: TheemisLogo6light.svg
// Znovu: python3 tool/gen_logo.py design/<logo>.svg \
//            lib/widgets/theemis_logo_paths.dart

import 'dart:typed_data';
import 'dart:ui';

/// Jeden ťah loga: cesta vo vlastných súradniciach, matica, ktorou sa
/// vykresľuje, a hrúbka ťahu. Hrúbka platí pred aplikovaním matice –
/// preto vyjde presne tak ako v SVG aj pri nerovnomernej mierke.
class TheemisStroke {
  final Path path;
  final Float64List matrix;
  final double width;
  final double miterLimit;
  const TheemisStroke(this.path, this.matrix, this.width, this.miterLimit);
}

Float64List _m(double a, double b, double c, double d, double e, double f) =>
    Float64List.fromList([a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, e, f, 0, 1]);

/// Rozmer kresby – v tomto priestore sú všetky cesty nižšie.
const kTheemisViewBox = Size(883, 254);

/// Účiarie slova (bez presahu T). Podľa nej zarovnávaj logo vedľa textu.
const kTheemisBaseline = 190.3175;

/// Výška písmen – užitočná na odvodenie hrúbky linky v [TheemisRule].
const kTheemisCapHeight = 110.8643;

// T
List<TheemisStroke> _g0() => [
  TheemisStroke(
    Path()
      ..moveTo(437.546, 355.155)
      ..lineTo(437.546, 570.906)
    ,
    _m(1, 0, 0, 1, -319.5359, -336.376),
    20.83,
    1.5,
  ),
  TheemisStroke(
    Path()
      ..moveTo(331.141, 345.271)
      ..lineTo(1261.825, 345.271)
    ,
    _m(0.908, 0, 0, 1, -281.9119, -326.4917),
    21.81,
    1.5,
  ),
];

// H
List<TheemisStroke> _g1() => [
  TheemisStroke(
    Path()
      ..moveTo(665.792, 400.906)
      ..lineTo(665.792, 567.81)
    ,
    _m(0.5997, 0, 0, 0.6642, -142.8785, -186.8425),
    19.75,
    1.5,
  ),
  TheemisStroke(
    Path()
      ..moveTo(550.243, 484.358)
      ..lineTo(665.792, 484.358)
    ,
    _m(0.5997, 0, 0, 0.6642, -142.8785, -186.8425),
    19.75,
    1.5,
  ),
  TheemisStroke(
    Path()
      ..moveTo(550.243, 400.906)
      ..lineTo(550.243, 567.81)
    ,
    _m(0.5997, 0, 0, 0.6642, -142.8785, -186.8425),
    19.75,
    1.5,
  ),
];

// E3
List<TheemisStroke> _g2() => [
  TheemisStroke(
    Path()
      ..moveTo(754.237, 485.951)
      ..lineTo(812.725, 485.951)
    ,
    _m(0.5923, 0, 0, 0.6754, -134.9676, -193.3168),
    19.68,
    1.5,
  ),
  TheemisStroke(
    Path()
      ..moveTo(871.212, 416.571)
      ..lineTo(754.237, 416.571)
      ..lineTo(754.237, 568.397)
      ..lineTo(871.212, 568.397)
    ,
    _m(0.5923, 0, 0, 0.6754, -134.9676, -197.7569),
    19.68,
    1.5,
  ),
];

// E
List<TheemisStroke> _g3() => [
  TheemisStroke(
    Path()
      ..moveTo(754.237, 486.558)
      ..lineTo(812.725, 486.558)
    ,
    _m(0.5923, 0, 0, 0.6754, -10.2458, -193.7271),
    19.68,
    1.5,
  ),
  TheemisStroke(
    Path()
      ..moveTo(871.212, 416.571)
      ..lineTo(754.237, 416.571)
      ..lineTo(754.237, 568.397)
      ..lineTo(871.212, 568.397)
    ,
    _m(0.5923, 0, 0, 0.6754, -10.2458, -197.7569),
    19.68,
    1.5,
  ),
];

// M
List<TheemisStroke> _g4() => [
  TheemisStroke(
    Path()
      ..moveTo(1249.244, 400.906)
      ..lineTo(1244.964, 567.81)
    ,
    _m(0.6741, -0.0153, 0.0173, 0.6638, -206.0353, -167.4755),
    18.65,
    1.5,
  ),
  TheemisStroke(
    Path()
      ..moveTo(1128.749, 403.815)
      ..lineTo(1188.616, 490.675)
      ..lineTo(1248.516, 403.815)
    ,
    _m(0.6743, 0, 0, 0.664, -199.3552, -186.714),
    18.68,
    1.5,
  ),
  TheemisStroke(
    Path()
      ..moveTo(1127.988, 567.81)
      ..lineTo(1125.135, 400.906)
    ,
    _m(0.6742, 0.0102, -0.0115, 0.6639, -192.7111, -198.1996),
    18.7,
    1.5,
  ),
];

// I
List<TheemisStroke> _g5() => [
  TheemisStroke(
    Path()
      ..moveTo(1321.997, 400.906)
      ..lineTo(1324.85, 567.81)
    ,
    _m(0.6651, 0.0109, -0.0114, 0.664, -176.2502, -201.2323),
    18.81,
    1.5,
  ),
];

// S
List<TheemisStroke> _g6() => [
  TheemisStroke(
    Path()
      ..moveTo(115.63, 41.92)
      ..cubicTo(112.78, 37.89, 109.84, 33.91, 106.56, 30.23)
      ..cubicTo(103.28, 26.54, 99.51, 23.25, 95.47, 20.4)
      ..cubicTo(87.51, 14.79, 77.54, 11, 67.8, 11)
      ..cubicTo(56.78, 11, 44.86, 15.36, 37.07, 23.15)
      ..cubicTo(33.77, 26.44, 31.02, 30.4, 29.16, 34.66)
      ..cubicTo(27.29, 38.94, 26.34, 43.71, 26.33, 48.37)
      ..cubicTo(26.32, 60.34, 32.27, 72.61, 40.39, 81.41)
      ..cubicTo(44.53, 85.9, 49.31, 89.78, 54.09, 93.58)
      ..cubicTo(58.9, 97.38, 63.78, 101.1, 68.72, 104.74)
      ..cubicTo(79.73, 112.86, 90.85, 121.12, 100.01, 131.28)
      ..cubicTo(104.57, 136.35, 108.68, 141.99, 111.6, 148.16)
      ..cubicTo(114.52, 154.31, 116.23, 161.25, 116.23, 168.06)
      ..cubicTo(116.24, 174.09, 115.1, 180.23, 112.87, 185.83)
      ..cubicTo(110.65, 191.43, 107.23, 196.69, 102.98, 200.96)
      ..cubicTo(93.6, 210.35, 79.12, 215.34, 65.85, 215.35)
      ..cubicTo(57.13, 215.35, 48.18, 212.77, 40.66, 208.38)
      ..cubicTo(34.21, 204.61, 28.46, 199.53, 23.56, 193.9)
      ..cubicTo(18.63, 188.25, 14.69, 181.76, 11, 175.23)
    ,
    _m(0.5951, 0, 0, 0.5107, 744.8943, 76.1778),
    22.54,
    10,
  ),
];

/// Písmená zľava doprava: T H E3 E M I S
final List<List<TheemisStroke>> kTheemisGlyphs =
    List.unmodifiable([_g0(), _g1(), _g2(), _g3(), _g4(), _g5(), _g6()]);
