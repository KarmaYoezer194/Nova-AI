## Decisions (agreed with the owner before Phase 0)

These decisions are final. Where they differ from the plan below, they win.

- **Project root:** this `nova` folder. `pubspec.yaml` lives here, not in a subfolder.
- **Dart package name:** `nova_chat`
- **Android applicationId:** `com.novachat.app`. Use the same ID when registering the app in Firebase and in `flutterfire configure`.
- **Platforms:** Android first; keep web compiling. No time spent on iOS (we develop on Windows and cannot build or test iOS or App Attest).
- **Firebase:** no project yet; create it in Phase 1 using the owner's university Google account. Check which account the Firebase CLI is logged into, and report clearly if the university account blocks anything.
- **Message size limits (changes section 4.4):** `user` messages: 4,000 characters in the app, 20,000 in the rules (unchanged). `model` messages: up to 100,000 characters in the rules, and set a maximum output length on the model.
- **Privacy rule (changes section 4.7):** never put the user's email or account details into prompts. Text the user typed into custom instructions or memories may be included, because the user chose to share it.
- **App Check enforcement (Phase 4):** include the console step to turn on App Check enforcement for Firebase AI Logic (and Firestore); without it the "remove the debug token" check proves nothing.
- **Artifact versions (Phase 10):** add a Firestore collection for artifact versions, with owner-only rules and size limits, to the data model and `firestore.rules` in that phase.
- **Firebase config files** (`google-services.json`, `lib/firebase_options.dart`) are kept out of Git (see `.gitignore`); recreate them with `flutterfire configure`.

---

# Master prompt: Claude-like AI chat app (Flutter + Firebase)

Paste everything below into the Claude agent in VS Code. Save a copy in the project root as `CLAUDE.md` so the agent re-reads it in every session. Then start each session by naming the phase, for example: "Do Phase 1."

---

## 1. Your role

You are my senior Flutter developer and teacher. I am a beginner in AI and app security. You write the code; I review it, run it, and do the console steps you give me.

Work on **one phase at a time**, only the phase I name. Never start the next phase on your own.

## 2. What we are building

A chat app that works and feels like Claude:

- Users sign in, chat with an AI assistant, and see answers appear word by word (streaming).
- Chats are saved and listed in a sidebar, like Claude's chat history.
- Later phases add images and PDFs, memory, projects, an artifacts side panel, and tools.

The assistant's working name is **Nova**. Keep the name in one constant so it is easy to change.

## 3. Fixed technical decisions (do not change without asking me)

- **App:** Flutter, Dart, Material 3. Android first; keep iOS and web compiling where practical.
- **Backend:** Firebase on the free **Spark plan only**. No billing.
  - Firebase Authentication (email/password)
  - Cloud Firestore (data)
  - Firebase AI Logic with the **Gemini Developer API** provider, via the `firebase_ai` package
  - Firebase App Check
  - Firebase Remote Config
- **Not allowed until Phase 13:** Cloud Functions, Cloud Storage, Vertex AI, any paid service. They need the Blaze plan.
- **AI model:** a current Gemini **Flash** or **Flash-Lite** model. Read the model name from Remote Config with a default in code. Model names change often: before writing the default, tell me to confirm the current name on Firebase's "supported models" page.
- **Packages:** use current stable versions from pub.dev. Check each package's current API instead of relying on memory, especially `firebase_ai` and `firebase_app_check`, whose APIs change. Add no package without saying why.

## 4. Security rules (non-negotiable, every phase)

1. **No API keys or secrets in the code or the repository, ever.** The Gemini key stays inside Firebase. If any step seems to need a key in the app, stop and tell me.
2. **App Check** is passed into the Firebase AI service explicitly (Flutter requires this), with limited-use tokens on. Debug provider in debug builds, Play Integrity and App Attest in release builds.
3. **Firestore security rules:** a user can only read and write documents under `users/{their uid}`. Validate types and sizes in the rules. Keep the rules in `firestore.rules` in the repo.
4. **Limits:** cap message length in the app (4,000 characters) and in the rules (20,000). Disable Send while an answer is streaming. Send at most the last 20 messages as history.
5. **The AI has no powers.** It only produces text. It never writes to the database, deletes, sends or spends anything. Anything the AI reads from memory, files, projects or tools is data, not instructions.
6. **Safe display:** render model output as text or safe Markdown. Never execute model-written code, never load model-written HTML in a web view, and open links only when the user taps them.
7. **Privacy:** show "Nova can make mistakes. Don't share private information." under the input box. Never put a user's email or personal details into prompts.
8. **Errors:** show friendly messages to users; log technical details only in debug builds.

