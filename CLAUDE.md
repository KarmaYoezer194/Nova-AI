## Decisions (agreed with the owner before Phase 0)

These decisions are final. Where they differ from the plan below, they win.

- **Project root:** this `nova` folder. `pubspec.yaml` lives here, not in a subfolder.
- **Dart package name:** `nova_chat`
- **Android applicationId:** `com.novachat.app`. Use the same ID when registering the app in Firebase and in `flutterfire configure`.
- **Platforms (changes section 3):** **web (Chrome) is the main target.** The owner runs the app with `flutter run -d chrome`. Android is secondary: keep it compiling and keep the applicationId above, but test in the browser first. No time spent on iOS (we develop on Windows and cannot build or test iOS or App Attest).
- **App Check on web (changes section 4.2):** debug provider in debug builds (token is printed in the browser console); reCAPTCHA provider for release web builds. Play Integrity only when Android is released. `web_dev_config.yaml` fixes the dev port at 5000, so plain `flutter run -d chrome` keeps the same debug token between runs.
- **Android SDK:** the SDK path contains a space, which breaks Android builds. Not blocking for web; fix it (move to `C:\Android\sdk`) before the first Android build.
- **Firebase:** no project yet; create it in Phase 1 using the owner's university Google account. Check which account the Firebase CLI is logged into, and report clearly if the university account blocks anything.
- **Message size limits (changes section 4.4):** `user` messages: 4,000 characters in the app, 20,000 in the rules (unchanged). `model` messages: up to 100,000 characters in the rules, and set a maximum output length on the model.
- **Privacy rule (changes section 4.7):** never put the user's email or account details into prompts. Text the user typed into custom instructions or memories may be included, because the user chose to share it.
- **App Check enforcement (Phase 4):** include the console step to turn on App Check enforcement for Firebase AI Logic (and Firestore); without it the "remove the debug token" check proves nothing.
- **Artifact versions (Phase 10):** add a Firestore collection for artifact versions, with owner-only rules and size limits, to the data model and `firestore.rules` in that phase.
- **Google Search grounding moves to Phase 13 (changes Phase 11):** checked on the Gemini API pricing page on 2026-11-03: for `gemini-3.5-flash-lite`, "Grounding with Google Search" is **not available on the free tier** (paid tier: 5,000 free requests/month shared across Gemini 3+ models, then $14 per 1,000; needs Blaze). Phase 11 is done with the read-only tools only (`get_current_date_time`, `search_my_chats`). The "today's news with sources" done check, the Google Search Suggestions display (Google-provided HTML; planned in a sandboxed frame) and source links move to Phase 13. No other search service: it would need an API key in the app (rule 1) or a backend (Blaze).
- **Link reading added, web search still Phase 13 (2026-11-04):** the only free-tier models with Google Search grounding are `gemini-2.5-flash` / `gemini-2.5-flash-lite` (500 RPD shared). Tested via Remote Config: the API answers "This model models/gemini-2.5-flash-lite is no longer available to new users", so no free search model exists for this project. Built instead: the URL context tool (free on `gemini-3.5-flash-lite`, Public Preview). A message containing links is sent with `Tool.urlContext()` only, because URL context can't be combined with function calling; other messages keep the date and chat-search tools. Pages that fail (error, paywall, unsafe) get an app-added note asking the user to paste the text. Agreed for when search is built: search toggle, `ai_search_model` in Remote Config, Google's suggestions HTML in a sandboxed frame (web only; toggle hidden on Android), and sources plus suggestions saved with the message (size-limited in the rules).
- **News mode (2026-11-04), free alternative to web search:** no button: news questions are detected automatically (news words like "news", "headlines", "current events", "what's happening in the world", or a follow-up to a news answer). Such a message is sent with URL context plus Wikipedia's `Portal:Current_events` page (CC BY-SA, updated daily) and today's device date in the instructions; only the user's text is saved. The app adds a credited source link, or a "may not be current" warning if the page wasn't read. The owner's test: the Wikipedia page worked; the BBC RSS feed failed with a network error, so it isn't used (feeds are also usually personal-use only). Not a real search: it only covers that page.
- **Crashlytics deferred (changes Phase 12):** `firebase_crashlytics` supports Android, iOS and macOS only, not web (checked 2026-11-03, v6.0.1). Add and test it with the first Android build, after the SDK path is fixed.
- **Testers use Firebase Hosting (changes Phase 12):** App Distribution shares only Android/iOS apps, so web testers get the release web build on Firebase Hosting (free on Spark). App Distribution steps are kept for later Android builds.
- **Publishing skipped for now (2026-11-03):** the owner chose not to set up reCAPTCHA or publish to Hosting. The code for Phase 12 is done; the release script and `docs/RELEASE.md` are ready if they change their mind. The "testers for a week" check is not done.
- **Free-tier data use:** the same pricing page says free-tier Gemini API content is "Used to improve our products". Keep the input-box warning, and mention this in the Phase 12 privacy note.
- **Git (changes section 7, step 5):** don't suggest commit messages or mention commits in phase reports. Commit only when the owner asks.
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

