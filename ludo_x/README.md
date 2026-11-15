# LUDO X

Bright, playful classic-style Ludo game prototype for Android (original art, board, pawns and sounds). Flutter app, Firebase Authentication, Firestore and Cloud Functions.

> **SIMULATED MONEY ONLY.** There is no payment SDK, no payment provider and no code path that moves real funds. Deposits, withdrawals, entry fees and prizes are demo ledger entries. `realPaymentsEnabled` is hard-wired to `false` on the server and cannot be switched on from the app. Do not enable anything real until the legal and regulatory requirements for your jurisdiction (real-money gaming licensing, KYC/AML, tax, age and state restrictions) have been independently verified.

## What is in the box

| Area | Where |
|---|---|
| Flutter app | `lib/` |
| Rules engine (Dart) | `lib/engine/ludo_engine.dart`, bots in `lib/engine/bot_ai.dart` |
| Authoritative match logic (Dart, in-process) | `lib/server/server_match.dart` |
| Authoritative match logic (Cloud Functions) | `functions/lib/engine.js`, `functions/lib/match.js`, `functions/index.js` |
| Firestore security rules | `firestore.rules` |
| Synthesised sound effects | `assets/sfx/*.wav` (regenerate with `python3 scripts/make_sfx.py`) |

## Run it right now (no Firebase needed)

If Firebase is not configured the app automatically falls back to a **local simulation backend** that runs the same server-side logic in-process (wallet ledger, server-side dice, anti-cheat, match logs, admin stats). Everything works offline.

```bash
# Flutter 3.27 or newer (stable) and the Android SDK required
bash scripts/bootstrap_android.sh     # generates android/, sets minSdk 23, INTERNET permission, app label
flutter run                            # emulator or USB device
```

## Build the APK without installing anything (GitHub Actions)

Push the project to a GitHub repo. `.github/workflows/build-apk.yml` builds the APK in the cloud: Actions tab > Build LUDO X APK > Run workflow, then download the `LUDO-X-apk` artifact. The workflow finds `pubspec.yaml` wherever it is and does not depend on the `scripts/` folder.

## Build the APK locally

```bash
bash scripts/bootstrap_android.sh      # once
flutter pub get
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk
```

That release build is signed with the debug key, which is fine for sideloading and demos. For a store release create a keystore and configure `android/app/build.gradle(.kts)` per <https://docs.flutter.dev/deployment/android>.

## Connect Firebase (full architecture)

1. Create a Firebase project. Enable **Authentication** (Email/Password and Anonymous), **Firestore** and **Functions** (Blaze plan is needed to deploy functions).
2. Install the CLIs: `npm i -g firebase-tools` and `dart pub global activate flutterfire_cli`.
3. From the project root:
   ```bash
   firebase login
   flutterfire configure            # overwrites lib/firebase_options.dart and adds google-services.json
   (cd functions && npm install)
   firebase deploy --only firestore:rules,functions
   ```
4. Run or build the app again. With real `firebase_options.dart` the app uses `FirebaseBackend` automatically (the Auth screen shows "Backend: Firebase Auth + Firestore + Cloud Functions").
5. Make yourself an admin (unlocks the Admin dashboard):
   ```bash
   cd functions && GOOGLE_APPLICATION_CREDENTIALS=serviceAccount.json node ../scripts/set_admin.js you@example.com
   ```
   Sign out and in again to refresh the token.

Local emulators: `firebase emulators:start --only functions,firestore,auth` (ports in `firebase.json`; point the app at them with `useFunctionsEmulator` / `useFirestoreEmulator` while developing).

### Architecture

```
Flutter UI  --(intents only: roll, move, deposit...)-->  Cloud Functions (Admin SDK)
     ^                                                        |
     |  read-only streams / snapshots                         v
     +------------------------ Firestore <-- transactions: wallet ledger, match state, logs, stats
                                  (clients can NOT write: firestore.rules)
```

* `createMatch` charges the entry and creates the match in one transaction. `rollDice` / `moveToken` / `botStep` / `timeoutTurn` / `abandonMatch` mutate match state and settle rewards on completion.
* `demoDeposit` / `requestWithdrawal` write the ledger. Admin-only: `adminStats`, `adminSetConfig` (custom claim `admin`).
* Collections: `users/{uid}` (+ `transactions`, `matches`, `notifications`), `leaderboard`, `matches/{id}` (+ `log`), `matchSecrets/{id}` (never readable), `config/game`, `stats/global`.

## Ludo X UI (v2 reskin)

The whole UI layer follows the Ludo X art: royal-blue arena, glossy 3D candy buttons, coin pill, gold-outlined ribbon titles.
Game logic, backend, wallet ledger, engine and bots are untouched, so every function works as before.

