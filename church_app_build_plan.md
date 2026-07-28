# Church App — Phased Build Plan

**Stack:** Flutter, targeting **web first, Android later** (same codebase, no framework switch — Flutter compiles to both) + **hybrid backend**: Firebase (Auth, Firestore, Hosting, FCM — free Spark plan, no card required) for identity/data/delivery, plus a **self-hosted Node server on a Raspberry Pi** (behind Cloudflare Tunnel) replacing Cloud Functions and Cloud Storage, so no payment info is required anywhere.
**Scope:** v1 test build for a single cell group / building. Multi-church, badges, poke/verse, and full moderation tooling are explicitly out of scope for this plan. Android is deferred to Phase 8, after the web version has been tested with the group.

Each phase below is written as a task list an implementation agent can execute independently, with inputs, outputs, and a definition of done. Phases are ordered by dependency — do not start a phase until the previous phase's DoD is met.

---

##Setup Checklist

**Before Phase 0:**
- [ ] Install Flutter SDK; confirm `flutter doctor` is clean; confirm web support is enabled (`flutter config --enable-web` if needed) and a Chrome-based browser is available for local testing. (Android Studio/Xcode not needed yet — deferred to Phase 8.)
- [ ] Create the Firebase project in the console.
- [ ] Enable Authentication, Cloud Firestore, Cloud Messaging, and **Hosting** for the project. Do **not** enable Cloud Functions or Cloud Storage — those are replaced by the Pi server below, which avoids the Blaze (card-on-file) requirement entirely. Firebase stays on the free Spark plan for this whole project.
- [ ] Set up the Raspberry Pi: flash an OS (Raspberry Pi OS Lite is enough, no desktop needed), install Node.js (LTS), confirm it's reachable on your local network via SSH.
- [ ] Install `cloudflared` on the Pi and create a Cloudflare Tunnel (free, no card) pointing at the Pi — this gives the Pi a stable public HTTPS URL without opening router ports or exposing your home IP.
- [ ] In the Firebase console, generate a service account key (Project Settings → Service Accounts → Generate new private key) and copy the JSON file onto the Pi only — never commit it to source control, never send it to the Flutter client.

**Before Phase 0.5 (Pi Server Scaffolding):**
- [ ] None beyond the above — this phase is fully agent-codeable once the Pi is reachable via SSH and the tunnel is live.

**Before Phase 1 (Auth):**
- [ ] Enable Google as a sign-in provider in Firebase Auth; configure the OAuth consent screen.
- [ ] Register a **Web app** in the Firebase console (not Android/iOS yet) to get the web SDK config (apiKey, authDomain, etc.) — this is pasted into Flutter web config, no file download needed the way `google-services.json` works for native.
- [ ] Add your local dev domain (e.g. `localhost`) and eventual Hosting domain to the OAuth "Authorized domains" list in Firebase Auth settings, or Google Sign-In will fail on web with a domain-mismatch error.

**Before Phase 2 (Schema + Rules):**
- [ ] None — this phase is fully agent-codeable once Phase 0/1 config is in place.

**Before Phase 3 (Core Loop):**
- [ ] Decide the fish reward constant per completion (e.g. 10 fish) and the group-fund contribution % (e.g. 10%). These are game-balance judgment calls, not something an agent should invent.
- [ ] Draft or approve the role-specific completion messages (5 roles), or explicitly delegate first-draft copy to the agent with a tone reference (e.g. "Walking Charlie-style, warm, short").

**Before Phase 4 (Neighbourhood):**
- [ ] Decide the completion-percentage time window (daily rolling vs. weekly) — affects the aggregation function's logic.
- [ ] Produce or source avatar/role art assets (even placeholders) so the member list has something to render.

**Before Phase 5 (Store):**
- [ ] Decide the starter item catalog (names, categories, costs) — or delegate a first draft to the agent and review it yourself.
- [ ] Produce or source item art assets (headpiece/shirt/pants/companion icons).
- [ ] Decide the group fund expansion threshold(s) (e.g. "playground unlocks at 500").

