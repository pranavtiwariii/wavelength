# Wavelength

A cross-domain taste-matching app: match people on **music + movies + books**,
and give them a concrete reason to start a conversation.

**Status: Phase 0 complete** — scaffold, schema, and auth working end to end.

## Stack

| Piece | Choice | Note |
| --- | --- | --- |
| Mobile app | Flutter 3.47 / Dart 3.13 | Riverpod (state), go_router (routing), dio (HTTP), fl_chart (Taste DNA radar) |
| Backend | Node 20+, TypeScript, Fastify 5 | REST, TypeBox schemas, OpenAPI generated |
| Database | PostgreSQL | PGlite (embedded WASM Postgres) for local dev, real Postgres via `DATABASE_URL` |
| Auth | Email/phone OTP + JWT | Own implementation, no third-party auth dependency |
| Tests | vitest (server), flutter_test (app) | 34 server + 7 app |

## Run it

Two terminals.

**Backend** — no database install required; PGlite persists to `server/.pgdata/`:

```bash
cd server && npm install && npm start
```

**App** — talks to `http://localhost:4000` by default:

```bash
cd app && flutter run
```

On a dev server the OTP is printed to the server log *and* prefilled in the
app's code field, so you can complete sign-in with no SMS provider.

### Useful commands

```bash
cd server && npm test          # 34 tests: auth + compatibility engine
cd server && npm run typecheck # tsc --noEmit
cd server && npm run migrate   # apply migrations
cd server && npm run openapi   # regenerate shared/openapi.json
cd app && flutter analyze      # 0 issues
cd app && flutter test         # widget + API integration tests
```

`app/test/api_integration_test.dart` exercises the real Dart client against a
running server. It skips itself when the server is down, so `flutter test`
stays green either way.

## Layout

```
app/                      Flutter app
  lib/core/               theme, router, API client
  lib/features/auth/      sign-in, OTP verify, auth state
  lib/features/onboarding/home shell (Phase 0 placeholder)
server/
  src/routes/             HTTP surface
  src/services/
    compatibility/        the matching engine - pure, isolated, unit tested
    narrative/            (Phase 2) Claude API narratives
    integrations/         (Phase 1+) spotify, tmdb, googleBooks, trakt
  src/jobs/               (Phase 2) nightly recompute, weekly recap
  src/db/migrations/      SQL schema
shared/openapi.json       app <-> server contract (generated)
```

## The compatibility engine

`server/src/services/compatibility/` is deliberately dependency-free — no DB,
no HTTP, no framework — so the algorithm can be iterated and tested on its own.

It implements the spec's scoring model:

- `0.45 × cosine` (taste *shape*) + `0.35 × weighted Jaccard` (literal shared
  favourites) + `0.20 × style alignment` (era/mood overlap)
- Shared items are weighted by **inverse popularity**, so two people who both
  love an obscure film score far higher than two who both love a blockbuster.
- Domain weights are **not** fixed at a third each: a domain counts only when
  both users have it, scaled by data depth and each user's stated priority. An
  unconnected domain can't silently drag a score toward zero.
- Every score carries the concrete items that produced it, plus divergence
  highlights — the distinctive things one person loves and the other has never
  touched — for conversation prompts.

## Decisions taken (flagged as assumptions)

1. **Flutter, not React Native.** Requested. `fl_chart`'s `RadarChart` replaces
   `victory-native` for the Taste DNA visualization.
2. **No shared TypeScript package.** The spec assumed a JS app could import
   `/shared`. Dart can't, so the contract is a generated OpenAPI document and
   the Dart models are written against it. They're hand-written for now; worth
   generating once the API surface settles.
3. **Own OTP auth rather than Supabase Auth.** Keeps the stack runnable with
   zero third-party accounts or keys. Swappable later.
4. **PGlite for local dev.** No Postgres or Docker on the dev machine; PGlite is
   real Postgres compiled to WASM, and the same SQL runs against a real server.
5. **Pairs stored canonically ordered** (`user_a_id < user_b_id`, enforced by
   CHECK constraints) so precomputed compatibility is stored once, not twice.
6. **Web target added to the Flutter project** purely so the UI can be verified
   on this machine. iOS and Android remain the product targets.

## Known gaps / what's next

- **Toolchain:** iOS and Android builds aren't possible on this machine yet —
  Xcode is incomplete and the Android SDK is missing. See below.
- **Phase 1:** Spotify OAuth, taste import, discovery swipe UI, matching, chat.
- Photos, moderation, and the remaining onboarding steps are schema-only.
- OTP delivery is a `console.log`; no SMS/email provider is wired up.

### To build for real devices

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

…plus Android Studio for the Android SDK. Both need your password, so they
weren't run automatically.
