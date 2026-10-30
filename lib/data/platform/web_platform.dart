// Funkcie, ktoré existujú len vo webovej verzii (iPhone cez Safari):
// úložisko v prehliadači (IndexedDB) a „displej nezhasína“.
//
// Na Windows / Androide sa použije prázdna verzia (web_platform_stub.dart),
// takže tieto aplikácie fungujú presne ako doteraz.
export 'web_platform_stub.dart' if (dart.library.js_interop) 'web_platform_web.dart';