**Before Phase 6 (Bulletin):**
- [ ] Decide whether any lightweight moderation is needed even for a trusted small group (e.g. a report button), or explicitly defer it.

**Before Phase 7 (AI Daily Challenge):**
- [ ] Get an Anthropic (or other LLM provider) API key.
- [ ] Store it as an environment variable on the Pi (e.g. a `.env` file loaded via `dotenv`, excluded from git via `.gitignore`) — never committed to source or handed to the client app.
- [ ] Decide whether generated challenges need manual approval before publishing, and if so, who approves them.

**Before Phase 8 (Android transition, later):**
- [ ] Install Android Studio; set up an emulator or physical Android test device.
- [ ] Register an **Android app** in the same Firebase project (package name) to get `google-services.json`.
- [ ] Generate SHA-1/SHA-256 fingerprints and add them in the Firebase console for Google Sign-In to work natively on Android.
- [ ] Download `google-services.json` and place it in the project — an agent can wire up code that reads it, but cannot generate it.

**Only needed if you go beyond your own cell group:**
- [ ] Apple Developer Program enrollment (paid) — required for TestFlight/App Store distribution.
- [ ] Google Play Developer account (one-time fee) — required for Play Store distribution.
- [ ] Recruiting testers and collecting feedback — inherently not agent-codeable.

---

## Phase 0 — Project Scaffolding

**Goal:** Empty but running Flutter app wired to a Firebase project.

Tasks:
- [ ] Create Firebase project; enable Authentication, Cloud Firestore, Cloud Messaging, Hosting. (Not Cloud Functions or Storage — see Phase 0.5.)
- [ ] Initialize Flutter project with web target enabled; add `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging`, `google_sign_in` packages (confirm each has web support — `firebase_messaging` in particular works differently on web, via a service worker, and can be stubbed out until Phase 7/8 if it adds friction). No `firebase_storage` needed — file handling goes through the Pi server.
- [ ] Enable Google as a sign-in provider in Firebase Auth console; configure the OAuth consent screen and the Authorized Domains list for web sign-in (native SHA-1/URL-scheme setup is deferred to Phase 8).
- [ ] Set up state management (recommend `riverpod` for testability and DI).
- [ ] Set up bottom navigation shell with 4 empty tab placeholders: Avatar, Neighbourhood, Tasks, Store (use a responsive layout from the start — e.g. bottom nav on narrow viewports, side rail on wide ones — since web users may be on desktop browsers, not just mobile-width windows).
- [ ] Configure `flutter_lints` and a basic CI check (analyze + test) if a repo/CI is available.
- [ ] Do a first deploy to Firebase Hosting (`flutter build web` + `firebase deploy --only hosting`) to confirm the pipeline works end-to-end early, before real features are built on top of it.

**Definition of done:** App runs in a browser (locally and via a deployed Firebase Hosting URL), shows 4 navigable empty tabs, connects to Firebase (verified via a test read/write to a scratch Firestore doc).

---

## Phase 0.5 — Pi Server Scaffolding

**Goal:** A running Node server on the Pi, reachable over the internet via Cloudflare Tunnel, with Firebase ID token verification wired up — the foundation every later "Cloud Function equivalent" endpoint gets built on.