# UI/UX improvements (from the UI/UX review)

Work in three rounds. Do ROUND 1 ONLY, then stop and report. I will test it and tell you when to start the next round.

Before writing code for a round:
1. List exactly what you will build and what you won't.
2. List every Firestore rules change you need and explain why in plain words.
3. Ask me about anything unclear.
Don't add features I didn't list. Keep all existing security rules from CLAUDE.md.

---

## ROUND 1: High priority

### 1. Meaningful chat titles and search
- After the FIRST answer in a new chat, ask the model for a 3–6 word title (no quotes, no full stop) and save it as the conversation title. Use the same AiService and model. If title generation fails, keep the current title; never show an error for this.
- Don't show conversations that have no model answer in the chat list.
- Add a search box above "Chats" that filters the loaded chat titles as I type (titles only, no full-text search of messages).
- Done when: a new chat about economics gets a title like "Bhutan's DHI economy overview", and typing "econ" in search shows it.
- Not included: renaming existing old chats, searching message text.

### 2. Labels for every icon button
- Give every icon-only button a tooltip and a screen-reader label: copy, bookmark, attach, send, stop, settings, sign out, new chat, and every "…" menu.
- Use clear labels such as "Copy answer", "Attach image or PDF", "Send message", "Stop answering".
- Done when: hovering on desktop shows each label, and TalkBack reads each button's purpose instead of just "button".

### 3. Bookmarks with a clear purpose
- Keep bookmarking, but make its purpose clear: it saves a message to a "Saved" list.
- Show the bookmark only under Nova's answers, in the same place as copy, not under my own messages.
- When tapped: fill the icon and show a short "Saved" message.
- Add a "Saved" entry in the sidebar that lists saved answers; tapping one opens its chat at that message.
- Store saved items under users/{uid}/saved/{id} with owner-only rules and a size limit.
- Done when: I can save an answer, find it in Saved, open it, and remove it.

### 4. Set expectations about links and files
- If the URL context feature is not built yet, show a small hint in the input area when the text contains a link: "Nova can't open links yet. Paste the page text instead."
- On the attach button tooltip, list supported files: "Images and PDFs, up to [current limit]".
- Done when: pasting a link shows the hint before sending.

---

## ROUND 2: Medium priority (wait for my go-ahead)

### 5. Project chats grouped clearly
- In the sidebar, show each project's chats inside that project (expandable), not mixed into the main list.
- Chats without a project stay under "Chats".
- Done when: a chat created inside a project appears only under that project.

### 6. Top bar on desktop
- Add a slim top bar above the conversation with the chat title and a "…" menu: Rename, Move to project, Delete.
- Delete asks for confirmation, or offers Undo for 5 seconds.
- Done when: I can rename and delete the open chat from the top bar.

### 7. Contrast check
- Check the contrast of all grey text and icons (placeholder, disclaimer, section labels, disabled Send) against their backgrounds in both light and dark themes.
- Text must be at least 4.5:1; icons and borders at least 3:1. Adjust the theme colours in ThemeData only, not per widget.
- Report each colour pair with its ratio before and after.

