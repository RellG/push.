# Google sign-in auth-handler proxy (bussdown.space)

## The problem this solves

The web app signs into Google with `signInWithRedirect` / `linkWithRedirect`.
With the default `authDomain` (`push-d9e0b.firebaseapp.com`), the redirect
result is stored on the **firebaseapp.com** origin and read back through a
hidden cross-origin iframe. Chrome 115+, Safari (ITP), Firefox (ETP), and
essentially all mobile browsers now block that third-party storage access, so
`getRedirectResult()` silently resolves `null`: sign-in "works" at Google,
then the user lands back on onboarding still anonymous. This is Firebase's
documented limitation — see
<https://firebase.google.com/docs/auth/web/redirect-best-practices> (we use
its Option 3: proxy auth requests).

The fix: serve the auth handler from the app's own origin.

- `lib/firebase_options.dart` sets `authDomain: 'bussdown.space'`.
- A Cloudflare Worker (`infra/cloudflare/auth-proxy-worker.js`) reverse-proxies
  `bussdown.space/__/*` to `push-d9e0b.firebaseapp.com`, so
  `/__/auth/handler`, `/__/auth/iframe`, and `/__/firebase/init.json` resolve
  same-origin with the app.

## One-time setup (do BOTH steps BEFORE deploying the authDomain change)

### 1. Cloudflare Worker (dashboard → Workers & Pages)

1. Create a new Worker (name suggestion: `push-auth-proxy`) and paste in
   `infra/cloudflare/auth-proxy-worker.js`.
2. Deploy it, then under the worker's **Settings → Domains & Routes → Add →
   Route**, add route `*bussdown.space/__/*` on the `bussdown.space` zone.
   (The `*` host prefix also covers `www.bussdown.space`.)
3. Verify: `curl -I https://bussdown.space/__/firebase/init.json` returns 200
   with JSON, and `https://bussdown.space/__/auth/handler` returns an HTML
   page (a Firebase helper page, not the Push. app).

### 2. Google Cloud OAuth client (console.cloud.google.com → project `push-d9e0b`)

APIs & Services → Credentials → OAuth 2.0 Client IDs → *Web client (auto
created by Google Service)*:

- **Authorized JavaScript origins**: add `https://bussdown.space` and
  `https://www.bussdown.space`.
- **Authorized redirect URIs**: add `https://bussdown.space/__/auth/handler`.

Leave the existing `push-d9e0b.firebaseapp.com` entries in place (native
platforms and the Firebase console still use them).

Firebase Auth **authorized domains** must contain `bussdown.space` — it
already does (that was required even before this change).

## Consequences / gotchas

- Google sign-in on the legacy `push-sm51.onrender.com` URL no longer works
  (its origin differs from the `bussdown.space` auth handler, recreating the
  original problem). `bussdown.space` is canonical; anonymous usage on the
  legacy URL is unaffected.
- If the Cloudflare route is ever removed, Google sign-in breaks with a 404 on
  `/__/auth/handler` (the SPA rewrite serves the app instead). The Worker route
  must outlive the app deploy.
- Native Android/iOS builds are untouched: `authDomain` is a web-only option.
