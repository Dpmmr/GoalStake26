// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import { FlutterLoader } from './loader.js';

if (!window._flutter) {
  window._flutter = {};
}

if (!window._flutter.loader) {
  window._flutter.loader = new FlutterLoader();
}

if (!window._flutter) {
  window._flutter = {};
}
_flutter.buildConfig = {"engineRevision":"42d3d75a56efe1a2e9902f52dc8006099c45d937","builds":[{"compileTarget":"dart2js","renderer":"canvaskit","mainJsPath":"main.dart.js"},{}]};

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: "4236973014" /* Flutter's service worker is deprecated and will be removed in a future Flutter release. */
  }
});