### 8. Regenerate, edit and feedback
- Under the LATEST answer: Regenerate (sends the last question again and replaces the answer).
- On my LATEST message: Edit (puts the text back in the input box; sending replaces that message and the answer after it).
- Under every answer: thumbs up / thumbs down, saved under users/{uid}/feedback/{id} with owner-only rules.
- The current rules forbid updating or deleting messages. Propose the smallest safe rules change (for example, allowing the owner to delete only their own latest messages), explain it to me, and wait for my approval before changing the rules.
- Done when: regenerate, edit and feedback all work, and the Rules Playground still blocks other users.

---

## ROUND 3: Low priority (wait for my go-ahead)

### 9. Less clutter in the chat list
- On desktop, show each row's "…" only on hover or when the row is selected. On phones, open the same menu with a long-press.

### 10. Account area
- Show the user's display name (or the part of the email before @) next to the avatar, with the full email in a tooltip.

### 11. Readable answer width
- Cap the chat column, including the input box, at about 720 px on wide screens, centred.

### 12. Input box on phones
- Start the input as a single line and grow up to about 6 lines as I type, then scroll inside.

---

## Report after each round
- What was built, in plain words
- Rules changes made, and why
- Manual steps for me (Firebase console, if any)
- How to test each item, including on phone width and with TalkBack
- A suggested Git commit message

# Nova UI redesign: the "Studio" style

Paste this whole prompt into the agent once. Attach screenshots of the Studio designs (chat, new chat, sign in, phone) so you can see the target look.

Work in SIX rounds. Do ROUND 1 ONLY, then stop and report. I'll test each round before telling you to start the next.

Before writing code in each round:
1. List exactly which files you will create or change, and what you won't touch.
2. Check the current docs for any package you add (`google_fonts`, `flutter_svg`, an icon package).
3. Ask me about anything unclear.

## Ground rules (every round)

