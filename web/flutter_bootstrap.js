{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
    // Use the image-cache worker as the app's sole root-scope worker. This
    // avoids a second registration replacing Flutter's worker and being
    // immediately unregistered by Flutter's deprecated default worker.
    serviceWorkerUrl: "peso-image-cache-worker.js?v=" + {{flutter_service_worker_version}},
  },
});
