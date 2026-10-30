{{flutter_js}}
{{flutter_build_config}}

// Grafické jadro (CanvasKit) sa načíta z tejto stránky, nie z Google CDN –
// vďaka tomu ho offline režim (sw.js) vie uložiť a apka ide aj bez internetu.
// Vlastný service worker (sw.js) sa registruje v index.html.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
});