Tasks:
- [ ] Initialize a Node project on the Pi; add `express` (or `fastify`), `firebase-admin`, `dotenv`, `node-cron`.
- [ ] Initialize the Firebase Admin SDK using the service account JSON from the Manual Setup Checklist (load its path from an environment variable, never hardcode it).
- [ ] Build auth middleware: read the `Authorization: Bearer <idToken>` header on incoming requests, verify it via `admin.auth().verifyIdToken()`, attach the resulting `uid` to the request object, and reject with 401 if missing/invalid. Every endpoint built in later phases uses this middleware — none should trust a `uid` sent directly in a request body.
- [ ] Add a `GET /health` endpoint returning a simple `{ ok: true }`.
- [ ] Set up `pm2` (or a systemd service) so the Node server restarts automatically on crash or Pi reboot — without this, a power blip silently takes down goal completions/purchases until you manually notice and restart it.
- [ ] From the deployed Flutter web app (not just the Pi's local network), call `/health` with a real Firebase ID token attached and confirm a verified `uid` comes back — this validates the whole chain (Tunnel → Node → Admin SDK → token verification) before any real feature is built on it.

**Definition of done:** The deployed web app can successfully call the Pi's `/health` endpoint over the public internet with a real user's ID token, and the response confirms the correct `uid` was extracted. The Pi survives a manual reboot with the server coming back up on its own.

---

## Phase 1 — Auth, Avatar Creation, Role Selection

**Goal:** First-time user journey up to "avatar created, role chosen" works end-to-end.

Data model:
```
users/{uid}
  name: string
  role: enum [gardener, electrician, cleaner, plumber, painter]
  avatarConfig: map (headpiece, shirt, pants, companion — nullable at creation)
  buildingId: string | null
  fishBalance: int (default 0)
  createdAt: timestamp
```

Tasks:
- [ ] Implement Google Sign-In for web using Firebase Auth's `GoogleAuthProvider` with `signInWithPopup` (or `signInWithRedirect` if popup blockers are an issue for your test users). This is a different code path from the native `google_sign_in` package flow you'll add in Phase 8 — both ultimately produce the same Firebase `User`, so the rest of the app (Firestore reads/writes, `uid` usage) doesn't need to know which one ran. (Fallback: email/password, if any group members lack a Google account — only build this if the join test in Phase 1's DoD surfaces a real need.)
- [ ] On first sign-in, prefill the name field from the Google profile's `displayName` (still editable — a user's Google name may not be what they want as their in-app identity). Do not use `photoURL`; the avatar is a custom in-app character, not the Google profile photo.
- [ ] Build onboarding flow: name entry (prefilled) → role selection (5 options, static assets) → write `users/{uid}` doc.
- [ ] Add auth state listener to route: signed out → onboarding; signed in but no role → resume onboarding; signed in with role → main app shell.
- [ ] Build Avatar tab (read-only display for now): shows name, role, placeholder badge button, placeholder "My Goals" button, placeholder notifications button.

**Definition of done:** A new user can sign up, pick a name and role, and land on the Avatar tab showing their chosen role. Closing and reopening the app skips onboarding and goes straight to Avatar tab.

---

## Phase 2 — Firestore Schema + Security Rules

**Goal:** Full data model exists with security rules enforced *before* any feature reads/writes private data. This phase is rules-first by design — retrofitting privacy rules after features exist is expensive to redo.

Full collection reference:
```
users/{uid}
  name, role, avatarConfig, buildingId, fishBalance, createdAt

buildings/{buildingId}
  name: string
  inviteCode: string
  memberIds: array<uid>
  unlockedExpansions: array<string>
  groupFund: int (default 0)

goals/{goalId}
  userId: uid
  type: enum [smart, templated]
  task: string            // e.g. "read bible"
  text: string            // free text for SMART goals
  frequency: enum [daily, weekly, monthly]
  currentStreak: int
  sharedToBulletin: bool (default false)
  createdAt: timestamp

dailyChallenges/{date}         // date = "YYYY-MM-DD", one doc per day, shared by all users
  promptText: string
  source: enum [ai, manual]
  createdAt: timestamp

completions/{completionId}
  userId: uid
  refId: string            // goalId or dailyChallenges date
  refType: enum [goal, dailyChallenge]
  date: string
  fishAwarded: int
  groupFundContribution: int
  timestamp: timestamp

inventory/{uid}/items/{itemId}
  equipped: bool
  acquiredAt: timestamp

storeItems/{itemId}
  category: enum [headpiece, shirt, pants, companion]
  cost: int
  roleRestricted: string | null

bulletinPosts/{postId}
  userId: uid
  buildingId: string
  type: enum [prayer, thanksgiving, sharing]
  text: string
  reactions: map<uid, string>   // emoji reactions
  createdAt: timestamp
```