| Ludo X screen | What it does here |
|---|---|
| Main menu | Competitive (entry-fee match), Pro Challenge (bot difficulty + entry tier), Vs Computer (free game vs 3 bots), Pass N Play (2-4 people on one phone, on-device) |
| Side items | Daily Rewards (7-day streak claim), Free Coins (simulated top-up), Tournament (SOON), Shop |
| Select Game Mode | Vs Computer: 4 players Classic. Pass N Play: 2 / 3 / 4 players. 6 players and Quick Ludo show as SOON |
| Shop | Coin packs add simulated coins via the same `demoDeposit`, custom amount, withdraw request, full Ledger tab |
| My Profile / Statistics | Avatar, ID, level, totals, achievements, match history |
| Leaderboards / Settings | Podium + ranks; sound, notifications, calculator, admin (if admin), fair play, sign out |
| Game screen | Four player cards (YOU / AI BOT tags kept), new board, dice, turn timer |

Currency is shown as **coins** (simulated) instead of rupees. To switch the label back, edit `inr()` in `lib/core/theme.dart`.

## Look, feel and engagement

* Bright indigo + sunny yellow theme, chunky 3D-style buttons, pawn-shaped tokens on a classic white-track board, animated dice and token hops.
* Sounds are synthesised from scratch by `scripts/make_sfx.py` (dice rattle, pawn hop, capture, six, home, win fanfare, UI tap, level-up, coin). Tap the speaker icon on Home to mute.
* Progression, all granted by the backend and **never tied to money**: XP for every finished match (practice included), levels and titles, a 7-day daily-reward streak (small demo coins, simulated), 8 achievements, confetti on wins.
* Healthy play: a break reminder appears every 45 minutes.

## Game modes

| Mode | Entry | Opponents | Wallet effect |
|---|---|---|---|
| Practice | free | 3 AI bots | none, no rewards, unlimited |
| Competitive Demo | ₹100 demo | 3 AI bots | pool ₹400 -> 1st ₹160, 2nd ₹120, 3rd ₹70, 4th ₹0, margin ₹50 (12.5%). Breakdown shown before you pay |
| Pro Bot Challenge | ₹50 / ₹100 / ₹200 demo | 3 bots, Easy / Medium / Hard (per bot or all) | same 1.6x / 1.2x / 0.7x multipliers, simulated winnings only |

Entry fees, multipliers, turn timer, bot names and competitive bot difficulty are editable in the Admin dashboard. The payout calculator (Home > Payout calculator) recomputes pool, payouts, total and margin live as entry or multipliers change.

## Ludo rules implemented

Standard 15x15 board with 52-square track, 4 colours (Red, Green, Yellow, Blue), a 6 brings a token out, exact roll needed to finish, 8 safe squares (4 start squares + 4 stars), captures send a token back to the yard, a 6, a capture or reaching home grants another turn, three sixes in a row forfeit the turn, tokens move through a private home column, turn timer with server-side auto-play on timeout, finishing order determines rank. A match ends when you finish or three players have finished.

## Bots

Three AI personalities: **Rusher** (hunts captures), **Guardian** (prefers safe squares and avoids danger), **Strategist** (balanced). Difficulty: **Easy** random legal moves, **Medium** heuristic with 15% slips, **Hard** heuristic plus threat analysis. In testing (200 matches) a Hard strategy beats three Easy bots about 80% of the time.

## Security and fair play

* **Server-authoritative dice**: commit-reveal. The server publishes `sha256(seed)` before roll 1, derives roll *n* from `sha256(seed:n)` (rejection-sampled, unbiased) and reveals the seed after the match. The result dialog and match log verify it for you.
* **Secure match state / no client balance writes**: Firestore rules make everything read-only for clients; the seed lives in `matchSecrets`, unreadable by clients.
* **Anti-cheat validation**: stale/replayed sequence numbers, out-of-turn actions, illegal tokens, sub-150 ms human actions, too-early bot steps and early timeouts are all rejected, logged as violations, and the match is flagged after 5.
* **Match logs**: every roll/move/capture/skip/timeout is recorded in a hash-chained log.
* **Bot identification**: every AI seat carries an AI BOT tag, difficulty and strategy name in the game, results, lobby and logs. Every opponent in this prototype is a bot.

## Tests

```bash
cd functions && npm test      # 10 tests: board geometry, rules, payouts, dice, 200 full matches, anti-cheat
flutter test                  # Dart engine + server logic mirror (test/engine_test.dart)
```

## Known limits of this prototype

* Matches are single human vs three bots (as specified). There is no human multiplayer.
* The leaderboard in the local simulation includes five fixed rows tagged SAMPLE. With Firebase it shows real users only.
* In the local simulation the single device user can open the admin dashboard; with Firebase it requires the `admin` claim.
* Bot turns are driven by the client calling `botStep` at a human pace; the server enforces turn order, timing and legality, but a production system would run bot turns server-side on a schedule or task queue.
