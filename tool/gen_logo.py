"""Z SVG loga Theemis vygeneruje Dart s cestami jednotlivych pismen.

Pouzitie:
    python3 tool/gen_logo.py design/TheemisLogo5.svg lib/widgets/theemis_logo_paths.dart

Kazde pismeno sa ulozi ako zoznam tahov. Tah drzi cestu v povodnych suradniciach
plus maticu, ktorou sa ma vykreslit - vdaka tomu hrubka tahu vyjde presne tak ako
v SVG aj pri nerovnomernom zvacseni (Affinity take matice bezne exportuje).
"""
import os
import re
import sys
import xml.etree.ElementTree as ET

NS = '{http://www.w3.org/2000/svg}'
NUM = r'-?\d*\.?\d+(?:[eE][-+]?\d+)?'


def mul(a, b):
    a0, a1, a2, a3, a4, a5 = a
    b0, b1, b2, b3, b4, b5 = b
    return (a0 * b0 + a2 * b1, a1 * b0 + a3 * b1,
            a0 * b2 + a2 * b3, a1 * b2 + a3 * b3,
            a0 * b4 + a2 * b5 + a4, a1 * b4 + a3 * b5 + a5)


def apply(m, x, y):
    return (m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5])


def parse_transform(t):
    m = (1.0, 0, 0, 1.0, 0, 0)
    for name, args in re.findall(r'(\w+)\s*\(([^)]*)\)', t or ''):
        v = [float(x) for x in re.findall(NUM, args)]
        if name == 'matrix':
            cur = tuple(v[:6])
        elif name == 'translate':
            cur = (1, 0, 0, 1, v[0], v[1] if len(v) > 1 else 0)
        elif name == 'scale':
            cur = (v[0], 0, 0, v[1] if len(v) > 1 else v[0], 0, 0)
        else:
            raise SystemExit('nepodporovana transformacia: ' + name)
        m = mul(m, cur)
    return m


def parse_d(d):
    tok = re.findall(r'[MLCmlc]|' + NUM, d)
    out, cur, i, px, py, cmd = [], None, 0, 0.0, 0.0, None
    while i < len(tok):
        if tok[i].isalpha():
            cmd = tok[i]
            i += 1
        rel, c = cmd.islower(), cmd.upper()
        if c == 'M':
            x, y = float(tok[i]), float(tok[i + 1]); i += 2
            if rel: x, y = px + x, py + y
            cur = [('M', x, y)]; out.append(cur); px, py = x, y
            cmd = 'l' if rel else 'L'
        elif c == 'L':
            x, y = float(tok[i]), float(tok[i + 1]); i += 2
            if rel: x, y = px + x, py + y
            cur.append(('L', x, y)); px, py = x, y
        elif c == 'C':
            v = [float(x) for x in tok[i:i + 6]]; i += 6
            if rel:
                v = [px + v[0], py + v[1], px + v[2], py + v[3], px + v[4], py + v[5]]
            cur.append(('C', *v)); px, py = v[4], v[5]
        else:
            raise SystemExit('nepodporovany prikaz: ' + c)
    return out


def style(s, prop, default):
    m = re.search(prop + r':\s*([\d.]+)', s or '')
    return float(m.group(1)) if m else default


def collect(node, m, out):
    m = mul(m, parse_transform(node.get('transform')))
    if node.tag == NS + 'path' and node.get('d'):
        out.append({
            'm': m,
            'w': style(node.get('style'), 'stroke-width', 1.0),
            'ml': style(node.get('style'), 'stroke-miterlimit', 10.0),
            'subs': parse_d(node.get('d')),
        })
    for ch in node:
        collect(ch, m, out)


def fmt(v):
    return ('%.4f' % v).rstrip('0').rstrip('.') or '0'