Tasks:
- [ ] Create all collections above in Firestore (can be empty/seed docs).
- [ ] Write Firestore security rules:
  - `users/{uid}`: readable by self and by members of the same `buildingId` (for role/avatar display only — not for arbitrary field access); writable only by self.
  - `goals/{goalId}`: readable and writable only by `userId == request.auth.uid`. **No exceptions.** Group members must never be able to query another user's `goals` collection directly.
  - `completions/{completionId}`: no direct client writes at all (the rule denies client `create`) — to prevent users forging fish rewards, all writes must come from the Pi server's Firebase Admin SDK, which bypasses security rules by design (admin credentials are trusted, which is exactly why the service account key must never leave the Pi); readable by self; aggregate reads (for % calculation) happen via the Pi, not a direct client query across users.
  - `bulletinPosts/{postId}`: readable by all members of the same `buildingId`; writable (create) by self; reactions updatable by any building member.
  - `buildings/{buildingId}`: readable by members; `groupFund` and `memberIds` writable only via the Pi server (Admin SDK), denied for direct client writes.
- [ ] Write a script or test suite (Firebase emulator + rules unit tests) that asserts: user A cannot read user B's `goals` doc; no client (not even the goal's own owner) can write directly to `completions`; user A cannot edit `buildings.groupFund` directly.

**Definition of done:** Firestore emulator rules tests pass, specifically covering the three assertions above. No client code needs to change in this phase — this is schema + rules only.

---

## Phase 3 — Core Loop: Templated Goals + Fish Rewards

**Goal:** A user can create a self-set goal, mark it complete, and receive fish (with a portion routed to the group fund), fully working end-to-end for a single user with no group features yet.

Tasks:
- [ ] Build "My Goals" screen: list of active goals + "add goal" flow.
- [ ] Add goal creation form for templated goals: task dropdown (read bible, pray, journal, attend church, share testimony, pray for someone, talk to someone in church) + frequency dropdown (daily, weekly, monthly). Write to `goals/{goalId}`.
- [ ] Add goal creation form for SMART goal: free text field, at least 1 required during onboarding (revisit Phase 1 onboarding to enforce this — add a step after role selection).
- [ ] Build a Pi server endpoint `POST /completeGoal` (behind the auth middleware from Phase 0.5):
  - Read `goalId` from the request body; `uid` comes from the verified token, never the body.
  - Verify the goal belongs to the calling `uid` (fetch the `goals/{goalId}` doc via Admin SDK, check `userId` matches).
  - Verify it hasn't already been completed for the current period (day/week/month per its frequency) — query `completions` for an existing entry.
  - Write a `completions` doc, increment `users/{uid}.fishBalance` by a fixed reward amount (define a constant, e.g. 10 fish), and if the user has a `buildingId`, increment `buildings/{buildingId}.groupFund` by a fixed fraction (e.g. 10% of the reward) — do all three writes inside a single Firestore transaction via the Admin SDK so a network hiccup can't leave the data half-updated.
  - Respond with the updated streak and a role-specific completion message (see message table below).
- [ ] Wire checkbox UI on Tasks tab to call `POST /completeGoal` (via the Pi's tunnel URL, attaching the user's current Firebase ID token as the Bearer header), show the returned message/animation, update local fish balance display.
- [ ] Define role-specific completion message table (5 roles × generic completion event) as a static map — this can be simple text for v1, e.g.:
  - Gardener: "You watered another seed today 🌱"
  - Electrician: "Circuit charged. Power flowing." (etc. — agent should propose full set matching Walking Charlie tone)

**Definition of done:** A single test user can add a templated goal, complete it once per period, see fish balance increase, and see the group fund increment (verifiable via Firestore console even with no UI for group fund yet).

