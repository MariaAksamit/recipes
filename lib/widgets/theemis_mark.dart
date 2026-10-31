import 'package:flutter/material.dart';

import 'theemis_logo_paths.dart';

/// Podpis autora. Veľkosť sa zadáva šírkou, výška sa dopočíta.
///
/// Cesty sú predgenerované z SVG; po novom exporte loga spusti:
/// `python3 tool/gen_logo.py Design/<logo>.svg lib/widgets/theemis_logo_paths.dart`

/// Pod touto šírkou sa slovo už nedá prečítať – použi [TheemisRule] alebo text.
const kTheemisMinWidth = 90.0;

double get kTheemisAspect => kTheemisViewBox.width / kTheemisViewBox.height;

class TheemisMark extends StatelessWidget {
  final double width;
  final Color? color;

  /// Krytie 0–1 (na vodoznak v prázdnom stave).
  final double opacity;

  const TheemisMark({super.key, this.width = 160, this.color, this.opacity = 1});

  @override
  Widget build(BuildContext context) {
    return _TheemisCanvas(
      width: width,
      color: color ?? Theme.of(context).colorScheme.onSurface,
      opacity: opacity,
      progress: 1,
    );
  }
}

/// Logo, ktorého písmená pribúdajú jedno po druhom – namiesto krúžiaceho
/// indikátora pri načítavaní.
class TheemisMarkAnimated extends StatefulWidget {
  final double width;
  final Color? color;

  /// Dĺžka jedného cyklu vrátane výdrže na konci.
  final Duration duration;

  final bool repeat;

  const TheemisMarkAnimated({
    super.key,
    this.width = 240,
    this.color,
    this.duration = const Duration(milliseconds: 950),
    this.repeat = true,
  });

  @override
  State<TheemisMarkAnimated> createState() => _TheemisMarkAnimatedState();
}

class _TheemisMarkAnimatedState extends State<TheemisMarkAnimated>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.repeat) {
      _c.repeat();
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // Písmená dobehnú v prvých 72 % cyklu, zvyšok je výdrž na celom slove.
        final t = (_c.value / 0.72).clamp(0.0, 1.0);
        return _TheemisCanvas(
          width: widget.width,
          color: color,
          opacity: 1,
          progress: t,
        );
      },
    );
  }
}

/// Linka s krátkym zvislým ťahom na ľavom konci – rameno písmena T ako
/// samostatný prvok. Na jednej obrazovke najviac raz, inak je z nej ozdoba.
class TheemisRule extends StatelessWidget {
  final double thickness;

  /// Ako vysoko trčí zvislý ťah nad linku.
  final double tick;

  final Color? color;

  const TheemisRule({super.key, this.thickness = 1.5, this.tick = 9, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.outlineVariant;
    return SizedBox(
      height: tick + thickness,
      width: double.infinity,
      child: CustomPaint(
        painter: _RulePainter(color: c, thickness: thickness, tick: tick),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _TheemisCanvas extends StatelessWidget {
  final double width;
  final Color color;
  final double opacity;
  final double progress;

  const _TheemisCanvas({
    required this.width,
    required this.color,
    required this.opacity,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final height = width / kTheemisAspect;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _MarkPainter(color: color, opacity: opacity, progress: progress),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  final Color color;
  final double opacity;
  final double progress;

  _MarkPainter({
    required this.color,
    required this.opacity,
    required this.progress,
  });

  static const _fade = 0.22; // podiel animácie na nábeh jedného písmena

  /// Štarty sú rozložené tak, aby posledné písmeno dobehlo presne na konci –
  /// inak by na záver viditeľne doskočilo.
  double _alpha(int i, int n) {
    if (progress >= 1) return 1;
    final start = n > 1 ? i * (1 - _fade) / (n - 1) : 0.0;
    return ((progress - start) / _fade).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / kTheemisViewBox.width;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.miter
      ..isAntiAlias = true;

    canvas.save();
    canvas.scale(scale);
    // Ťahy v písmene sa prekrývajú (rameno a stĺpik v T). Priesvitná farba by
    // prekryv stmavila, preto ide každé písmeno cez vlastnú vrstvu.
    final bounds = Rect.fromLTWH(0, 0, kTheemisViewBox.width, kTheemisViewBox.height)
        .inflate(kTheemisViewBox.height);
    final glyphs = kTheemisGlyphs;
    for (var i = 0; i < glyphs.length; i++) {
      final a = _alpha(i, glyphs.length) * opacity;
      if (a <= 0) continue;
      final layered = a < 1;
      if (layered) {
        canvas.saveLayer(
          bounds,
          Paint()..color = const Color(0xFF000000).withValues(alpha: a),
        );
      }
      paint.color = color;
      for (final stroke in glyphs[i]) {
        canvas.save();
        canvas.transform(stroke.matrix);
        paint
          ..strokeWidth = stroke.width
          ..strokeMiterLimit = stroke.miterLimit;
        canvas.drawPath(stroke.path, paint);
        canvas.restore();
      }
      if (layered) canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.color != color || old.opacity != opacity || old.progress != progress;
}

class _RulePainter extends CustomPainter {
  final Color color;
  final double thickness;
  final double tick;

  _RulePainter({required this.color, required this.thickness, required this.tick});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.square;
    final y = size.height - thickness / 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    final x = thickness / 2;
    canvas.drawLine(Offset(x, y), Offset(x, size.height - tick), paint);
  }

  @override
  bool shouldRepaint(_RulePainter old) =>
      old.color != color || old.thickness != thickness || old.tick != tick;
}