def main():
    src, dst = sys.argv[1], sys.argv[2]
    root = ET.parse(src).getroot()
    vb = [float(v) for v in re.findall(NUM, root.get('viewBox'))]

    # Skupina pismen = ta s najvacsim poctom priamych podskupin <g>.
    group, best, chain = None, 0, {}

    def walk(n, path):
        nonlocal group, best
        chain[id(n)] = path
        k = sum(1 for ch in n if ch.tag == NS + 'g')
        if k > best:
            group, best = n, k
        for ch in n:
            walk(ch, path + [n])

    walk(root, [])
    if group is None or best < 3:
        raise SystemExit('nenasiel som skupinu s pismenami')

    base = (1.0, 0, 0, 1.0, 0, 0)
    for n in chain[id(group)] + [group]:
        base = mul(base, parse_transform(n.get('transform')))

    letters = []
    for g in group:
        strokes = []
        collect(g, base, strokes)
        if not strokes:
            continue
        pts = [apply(st['m'], seg[j], seg[j + 1])
               for st in strokes for sub in st['subs'] for seg in sub
               for j in range(1, len(seg), 2)]
        letters.append({'id': g.get('id'), 'strokes': strokes,
                        'x0': min(p[0] for p in pts),
                        'y0': min(p[1] for p in pts),
                        'y1': max(p[1] for p in pts)})
    letters.sort(key=lambda L: L['x0'])

    # Uciarie slova = spodok pismen bez T (T presahuje).
    body = [L for L in letters if L['id'] != 'T'] or letters
    baseline = max(L['y1'] for L in body)
    cap = baseline - min(L['y0'] for L in body)

    o = []
    w = o.append
    w('// GENEROVANE - neupravuj rucne.')
    w('// Zdroj: %s' % os.path.basename(src))
    w('// Znovu: python3 tool/gen_logo.py design/<logo>.svg \\')
    w('//            lib/widgets/theemis_logo_paths.dart')
    w('')
    w("import 'dart:typed_data';")
    w("import 'dart:ui';")
    w('')
    w('/// Jeden ťah loga: cesta vo vlastných súradniciach, matica, ktorou sa')
    w('/// vykresľuje, a hrúbka ťahu. Hrúbka platí pred aplikovaním matice –')
    w('/// preto vyjde presne tak ako v SVG aj pri nerovnomernej mierke.')
    w('class TheemisStroke {')
    w('  final Path path;')
    w('  final Float64List matrix;')
    w('  final double width;')
    w('  final double miterLimit;')
    w('  const TheemisStroke(this.path, this.matrix, this.width, this.miterLimit);')
    w('}')
    w('')
    w('Float64List _m(double a, double b, double c, double d, double e, double f) =>')
    w('    Float64List.fromList([a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, e, f, 0, 1]);')
    w('')
    w('/// Rozmer kresby – v tomto priestore sú všetky cesty nižšie.')
    w('const kTheemisViewBox = Size(%s, %s);' % (fmt(vb[2]), fmt(vb[3])))
    w('')
    w('/// Účiarie slova (bez presahu T). Podľa nej zarovnávaj logo vedľa textu.')
    w('const kTheemisBaseline = %s;' % fmt(baseline))
    w('')
    w('/// Výška písmen – užitočná na odvodenie hrúbky linky v [TheemisRule].')
    w('const kTheemisCapHeight = %s;' % fmt(cap))
    w('')
    names = []
    for i, L in enumerate(letters):
        name = '_g%d' % i
        names.append(name)
        w('// %s' % L['id'])
        w('List<TheemisStroke> %s() => [' % name)
        for st in L['strokes']:
            for sub in st['subs']:
                w('  TheemisStroke(')
                w('    Path()')
                for seg in sub:
                    a = [fmt(v) for v in seg[1:]]
                    if seg[0] == 'M':
                        w('      ..moveTo(%s, %s)' % tuple(a))
                    elif seg[0] == 'L':
                        w('      ..lineTo(%s, %s)' % tuple(a))
                    else:
                        w('      ..cubicTo(%s, %s, %s, %s, %s, %s)' % tuple(a))
                w('    ,')
                w('    _m(%s),' % ', '.join(fmt(v) for v in st['m']))
                w('    %s,' % fmt(st['w']))
                w('    %s,' % fmt(st['ml']))
                w('  ),')
        w('];')
        w('')
    w('/// Písmená zľava doprava: %s' % ' '.join(L['id'] for L in letters))
    w('final List<List<TheemisStroke>> kTheemisGlyphs =')
    w('    List.unmodifiable([%s]);' % ', '.join(n + '()' for n in names))
    w('')
    open(dst, 'w', encoding='utf-8').write('\n'.join(o))
    print('zapisane:', dst)
    print('pismena:', ' '.join(L['id'] for L in letters))
    print('viewBox %gx%g  uciarie %.2f  vyska pismen %.2f' % (vb[2], vb[3], baseline, cap))


main()