---

## Phase 4 — Neighbourhood Tab (Single Building)

**Goal:** Users can join a building via invite code, see other members, and see live completion percentages — without ever exposing private goal content.

Tasks:
- [ ] Add "join building" flow (post-onboarding or from a settings screen): enter invite code → build a Pi server endpoint `POST /joinBuilding` that validates the code against the `buildings` collection, adds `uid` to `memberIds`, and sets `users/{uid}.buildingId` (all via Admin SDK, since `memberIds` is denied for direct client writes per Phase 2 rules).
- [ ] Build a Pi server endpoint `GET /buildingStats/:buildingId`: for each member, compute "% of goals completed" for the current period (define period — recommend daily rolling window for v1) by querying `completions` via the Admin SDK (bypassing the client-side read restriction) and return an aggregated, non-sensitive payload: `{ uid, name, avatarConfig, role, completionPercent }`. No goal text ever leaves this endpoint.
- [ ] Call this endpoint on-demand from the Neighbourhood tab with a loading state (simplest option for a single test group — a scheduled refresh via `node-cron` writing to a cached Firestore doc is a reasonable upgrade later if on-demand calls feel slow).
- [ ] Build Neighbourhood tab: list of buildings the user belongs to (v1: just one) → tap to view building detail screen showing member list with avatar, role, and completion %.
- [ ] Add bulletin button on building detail screen (navigates to Phase 6 bulletin screen; can be a stub until Phase 6).

**Definition of done:** Two test accounts join the same building via invite code, both complete goals, and each can see the other's role/avatar/completion % on the Neighbourhood tab — but neither can access the other's goal text through the UI or a direct Firestore query.

---

## Phase 5 — Store + Fitting Room

**Goal:** Users can spend individual fish on cosmetic items; group fund separately tracked for future expansion-unlocking (expansion *use* can be a stub in v1).

