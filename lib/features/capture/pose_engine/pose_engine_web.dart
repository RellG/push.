import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:push_app/domain/models/pose_sample.dart';
import 'package:push_app/features/capture/pose_engine/pose_engine.dart';

// Hand-rolled bindings instead of package:web: the engine only needs to
// mint one container element and talk to `web/motion/pose_capture.js`
// (loaded by index.html), which isn't worth a new dependency.

@JS('document.createElement')
external JSObject _documentCreateElement(JSString tag);

@JS('pushPoseCapture')
external JSObject? get _poseCaptureScript;

@JS('pushPoseCapture.start')
external void _poseCaptureStart(
  JSObject container,
  JSFunction onFrame,
  JSFunction onReady,
  JSFunction onError,
);

@JS('pushPoseCapture.stop')
external void _poseCaptureStop();

const _viewType = 'push-pose-capture';
final _containers = <int, JSObject>{};
var _viewFactoryRegistered = false;

void _ensureViewFactory() {
  if (_viewFactoryRegistered) {
    return;
  }
  _viewFactoryRegistered = true;
  ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
    final container = _documentCreateElement('div'.toJS);
    _containers[viewId] = container;
    return container;
  });
}

extension type _DomElement(JSObject _) implements JSObject {
  external bool get isConnected;
}

/// Web pose engine: hosts the JS capture pipeline inside an
/// [HtmlElementView] and forwards its per-frame landmark arrays into
/// [PoseSample]s. One engine instance backs one capture session.
class WebPoseEngine implements PoseEngine {
  JSObject? _container;
  var _running = false;

  @override
  bool get isSupported => true;

  @override
  Widget buildPreview() {
    _ensureViewFactory();
    return HtmlElementView(
      viewType: _viewType,
      onPlatformViewCreated: (viewId) {
        // Every (re)mount of the preview delivers a fresh container; keep
        // the newest one so an error → retry remount doesn't leave start()
        // pointed at a detached element.
        final container = _containers.remove(viewId);
        if (container != null) {
          _container = container;
        }
      },
    );
  }

  /// Waits until the preview's container element is both created and
  /// attached to the document — onPlatformViewCreated can fire before the
  /// engine slots the element into the DOM, so poll rather than trust the
  /// event alone.
  Future<JSObject?> _connectedContainer() async {
    for (var attempt = 0; attempt < 100; attempt += 1) {
      final container = _container;
      if (container != null && _DomElement(container).isConnected) {
        return container;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return null;
  }

  @override
  Future<void> start({
    required PoseSampleCallback onSample,
    required VoidCallback onReady,
    required PoseErrorCallback onError,
  }) async {
    if (_running) {
      return;
    }
    _running = true;

    // The DOM container only exists once the preview widget has laid out.
    final container = await _connectedContainer();
    if (!_running) {
      return; // stopped while waiting for the platform view
    }
    if (container == null) {
      onError('pose-engine-view-missing');
      return;
    }
    if (_poseCaptureScript == null) {
      onError('pose-engine-script-missing');
      return;
    }

    void handleFrame(JSFloat32Array data) {
      final sample = PoseSample.fromFlat(data.toDart);
      if (sample != null) {
        onSample(sample);
      }
    }

    void handleError(JSString code) => onError(code.toDart);

    _poseCaptureStart(
      container,
      handleFrame.toJS,
      onReady.toJS,
      handleError.toJS,
    );
  }

  @override
  Future<void> stop() async {
    if (!_running) {
      return;
    }
    _running = false;
    if (_poseCaptureScript != null) {
      _poseCaptureStop();
    }
  }
}

PoseEngine createPoseEngine() => WebPoseEngine();