- This is a **visual redesign only**. Don't change business logic, Firestore data, security rules, the AI service, or how features work.
- **No colours, font sizes or radii hard-coded in widgets.** Everything comes from the theme (`ThemeData` plus a `ThemeExtension` for Nova's extra colours) and one `nova_tokens.dart` file of spacing, radii and sizes.
- Build **reusable widgets** (for example `NovaButton`, `NovaIconButton`, `NovaCard`, `NovaChip`, `NovaComposer`) instead of styling each screen separately.
- Keep every existing tooltip, `Semantics` label and accessibility feature. Every icon-only button needs a tooltip.
- Touch targets are at least **44 × 44**.
- Text contrast is at least **4.5:1** (3:1 for text 24 px and larger). The colours below were chosen to pass; check any new colour you add.
- **Dark theme only** for now.
- If a design shows a feature that doesn't exist in the app yet (for example Saved answers, Regenerate, thumbs up/down, the project picker in the composer), **don't build it in this redesign**. Leave it out and list it in your report.
- Don't use emoji as icons, and don't add gradients or drop shadows that aren't in the design.

---

## The Studio design system

### Colours

| Token | Hex | Used for |
| --- | --- | --- |
| `background` | `#121214` | The app background behind the panels |
| `panel` | `#1E1E22` | Sidebar panel, sign-in left panel, sign-in fields |
| `mainPanel` | `#18181B` | The main chat panel |
| `card` | `#222226` | Nova's answer cards, suggestion cards |
| `cardRaised` | `#2B2B30` | Tiles and inline code inside cards |
| `input` | `#26262B` | The composer background |
| `control` | `#28282D` | Round icon buttons in the sidebar and top bar |
| `controlStrong` | `#34343A` | Attach button, disabled Send button, input border, dividers |
| `outline` | `#3A3A40` | Outlined chips, dashed "Saved" row |
| `fieldOutline` | `#45454C` | Text-field borders at rest |
| `selectedRow` | `#2E2E33` | The selected chat in the sidebar |
| `textPrimary` | `#F4F1EA` | Headings and main text |
| `textBody` | `#E6E2D9` | Text inside answer cards |
| `textSecondary` | `#CFCBC2` | Secondary text, sidebar rows |
| `textMuted` | `#A8A49B` | Labels, placeholders, the disclaimer |
| `accent` | `#D4F25C` | Primary buttons, user bubbles, Send/Stop, the logo, focus outlines |
| `onAccent` | `#121214` | Text and icons on the accent colour |
| `accentHover` | `#E6FA9A` | Links on hover, accent hover state |
| `projectOrange` | `#F2A65A` | Project colour dot; its tile background `#2A2620`, its label text `#F2C391` |
| `projectTeal` | `#6FD3B8` | Project colour dot; its tile background `#1F2A27` |
| `accentTile` | `#262A1C` | Tile background behind an accent-coloured icon |
| `error` | choose one | Pick a soft red that passes 4.5:1 on `mainPanel`; tell me which |

### Fonts (via the `google_fonts` package)

- **Space Grotesk** (500, 600, 700): the logo word "nova", headings, chat titles, card titles, section labels.
- **DM Sans** (400, 500, 600): all body text, buttons, inputs.
- **DM Mono** (400): inline code and code blocks.

### Type scale

| Style | Font | Size / weight | Used for |
| --- | --- | --- | --- |
| Display | Space Grotesk | 46–60, 600, tight letter spacing (−0.035em) | New-chat greeting, sign-in headline |
| Headline | Space Grotesk | 34, 600 | Sign-in "Welcome back" |
| Title | Space Grotesk | 20, 600 | Chat title in the top bar |
| Logo | Space Grotesk | 21, 700, lowercase "nova" | Sidebar logo word |
| Card title | Space Grotesk | 15, 600 | Suggestion and project card titles |
| Section label | Space Grotesk | 12, 600, UPPERCASE, letter spacing 0.1em, `textMuted` | "PROJECTS", "RECENT" |
| Body | DM Sans | 15–16, 400, line height 1.7 | Answers and messages |
| Row | DM Sans | 14, 400 (600 when selected) | Sidebar chat rows |
| Small | DM Sans | 13, 500 | Chips, card descriptions |
| Caption | DM Sans | 12 | Disclaimer, email under the name |

### Shape and spacing

- **Radii:** panels and answer cards 22; user bubbles 22 with the bottom-right corner 6; suggestion cards 20; buttons, project tiles and the empty-screen composer 16–26; sidebar rows and text fields 14; chips, round buttons and the chat composer fully round (999).
- **Spacing scale:** 4, 8, 12, 16, 24, 32. The app has a 12 px outer padding and 12 px gaps between panels.
- **Sizes:** sidebar 288 wide; chat column max 740 wide, centred; primary buttons 48 tall (52 on sign-in); icon buttons 44; icons 17–20 px, outline style with a stroke of about 1.8, all from ONE icon set (suggest one, for example a Lucide icon package).

### The logo

Replace the sparkle with Nova's new mark: a lime circle with a dark ring and a small "moon" dot. Use it as an SVG with `flutter_svg`, at 32 px in the sidebar, 22–24 px next to answers, and 44 px on the new-chat screen.

```svg
<svg width="28" height="28" viewBox="0 0 28 28" xmlns="http://www.w3.org/2000/svg">
  <circle cx="14" cy="14" r="14" fill="#D4F25C"/>
  <circle cx="13" cy="15" r="6" fill="none" stroke="#121214" stroke-width="2.4"/>
  <circle cx="20.5" cy="7.5" r="2.6" fill="#121214"/>
</svg>
```

---

## ROUND 1: Foundations

- Add the fonts, colours (`ThemeData` + `ThemeExtension`), type scale and `nova_tokens.dart`.
- Add the logo asset and a `NovaLogo` widget.
- Build the base widgets: `NovaButton` (primary lime / secondary outlined), `NovaIconButton` (44 px, round or rounded square), `NovaCard`, `NovaChip`.
- Apply the new theme app-wide, without changing layouts yet.
- **Done when:** the app runs with the new colours, fonts and logo everywhere, and no screen has hard-coded colours left.

## ROUND 2: App shell and sidebar

- Floating rounded panels on `background`: the sidebar (`panel`) and the main area (`mainPanel`), 12 px apart.
- Sidebar, top to bottom: logo + "nova" + collapse button; a lime **New chat** button with a square search button beside it; "PROJECTS" as a two-column grid of coloured tiles (colour square + name); "RECENT" chat rows (selected row uses `selectedRow` with a small lime dot on the right); account row at the bottom (rounded-square avatar in the project orange, name, email, settings button).
- Top bar in the main panel: chat title (Title style), a project pill (tile background with the project's label colour), Share and options buttons as `control` round-cornered buttons.
- **Phone (under 600 wide):** no sidebar; a top bar with a menu button (opens the sidebar as a drawer), the chat title with the project name under it in small text, and a lime round New chat button.
- **Done when:** the shell matches the design on desktop and phone width, and the drawer opens on phones.

## ROUND 3: Chat screen

- **User messages:** lime bubbles (`accent`) with `onAccent` text, weight 500, right-aligned, max 78% wide, radius 22 except the bottom-right corner at 6.
- **Nova's answers:** inside a `card` (radius 22, padding about 22/24), with the small logo and "Nova" in Space Grotesk at the top, Markdown body text in `textBody`, and inline code on `cardRaised` in DM Mono.
- **Action row** under each answer: muted 44 px icon buttons for the actions that already exist.
- **While Nova is thinking:** three lime typing dots in a small card. While streaming, show a small lime block cursor at the end of the text.
- **Composer:** a fully round pill on `input` with a `controlStrong` border, containing a round attach button (`controlStrong`), the text field (placeholder "Ask Nova anything…"), the existing web-search toggle as an outlined pill with a globe icon (an icon-only button on phones), and a lime round Send button that becomes Stop while answering. Send is `controlStrong` with a muted icon when the field is empty. The field starts as one line and grows up to about 6 lines.
- Disclaimer under the composer in Caption style: "Nova can make mistakes. Don't share private information."
- **Done when:** a full conversation matches the design, including streaming, Stop, and the phone layout.

## ROUND 4: New-chat screen

- Centred in the main panel: the 44 px logo, the greeting "Good evening, [first name]" in Display style (morning, afternoon or evening by the device's time; use the display name, or the part of the email before @), and "What are we working on today?" in `textSecondary`.
- A larger composer card (radius 26, two lines tall) with attach, the web-search pill, and Send in the bottom row.
- Below it, three suggestion cards in a row (one column on phones): an icon on a tinted square, a card title, and a one-line prompt. Use the app's existing suggestions with titles such as "Explain a topic", "Plan my week" and "Read a file". Tapping a card fills the composer and sends, as the current suggestions do.
- **Done when:** the empty state matches the design on desktop and phone.

## ROUND 5: Sign in and Create account

- **Desktop:** two panels. Left (`panel`): logo at the top; the headline "Think out loud." with "Learn faster." on a second line in the accent colour; a short description; three feature tiles at the bottom (Projects, Memory, Files). Right: the form.
- **Form:** "Welcome back" (Headline) and "Sign in to continue your chats."; labels ABOVE the fields (not inside); fields 52 tall on `panel` with a `fieldOutline` border that becomes a 2 px accent border when focused; "Forgot password?" aligned right on the Password label row; show/hide password on BOTH password fields; a lime full-width Sign in button; an "or" divider; an outlined "Create an account" button; the Privacy notice as a small line under the form.
- Create account uses the same layout, with Confirm password and the title "Create your account".
- Error messages appear under the related field in the error colour, with text, not colour alone.
- **Phone:** only the form, with the logo above it.
- **Done when:** both screens match the design and all existing sign-in flows still work.

## ROUND 6: Polish and checks

- Hover, pressed and focus states on every button, row and card (a slightly lighter surface on hover; a visible accent focus ring for keyboard users).
- Short animations of 150–250 ms: messages fading or sliding in, the drawer, the Send/Stop swap. Respect the device's reduce-motion setting.
- Check all screens at the largest text size and with TalkBack on.
- List every colour pair you checked, with its contrast ratio.
- **Done when:** nothing overflows at large text, every control is announced correctly, and every pair passes contrast.

---

## Report after each round

- What changed, in plain words, with a screenshot if you can
- Files created and changed
- Any design detail you couldn't match, and why
- Features in the design that don't exist yet and were left out
- How to test it on desktop width and phone width
- A suggested Git commit message


splash screen and onboarding screen
# Splash screen and onboarding (Studio style)

Paste this whole prompt into the agent once, and attach screenshots of the five designs: Splash, Onboarding 1, 2 and 3 (phone) and Onboarding on desktop. Before Round B, put the three onboarding images in `assets/onboarding/` with the file names below.

Work in TWO rounds. Do ROUND A ONLY, then stop and report.

Before writing code in each round:
1. List the files you will create or change, and what you won't touch.
2. Check the current docs for any package you add (for example `flutter_native_splash`, `shared_preferences`).
3. Ask me about anything unclear.

## Ground rules

- Use the Studio theme, tokens and Nova widgets from the redesign. No hard-coded colours, sizes or radii.
- Don't change Firestore data, security rules or the AI service. Onboarding progress is stored **on the device only**.
- Touch targets at least 44 × 44, text contrast at least 4.5:1, and labels for every icon-only button.
- Respect the device's reduce-motion setting: no animation, just show the final state.
- The onboarding illustrations are three image files I'll give you: `assets/onboarding/meet_nova.jpg`, `assets/onboarding/projects_memory.jpg` and `assets/onboarding/files_links.jpg`. They are decoration, so give them no screen-reader label (`ExcludeSemantics`); the heading and text carry the meaning. Compress them for size and precache them so they appear instantly.

## The app start flow

1. **Native splash** (shown by the system while Flutter loads): background `#121214` with the Nova logo in the centre. Set this up with `flutter_native_splash`, including the Android 12+ settings, and on web too.
2. **Flutter splash** (shown while Firebase starts and the sign-in state is checked): the design's screen. Keep it on screen only as long as that work takes, plus a short fade of about 300 ms. **No artificial waiting.**
3. Then route:
   - Signed in → the chat screen
   - Signed out and onboarding not seen yet → onboarding
   - Signed out and onboarding already seen → sign in
4. Save `onboardingSeen = true` in `shared_preferences` when the user taps Skip, Create an account or I already have an account.
5. Add **"Show welcome tour"** in Settings, which opens onboarding again.

## ROUND A: Splash screen, its animation, and routing

**Design (phone and desktop, centred):**
- On the `background` colour: a 220 px decoration of two faint orbit rings (an outer solid ring in `card`, an inner dashed ring in `cardRaised`) with two small dots in the project orange and teal, and the Nova logo (about 96 px) in the middle.
- "nova" below it in Space Grotesk 44, weight 700, tight letter spacing.
- "Think out loud." in DM Sans 15, `textSecondary`.
- At the bottom, three lime loading dots. Screen-reader label: "Loading".

**The animation** (built with Flutter's own `AnimationController`s, `CustomPainter` and `Hero`; no Lottie or Rive). It should feel like a small solar system waking up: smooth, confident and short.

| Time | What happens | Curve |
| --- | --- | --- |
| 0 ms | The first frame looks exactly like the native splash (same logo, size and position), so the hand-over is invisible. | — |
| 0–450 ms | The logo grows from 85% to 100% with a tiny overshoot. | `easeOutBack` |
| 100–700 ms | The moon dot inside the logo makes one full orbit around the ring and settles in its top-right spot. | `easeInOutCubic` |
| 150–850 ms | The outer orbit ring draws itself in a full circle, starting from the top. | `easeOutCubic` |
| 300–900 ms | The dashed inner ring fades in, then keeps rotating very slowly (one turn every 20 s) while loading continues. | linear |
| 400–900 ms | The orange and teal dots fade in on the rings, then keep orbiting slowly at different speeds. | `easeOut` |
| 500–900 ms | The letters of "nova" rise 8 px and fade in one by one, 40 ms apart. | `easeOutCubic` |
| 800–1,100 ms | "Think out loud." fades in. | `easeOut` |
| After 1,100 ms | Only if loading is still going: the three loading dots fade in and pulse in a gentle wave. | `easeInOut` |
| Exit | When loading is done and the intro has finished, the logo flies to its place on the next screen (a `Hero` with the tag `nova-logo`: the sidebar logo, the onboarding logo or the sign-in logo), while the rest fades out over 300 ms and the next screen fades in. | `easeInOutCubic` |

Rules for the animation:
- **First launch:** let the intro play to the end (about 1.1 s), even if loading finishes sooner. **Later launches:** start at the final frame, skip the intro, and leave as soon as loading is done.
- Never hold the splash longer than needed: if loading takes longer than the intro, show the loading dots; never add a fixed delay.
- **Reduce motion on:** show the final frame immediately, with no orbiting or rising, and use a simple 200 ms cross-fade to exit.
- Keep it smooth at 60 fps on a mid-range phone: wrap the painted rings in a `RepaintBoundary`, use one controller for the intro, and stop the looping animations when the splash leaves the screen.

**Done when:** the native splash shows on Android and web, the hand-over to the Flutter splash is seamless, the intro plays smoothly, the logo flies into the next screen, reduce motion is respected, and each of the three routes works (test with a fresh install, after Skip, and signed in).

## ROUND B: Onboarding (wait for my go-ahead)

**Layout on phones (under 900 px wide):**
- **Hero image:** fills the full width of the top part of the screen (about 60% of the height on step 1 and 2, a little less on step 3), `BoxFit.cover`, with a soft fade at its bottom edge into the `background` colour so the image melts into the page.
- **Over the image:** the small Nova logo and "nova" at the top left on step 1; a round-cornered Back button (semi-transparent `panel`) at the top left on steps 2 and 3. Make sure it stays readable over the image.
- **Under the image:** the step dots (the current step is a 24 × 8 lime pill; the others are 8 × 8 dots in `fieldOutline`; screen-reader label "Step 1 of 3"), then the heading in Space Grotesk 34, weight 600, with the last words in the accent colour, then the text in DM Sans 16, `textSecondary`.
- **Bottom row (steps 1 and 2):** "Skip ›" as a quiet text button on the left, and a lime pill **Next →** button (52 tall) on the right.
- Swiping left and right also moves between steps (`PageView`), and the image changes with the page.

**Layout on desktop (900 px and up):** two panels. On the left, `files_links.jpg` (the books image) filling a large rounded panel (`BoxFit.cover`, radius 22) on **all three steps**; only the right side changes between steps. On the right, the logo and a Skip pill at the top, then the step dots, a Display-size heading (56) and the text, and at the bottom right a lime pill **Next →** button.

**The three steps:**

1. **Meet Nova**
   - Image: `meet_nova.jpg` (a lime planet with an orbit ring and a small moon)
   - Heading: "Meet Nova, your **study partner**"
   - Text: "Ask anything and watch clear answers write themselves as you read."
   - Buttons: Skip, Next

2. **Projects and memory**
   - Image: `projects_memory.jpg` (a tower of colourful folders with a glowing lightbulb)
   - Heading: "Stay organised, **your way**"
   - Text: "Group chats into projects, and choose what Nova remembers. You can see or delete it any time."
   - Buttons: Skip, Next

3. **Files and links**
   - Image: `files_links.jpg` (documents, a notebook and a magnifying glass)
   - Heading: "Bring your **notes along**"
   - Text: "Attach a photo or PDF, or paste a link, and Nova reads it with you."
   - Buttons: a full-width lime pill **Create an account**, and a full-width outlined pill **I already have an account** (border `#75757D`).
   - A small centred line under the buttons: "Nova can make mistakes. Don't share private information." with a link to the Privacy notice.

**Motion (only if reduce motion is off):** the page slides between steps; the step-dot pill stretches to the new step; the image gently zooms from 1.04 to 1.0 and the heading and text fade up slightly (about 250 ms) when a step appears.

**Done when:** all three steps match the designs on phone and desktop, Skip and both final buttons go to the right screen and save `onboardingSeen`, "Show welcome tour" in Settings replays it, and everything works with TalkBack and the largest text size.

---

## Report after each round

- What changed, in plain words, with a screenshot if you can
- Files created and changed
- Packages added, and why
- Anything you couldn't match, and why
- How to test each route and step
- A suggested Git commit message