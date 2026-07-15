// Push. — camera pushup capture engine.
//
// Runs the whole video pipeline on the JS side: getUserMedia, MediaPipe
// Pose Landmarker inference, and the skeleton overlay all live here, and
// only a tiny Float32Array of landmarks crosses into Dart per frame. Never
// ship frames across the JS↔Dart boundary.
//
// The MediaPipe runtime (~3 MB wasm) and pose model (~5.5 MB) are fetched
// lazily from pinned CDN URLs on first start(), NOT bundled: everything in
// web/ lands in Flutter's service-worker manifest, and the app shell must
// not grow ~12 MB for an optional screen. No frame ever leaves the device —
// inference is fully local; the CDNs only serve static code/model bytes.
(function () {
  'use strict';

  var MEDIAPIPE_VERSION = '0.10.35';
  var CDN_BASE =
    'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@' +
    MEDIAPIPE_VERSION;
  var WASM_BASE = CDN_BASE + '/wasm';
  var BUNDLE_URL = CDN_BASE + '/vision_bundle.mjs';
  var MODEL_URL =
    'https://storage.googleapis.com/mediapipe-models/pose_landmarker/' +
    'pose_landmarker_lite/float16/1/pose_landmarker_lite.task';

  // Landmark indices shipped to Dart, in the wire order PoseSample.fromFlat
  // expects: nose, eyes, shoulders, elbows, wrists.
  var SENT_LANDMARKS = [0, 2, 5, 11, 12, 13, 14, 15, 16];

  // Torso + arms + upper legs, for the overlay only.
  var SKELETON = [
    [11, 12], [11, 13], [13, 15], [12, 14], [14, 16],
    [11, 23], [12, 24], [23, 24], [23, 25], [24, 26],
  ];

  var MIN_DRAW_VISIBILITY = 0.4;

  var session = null;

  async function start(container, onFrame, onReady, onError) {
    stop();
    var s = {
      stopped: false,
      video: null,
      canvas: null,
      stream: null,
      landmarker: null,
      raf: 0,
    };
    session = s;

    try {
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw { name: 'NotSupportedError', message: 'camera-unsupported' };
      }

      // A retried session reuses the container — drop any stale layers.
      container.innerHTML = '';
      container.style.position = 'relative';
      container.style.width = '100%';
      container.style.height = '100%';
      container.style.overflow = 'hidden';
      container.style.background = '#000';

      var video = document.createElement('video');
      video.muted = true;
      video.autoplay = true;
      video.setAttribute('playsinline', ''); // iOS: never go fullscreen
      styleLayer(video.style);
      // Dimmed + monochrome so the feed sits behind the HUD instead of
      // competing with it.
      video.style.filter = 'grayscale(1) brightness(0.55)';

      var canvas = document.createElement('canvas');
      styleLayer(canvas.style);

      container.appendChild(video);
      container.appendChild(canvas);
      s.video = video;
      s.canvas = canvas;

      var results = await Promise.all([
        navigator.mediaDevices.getUserMedia({
          video: {
            facingMode: 'user',
            width: { ideal: 640 },
            height: { ideal: 480 },
          },
          audio: false,
        }),
        createLandmarker(),
      ]);
      s.stream = results[0];
      s.landmarker = results[1];
      if (s.stopped) {
        releaseMedia(s);
        return;
      }

      video.srcObject = s.stream;
      await video.play();
      if (s.stopped) {
        return;
      }

      onReady();

      var startTime = performance.now();
      var lastVideoTime = -1;
      var loop = function () {
        if (s.stopped) {
          return;
        }
        if (s.video.readyState >= 2 && s.video.currentTime !== lastVideoTime) {
          lastVideoTime = s.video.currentTime;
          var now = performance.now();
          var result = s.landmarker.detectForVideo(s.video, now);
          handleResult(s, result, now - startTime, onFrame);
        }
        s.raf = requestAnimationFrame(loop);
      };
      s.raf = requestAnimationFrame(loop);
    } catch (err) {
      var wasStopped = s.stopped;
      cleanup(s);
      if (session === s) {
        session = null;
      }
      if (!wasStopped) {
        onError(errorCode(err));
      }
    }
  }

  function stop() {
    if (session) {
      cleanup(session);
      session = null;
    }
  }

  async function createLandmarker() {
    var vision = await import(BUNDLE_URL);
    var fileset = await vision.FilesetResolver.forVisionTasks(WASM_BASE);
    var options = function (delegate) {
      return {
        baseOptions: { modelAssetPath: MODEL_URL, delegate: delegate },
        runningMode: 'VIDEO',
        numPoses: 1,
        minPoseDetectionConfidence: 0.5,
        minPosePresenceConfidence: 0.5,
        minTrackingConfidence: 0.5,
      };
    };
    try {
      return await vision.PoseLandmarker.createFromOptions(
        fileset,
        options('GPU')
      );
    } catch (err) {
      // Some browsers/GPUs can't run the GPU delegate; CPU is slower but
      // universal.
      return await vision.PoseLandmarker.createFromOptions(
        fileset,
        options('CPU')
      );
    }
  }

  function handleResult(s, result, elapsedMs, onFrame) {
    var canvas = s.canvas;
    var video = s.video;
    if (canvas.width !== video.videoWidth && video.videoWidth > 0) {
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
    }
    var ctx = canvas.getContext('2d');
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    var lm = result.landmarks && result.landmarks[0];
    if (!lm) {
      return;
    }

    drawSkeleton(ctx, lm, canvas.width, canvas.height);

    var data = new Float32Array(2 + SENT_LANDMARKS.length * 4);
    data[0] = elapsedMs;
    data[1] = video.videoHeight > 0 ? video.videoWidth / video.videoHeight : 1;
    for (var i = 0; i < SENT_LANDMARKS.length; i++) {
      var p = lm[SENT_LANDMARKS[i]];
      var base = 2 + i * 4;
      if (p) {
        data[base] = p.x;
        data[base + 1] = p.y;
        data[base + 2] = p.z || 0;
        data[base + 3] = p.visibility === undefined ? 1 : p.visibility;
      }
    }
    onFrame(data);
  }

  function drawSkeleton(ctx, lm, w, h) {
    var lineWidth = Math.max(2, w / 320);
    ctx.lineWidth = lineWidth;
    ctx.lineCap = 'round';
    ctx.strokeStyle = 'rgba(250, 250, 250, 0.85)';
    ctx.fillStyle = 'rgba(250, 250, 250, 0.85)';

    for (var i = 0; i < SKELETON.length; i++) {
      var a = lm[SKELETON[i][0]];
      var b = lm[SKELETON[i][1]];
      if (!visible(a) || !visible(b)) {
        continue;
      }
      ctx.beginPath();
      ctx.moveTo(a.x * w, a.y * h);
      ctx.lineTo(b.x * w, b.y * h);
      ctx.stroke();
    }

    for (var j = 0; j < SENT_LANDMARKS.length; j++) {
      var p = lm[SENT_LANDMARKS[j]];
      if (!visible(p)) {
        continue;
      }
      ctx.beginPath();
      ctx.arc(p.x * w, p.y * h, lineWidth * 1.6, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  function visible(p) {
    return (
      p && (p.visibility === undefined || p.visibility >= MIN_DRAW_VISIBILITY)
    );
  }

  function styleLayer(style) {
    style.position = 'absolute';
    style.top = '0';
    style.left = '0';
    style.width = '100%';
    style.height = '100%';
    style.objectFit = 'cover';
    // Mirror like a selfie camera so moving left moves left.
    style.transform = 'scaleX(-1)';
  }

  function releaseMedia(s) {
    if (s.stream) {
      s.stream.getTracks().forEach(function (t) {
        t.stop();
      });
      s.stream = null;
    }
    if (s.landmarker) {
      try {
        s.landmarker.close();
      } catch (err) {
        /* already closed */
      }
      s.landmarker = null;
    }
  }

  function cleanup(s) {
    s.stopped = true;
    if (s.raf) {
      cancelAnimationFrame(s.raf);
      s.raf = 0;
    }
    releaseMedia(s);
    if (s.video) {
      s.video.srcObject = null;
    }
  }

  function errorCode(err) {
    if (err && err.name === 'NotAllowedError') {
      return 'camera-permission-denied';
    }
    if (err && err.name === 'NotFoundError') {
      return 'camera-not-found';
    }
    if (err && err.name === 'NotSupportedError') {
      return 'camera-unsupported';
    }
    return String((err && err.message) || err);
  }

  window.pushPoseCapture = { start: start, stop: stop };
})();