Tasks:
- [ ] Seed `storeItems` collection with a small starter catalog (2–3 items per category: headpiece, shirt, pants, companion). Bundle the actual art assets inside the Flutter app itself (they're fixed, developer-provided images, not user uploads) — this avoids needing Cloud Storage or a Pi file-serving endpoint for v1 entirely.
- [ ] Build Store tab: grid of items with cost, filtered/highlighted by role restriction if any.
- [ ] Build a Pi server endpoint `POST /purchaseItem`: a Firestore transaction (via Admin SDK) that checks `fishBalance >= cost`, decrements balance, writes `inventory/{uid}/items/{itemId}`. Reject if already owned.
- [ ] Build Fitting Room screen: shows owned inventory, lets user equip/unequip per category (only one item equipped per category at a time), updates `users/{uid}.avatarConfig`.
- [ ] Reflect equipped items back on the Avatar tab display.
- [ ] Stub a "Group Fund" display on the building detail screen (read-only progress bar toward next expansion threshold — actual expansion-unlock logic can be a fixed placeholder like "unlocks at 500").

*(Note: if you later want user-uploaded images — e.g. a testimony photo — that's the point where the Pi needs a file-upload endpoint, using something like `multer` to save to disk and serve back over the tunnel. Not needed for v1's fixed catalog.)*

**Definition of done:** A test user with sufficient fish balance can purchase an item, see it appear in the fitting room, equip it, and see it reflected on their Avatar tab.

---

## Phase 6 — Bulletin Board

**Goal:** Building members can post prayer requests, thanksgiving, or sharings, and react to each other's posts.

Tasks:
- [ ] Build bulletin screen (reached from Neighbourhood building detail): list of `bulletinPosts` for the current `buildingId`, most recent first.
- [ ] Build "new post" flow: type selector (prayer/thanksgiving/sharing) + text field → write to `bulletinPosts`.
- [ ] Add a "share this goal" option from the My Goals screen: if `sharedToBulletin` is toggled true on a goal, create a corresponding `bulletinPosts` doc of type `sharing` (keep the underlying `goals` doc still private — this is a copy, not a reference, so later edits to the private goal don't retroactively change what was shared).
- [ ] Add reaction UI: tap an emoji → write to `bulletinPosts/{postId}.reactions[uid]`.

**Definition of done:** Two test accounts in the same building can each post to the bulletin, see each other's posts, and react to them. A user with a private goal can choose to share it and it appears as a bulletin post without exposing the original goal doc.

---

## Phase 7 — AI Daily Challenge

**Goal:** One shared, AI-generated daily challenge appears for all users and can be completed for a reward, same as a templated goal.

Tasks:
- [ ] On the Pi server, add a `node-cron` job scheduled to run once daily (e.g. midnight local time):
  - Call an LLM API with a fixed system prompt oriented around reflection prompts (e.g. "what stood out from today's reading") and church-appropriate tone.
  - Write result to `dailyChallenges/{date}` via the Admin SDK.
  - (Optional for v1, recommended given church content sensitivity) Write to a `pendingChallenges` doc instead and require a manual approval tap in an admin view before it publishes to `dailyChallenges`.
  - Since this runs as a cron job on a Pi that could be mid-reboot at the scheduled time, add a simple startup check: on server boot, if today's `dailyChallenges/{date}` doc doesn't exist yet, generate it immediately rather than waiting for the next scheduled run.
- [ ] Extend the `POST /completeGoal` Pi endpoint (or add a sibling `POST /completeDailyChallenge`) to handle `dailyChallenges` completions the same way: fish reward, group fund contribution, `completions` doc, role-specific message.
- [ ] Add the daily challenge as a card at the top of the Tasks tab, above the self-set goals list.

**Definition of done:** A challenge appears automatically each day without manual intervention (or with a one-tap approval if you chose the moderation option), and completing it awards fish the same way a templated goal does.

---

## Phase 8 — Android Transition (after web version is tested with the group)

**Goal:** Same app, same Firebase backend, running natively on Android — no backend changes, only client-side platform additions.

Tasks:
- [ ] Register an Android app in the existing Firebase project; add `google-services.json` per the Manual Setup Checklist above.
- [ ] Add native `google_sign_in` package flow alongside (not replacing) the web `signInWithPopup` flow — branch on `kIsWeb` to choose which sign-in path runs, both write to the same `users/{uid}` shape.
- [ ] Re-test responsive layout decisions made in Phase 0 against actual Android screen sizes; adjust the bottom-nav/side-rail breakpoint if needed.
- [ ] Verify `firebase_messaging` push notifications work natively (this is where FCM behaves most differently from its web/service-worker equivalent) — request notification permission, confirm token registration.
- [ ] Confirm the Android app can reach the Pi's Cloudflare Tunnel URL from a cellular network, not just the same WiFi as the Pi — this should already work since the tunnel gives a public HTTPS endpoint, but is worth verifying explicitly since it's a new network path.
- [ ] Run through every phase's Definition of Done again on a physical or emulated Android device.

**Definition of done:** The same test users who used the web version can sign in on Android with the same account, see identical data (goals, fish balance, building membership), and complete the full core loop natively.

---

## Open items intentionally deferred past v1
(Not tasked above — revisit after testing with your own group)
- Multi-building / multi-church support
- Badge system beyond placeholder button
- Poke / send-bible-verse interactions
- Push notification infrastructure beyond basic FCM token registration
- Expansion-unlock gameplay logic (playground etc.) beyond the group fund progress bar stub
- Content moderation tooling for bulletin posts
- Automated backups of the Pi (e.g. periodic export of Firestore isn't needed since Firestore is still Google-managed, but if you later add local Pi state — like the `.env` file or logs — back those up manually for now)
- Monitoring/alerting if the Pi goes offline (for v1, "the app stops letting people complete goals" is an acceptable signal; a proper uptime check is a later nice-to-have)
