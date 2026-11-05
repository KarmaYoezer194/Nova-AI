# Releasing Nova to testers

Step-by-step guide for Phase 12. Web (Chrome) is the main target, shared through
Firebase Hosting (free on the Spark plan). Android steps are at the end, for later.

## 1. One-time: reCAPTCHA for App Check (web release)

Release web builds prove they are the real app with reCAPTCHA v3 instead of a debug token.

1. Open <https://www.google.com/recaptcha/admin/create> (signed in with the university account).
2. **Label:** `Nova web`. **Type:** Score based (v3).
3. **Domains:** add `nova-chat-af63f.web.app`, `nova-chat-af63f.firebaseapp.com` and `localhost`.
4. If asked for a Google Cloud project, pick **nova-chat-af63f**. Submit.
5. You get two keys:
   - **Site key**: public. It goes into the build command (step 3 below).
   - **Secret key**: secret. It goes **only** into the Firebase console. Never paste it into code, chat or screenshots.
6. Firebase console → **App Check** → **Apps** → the web app → **reCAPTCHA** → paste the **secret key** → Save.

## 2. One-time: check the console

- **Authentication → Settings → Authorized domains:** `nova-chat-af63f.web.app` and `nova-chat-af63f.firebaseapp.com` should already be there.
- **App Check → APIs:** Firebase AI Logic and Cloud Firestore both **Enforced**.
- **App Check → Apps → web app → Manage debug tokens:** delete old tokens you no longer use (for example the first one, `68777e52…`).
- **Authentication → Sign-in method:** only Email/Password enabled (turn off Google and Anonymous if unused).

## 3. Build and publish

From the `nova` folder:

```powershell
.\scripts\release_web.ps1 -RecaptchaSiteKey <your site key> -Deploy
```

This runs the tests, builds the release web app, and publishes the security rules and the app.
Testers open **https://nova-chat-af63f.web.app** in Chrome.

To check the release build on your own computer first (without publishing):

```powershell
.\scripts\release_web.ps1 -RecaptchaSiteKey <your site key>
firebase emulators:start --only hosting   # then open http://localhost:5000
```

(Stop `flutter run` first: it uses port 5000 too.)

## 4. The tester week ("done when")

1. Send testers the link and ask them to create an account with any email and a new password (not one they use elsewhere).
2. Ask them to try: a normal chat, a photo of notes, a memory, a project, an essay outline (artifact) and "what's the date today?".
3. Collect bugs in one place (a shared doc or chat), with: what they did, what they expected, what happened, and a screenshot (no passwords or tokens in it).
4. After a week, bring the list to the next session so the bugs get fixed.

Limits to tell testers: Gemini's free tier has daily limits, so "Nova is busy" can happen; chats may be used by Google to improve its products (see the Privacy note in the app).

## 5. Firestore rules tests

```powershell
.\rules_test\run.ps1
```

Look for `ℹ fail 0`. (On Windows the Firebase CLI may print "An unexpected error has occurred" while shutting the emulator down afterwards. That is harmless if the tests passed.)

## Later: Android (App Distribution and Crashlytics)

Deferred until the first Android build (see Decisions in CLAUDE.md):

1. Move the Android SDK to a path without spaces (for example `C:\Android\sdk`) and update it in Android Studio → Settings → Android SDK, then run `flutter doctor`.
2. Add Crashlytics (`firebase_crashlytics`, Android only) and test a crash report.
3. Play Integrity for App Check: Firebase console → App Check → Android app → Play Integrity (needs the app's SHA-256 fingerprint).
4. Build: `flutter build apk --release`.
5. Firebase console → **App Distribution** → Android app → upload `build\app\outputs\flutter-apk\app-release.apk` → add testers by email → Distribute. Testers get an email with the install link.
