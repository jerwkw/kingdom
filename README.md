# Kingdom

Kingdom is a web-first Flutter accountability app for a church cell group. Members create private spiritual goals, complete daily reflections, earn cosmetic currency, customize an avatar, and participate in a shared neighbourhood and bulletin board.

## Supported architecture

- Flutter Web client, with Android planned from the same codebase.
- Firebase Authentication for Google sign-in.
- Cloud Firestore for application data and live UI streams.
- Firebase Cloud Functions for rewards, purchases, neighbourhood membership, contributions, and aggregate statistics.
- Firebase Hosting for the web build and `/api/**` Functions rewrite.

The earlier Raspberry Pi backend under `server/` is archived and disabled by default. It is not part of the supported workflow.

## Local setup

Prerequisites are Flutter matching `pubspec.yaml`, Node.js 22, Java for the Firestore emulator, and a configured Firebase project.

```bash
flutter pub get
cd functions
npm install
cd ..
```

Run Flutter against deployed Firebase services:

```bash
flutter run -d chrome
```

To use local Auth and Firestore emulators, start the Firebase suite and opt in explicitly:

```bash
npx --prefix functions firebase emulators:start
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true
```

## Quality checks

```bash
flutter analyze
flutter test
flutter build web
cd functions
npm test
npm run test:rules
```

The rules suite verifies that clients cannot forge balances, streaks, completions, inventory, membership, or cross-neighbourhood reactions. Backend domain tests cover authoritative catalog prices and daily, weekly, and monthly period keys.

## Production deployment

```bash
flutter build web
npx --prefix functions firebase deploy
```

See `FIREBASE_DEPLOYMENT_GUIDE.md` for rollout order and post-deployment checks.

## Security model

Direct client writes are limited to editable profile fields, private goal content, and same-neighbourhood bulletin content. Fish balances, streaks, completions, inventory purchases, group funds, and building membership are written only through authenticated Cloud Functions. Store prices are looked up on the server.

Never commit service-account credentials, `.env` files, signing keys, or platform Firebase secret files.