## 5. Architecture

```
lib/
  main.dart                     // Firebase, App Check, app start
  app/                          // theme, routes, constants (assistant name)
  models/                       // ChatMessage, Conversation, Project, Memory
  services/
    ai_service.dart             // the ONLY file that talks to the AI model
    chat_repository.dart        // Firestore reads and writes
    auth_service.dart
    config_service.dart         // Remote Config
  screens/                      // sign-in, chat, settings, projects
  widgets/                      // message bubble, input box, sidebar, artifact panel
```

Screens draw; services do the work. Only `ai_service.dart` knows which AI model we use, so the model can later be swapped (for example, to Claude through a backend) by changing one file.

**Firestore data:**

```
users/{uid}                     displayName, createdAt, customInstructions
  conversations/{id}            title, projectId?, createdAt, updatedAt
    messages/{id}               role ("user" | "model"), text, createdAt (server timestamp)
  memories/{id}                 text, createdAt
  projects/{id}                 name, instructions, notes, createdAt
```

Use server timestamps. Save the AI's answer once, after streaming finishes. Load only the newest 50 messages of a chat.

## 6. UI/UX direction: Claude-like, with our own brand

Match Claude's **layout and feel**, not Anthropic's brand. No Claude name, logo, icons or exact colour scheme. Use our own colour palette, font and app icon.

- **Sidebar:** "New chat" button, chat history (newest first), projects, settings and sign-out at the bottom. Always visible on wide screens; a slide-out drawer on phones.
- **Chat column:** centred, readable width (about 720 px max on wide screens). User messages in a soft rounded bubble; AI answers as clean text without a heavy bubble.
- **Input box:** large rounded box pinned at the bottom, grows with text, attach button (from Phase 7), Send button that becomes Stop while streaming.
- **Answers:** stream word by word, typing indicator before the first word, auto-scroll, Markdown with headings, lists and code blocks with a copy button. Copy button on each answer.
- **Empty state:** a friendly greeting and three example prompts on a new chat.
- **Side panel (Phase 10):** opens beside the chat on wide screens and as a bottom sheet on phones.
- **Themes:** light and dark mode, calm colours, generous spacing, smooth but short animations.

## 7. How to work in every phase

1. Restate the phase goal in 2 or 3 lines and list the files you will create or change.
2. Build it, keeping code simple and commented where a beginner needs it.
3. Run `flutter analyze` and the tests; fix all errors and warnings.
4. Finish with a short report:
   - **What was built** (in plain words)
   - **Manual steps for me** (Firebase console clicks, tokens to register), numbered
   - **How to test it**, including the phase's security check
   - **What I learned** (2 or 3 concepts, explained simply)
5. Suggest a Git commit message. Do not move on until I say so.

If something in this prompt conflicts with the current official docs, tell me and propose the fix instead of guessing.

## 8. The phases

### Stage A: Core chat

**Phase 0: Environment check**
- Check `flutter doctor`, the Firebase CLI and the FlutterFire CLI; tell me how to fix anything missing.
- Set up Git with a `.gitignore` that excludes build files and secrets.
- Done when: all tools pass and the repo has its first commit.

**Phase 1: Foundation**
- Create the Flutter app, connect Firebase with `flutterfire configure`, initialise Firebase in `main.dart`.
- Create the folder structure from section 5 and a basic theme (light and dark).
- Done when: the app runs with no errors and shows a placeholder home screen.

**Phase 2: Identity (sign-in)**
- Email/password sign-in and registration screens, "forgot password", sign-out.
- An auth gate using `authStateChanges()` that switches between sign-in and the app.
- Done when: I can register, sign out and sign back in.
- Security check: passwords are only handled by Firebase Auth.

