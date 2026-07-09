// Cloudflare Worker: Firebase Auth handler proxy for bussdown.space.
//
// Why this exists: the web app signs in with Google via
// signInWithRedirect/linkWithRedirect, which only works in modern browsers
// (Chrome 115+, Safari, Firefox — all of which partition third-party storage)
// when the Firebase auth handler is served from the SAME origin as the app.
// The app therefore uses authDomain: 'bussdown.space' (see
// lib/firebase_options.dart) and this worker reverse-proxies the handler
// routes to the real Firebase-hosted helper.
//
// Deploy: Cloudflare dashboard -> Workers & Pages -> Create Worker, paste
// this file, then add the route `*bussdown.space/__/*` (zone bussdown.space)
// pointing at the worker. Full steps: docs/google-auth-proxy.md.

const UPSTREAM_HOST = 'push-d9e0b.firebaseapp.com';

export default {
  async fetch(request) {
    const url = new URL(request.url);
    url.hostname = UPSTREAM_HOST;
    // Rebuilding the Request from the rewritten URL keeps method, headers,
    // and body, and lets fetch() set the Host header to the upstream.
    return fetch(new Request(url.toString(), request));
  },
};
