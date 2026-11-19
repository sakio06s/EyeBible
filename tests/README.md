# Annotation regression checks

The app remains a static `index.html`; these checks do not change its hosting setup.

With Node.js and Playwright installed:

```sh
npm install --no-save --package-lock=false playwright@1.62.1
npx playwright install --with-deps chromium webkit
node tests/annotations.cjs
node tests/presentation.cjs
node tests/daily.cjs
node tests/interface.cjs
node tests/social.cjs
node tests/refinements.cjs
node tests/login-mobile.cjs
LEGACY_ONLY=1 node tests/annotations.cjs
```

The script serves the actual HTML from an ephemeral localhost port. It checks Chromium and WebKit at six viewport sizes, including narrow phones, landscape and desktop, using the largest supported scripture font. It tests single-tap whole-verse selection, color/clear persistence, untouched legacy data, notes/tab transitions, keyboard activation, and unchanged scripture geometry/scroll position when opening, coloring, clearing or closing the toolbar. The second command simulates browsers that ignore dynamic viewport height units.

WebKit tests are engine checks, not a substitute for a final check on an actual iPhone with Safari's browser bars and software keyboard.

`presentation.cjs` checks the EyeBible name, visible Taiwan date (including a day boundary in another device timezone), exact sharing prompt, saved light/dark preferences, dark inputs, and legacy-note preservation in both engines.

`daily.cjs` checks dated and latest-file fetching, true verse numbering, stale/offline fallback, legacy snapshot isolation, frozen note drafts across midnight, historical note navigation, delayed responses without moving the reading, and malformed or changed snapshot rejection in Chromium and WebKit. Run the importer unit suite separately with `python3 -m unittest discover -s tests -p "test_*.py"`.

`interface.cjs` checks the annotated onboarding and reading-screen changes, compact retry control, local checkin names/avatars, circular centered photo uploads, and concise floating-toolbar/note titles.

`social.cjs` checks the real seven-day feed boundary in Taipei, private/own activity exclusion, unread persistence, inline reply drafts, Amen toggles, local member completion and glow levels 1–5, duplicate dates, missing-day decay, midnight rollover and narrow light/dark layouts.

`refinements.cjs` verifies 20% smaller logo with transparent dark treatment, equal annotation buttons, concise prompts, one group composer, historical reading dates/full verse excerpts, and visible emoji pixel centering.

## Account and private cloud storage

`node tests/cloud-core.cjs` checks stable record encoding and three-way merging, including deletions and conflicts. `node tests/cloud-ui.cjs` uses the real locally vendored Supabase SDK with mocked Auth/PostgREST endpoints to check OTP, import consent, independent updates, conflict choices, offline retry, logout and account isolation. These tests never send real email.

Run `sh tests/cloud-db.sh` only against the disposable `eyebible-cloud-test` Docker container described in [cloud setup](../docs/cloud-setup.md). It rebuilds that test database schema and checks actual PostgreSQL RLS, per-user isolation and optimistic revisions. Never run the database harness against a production database.

`login-mobile.cjs` checks actual touch/keyboard entry in mobile Chromium and WebKit contexts and simulates iOS visual viewport shrink/pan. Email and OTP remain visible on short keyboard viewports without scrolling the app underneath. This is not a physical iPhone software-keyboard test.

`google-login.cjs` checks Google-only mode, disabled-provider readiness messaging, retry after backend activation, minimal identity scopes, account selection and PKCE redirect parameters without contacting real Google or requesting Email OTP.

`node tests/cloud-devices.cjs` opens independent Chromium and WebKit storage contexts against a shared simulated cloud API. It uses the shipped SDK and real UI to verify verse highlights, private notes and checkins arrive on the second device, independent concurrent edits survive merging, another account sees none of these records, and logout clears the displayed workspace. This is a deterministic integration test, not evidence of real Supabase account synchronization.

## Invite-only shared groups

`sh tests/groups-db.sh` resets only the disposable `eyebible-cloud-test` database, runs private isolation tests and applies `cloud/groups.sql`. It checks 30-day expiry/rotation, membership/blocking, cross-group and anonymous denial, author/leader operations, duplicate retries/tombstones, archive retention and keyset pagination. Never use this harness against the live project.

`node tests/groups-ui.cjs` runs the shipped app/group module in Chromium and WebKit with a simulated account bridge/API: create, invitation preview/join, private/public separation, replies/Amen/completions, ambiguous network delivery followed by reload/retry, dated archive pagination, and delayed responses after signout. `cloud-devices.cjs` also exercises the real shipped SDK/account subscription with the groups flag enabled. These do not replace the two-real-account acceptance steps in [group setup](../docs/groups-setup.md).

`node tests/groups-edge.cjs` covers all independent review fixes: semantic scripture identity and conflicting-version isolation, group/session-bound drafts with private-draft preservation, per-operation multi-tab outboxes, delayed old-group pagination, refreshed expanded feeds, retained archive pages/replies, Taipei reply dates, photo DOM reuse and ungrouped personal checkins. `groups-db.sh` includes `groups-payload.sql` for bounded photo/unseen payloads and `groups-races.sh` for concurrent joins. SQL set-operation receipt tests prove an acknowledged-but-lost operation cannot undo a newer opposite choice.