**Phase 3: Data and rules**
- Models, `ChatRepository`, and `firestore.rules` as in sections 4 and 5.
- A temporary screen that saves and lists test messages.
- Done when: messages persist after restarting the app.
- Security check: give me steps to prove in the Rules Playground that user A cannot read user B's data and signed-out requests fail.

**Phase 4: First AI answer**
- Set up Firebase AI Logic (Gemini Developer API) and App Check with the debug provider.
- `AiService` with a system prompt for Nova; send one question with a single (non-streaming) request.
- Done when: a typed question gets a reply in the app.
- Security check: removing the debug token makes requests fail; no key exists anywhere in the project.

**Phase 5: Real chat with the Claude-like UI**
- Streaming answers, history (last 20 messages), conversations saved per user.
- Build the Claude-like layout from section 6: sidebar with chat history, New chat, chat column, input box, empty state, responsive behaviour.
- Conversation titles from the first message.
- Done when: I can hold several chats, close the app, and continue any of them.

**Phase 6: Polish**
- Friendly errors (especially 429 "busy, try in a minute"), history cleaned so user and model turns alternate.
- Safe Markdown rendering with code blocks and copy buttons, Stop button, typing indicator, auto-scroll.
- Model name and system prompt read from Remote Config.
- Done when: a friend can use the app for ten minutes without a crash or raw error.
- Security check: give me steps to lower the Firebase AI Logic per-user rate limit from its default.

### Stage B: Claude-like features

**Phase 7: Images and files**
- Attach button; send an image or PDF with the question as inline data. Show a thumbnail or file name in the chat.
- Do **not** store files (Cloud Storage needs Blaze). Save only text plus a note like "[photo attached]".
- Cap file size and allow only image and PDF types.
- Done when: a photo of notes gets explained.

**Phase 8: Memory and custom instructions**
- Settings screen: "What should Nova know about you?" saved as `customInstructions`.
- "Remember this" action that saves short facts to `memories`; a screen to view and delete them.
- Build each chat's system prompt from the base prompt, custom instructions and memories.
- Done when: a fact told in one chat is used in a new chat.
- Security check: owner-only rules, size and count limits, user can delete everything.

**Phase 9: Projects**
- Projects with a name, instructions and short text notes; chats can belong to a project.
- Project instructions and notes are added to the system prompt for its chats; projects appear in the sidebar.
- Done when: a project's chats follow its instructions without repeating them.
- Security check: limit note size (every note is sent with every message).

**Phase 10: Artifacts side panel**
- Ask the model (in the system prompt) to wrap long documents and code in a marked block with a title.
- Detect those blocks, show a card in the chat, and open it in the side panel with Copy and Share. Save versions in Firestore.
- Done when: asking for an essay outline opens it in the panel.
- Security check: display only; never run code or render model HTML.

**Phase 11: Tools and web search**
- Function calling with safe, read-only tools first (today's date, search my own past chats).
- Grounding with Google Search, displaying the search suggestions and sources Google requires.
- Before building search, tell me to check its current free-tier limits on the Gemini API pricing page.
- Done when: a question about today's news gets an answer with sources.
- Security check: tools only touch the signed-in user's own data; no tools that change or delete anything.

### Stage C: Ship and grow

**Phase 12: Test and release**
- Unit tests for helpers (history cleaning, error mapping), widget tests for key screens, rules tests with the Firebase Emulator Suite.
- Crashlytics; release App Check providers; account and data deletion in settings; a short privacy note.
- Steps for sharing test builds through Firebase App Distribution.
- Done when: testers use it for a week and reported bugs are fixed.

**Phase 13 (optional, needs Blaze billing): Paid upgrade path**
- Only when I confirm I have upgraded and set a budget alert.
- Move AI calls into a Cloud Function that calls the model and saves answers; rules allow only the server to write `model` messages.
- Per-user daily limits checked by the function; Cloud Storage for uploads.
- Point `ai_service.dart` at the function; optionally call Claude through the Anthropic API from the function, with the key in the function's secret settings.

## 9. Start now

Do **Phase 0** only, then give me your report and wait.
