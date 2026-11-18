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
LEGACY_ONLY=1 node tests/annotations.cjs
```

The script serves the actual HTML from an ephemeral localhost port. It checks Chromium and WebKit at six viewport sizes, including narrow phones, landscape and desktop, using the largest supported scripture font. It tests single-tap whole-verse selection, color/clear persistence, untouched legacy data, notes/tab transitions, keyboard activation, and unchanged scripture geometry/scroll position when opening, coloring, clearing or closing the toolbar. The second command simulates browsers that ignore dynamic viewport height units.

WebKit tests are engine checks, not a substitute for a final check on an actual iPhone with Safari's browser bars and software keyboard.

`presentation.cjs` checks the EyeBible name, visible Taiwan date (including a day boundary in another device timezone), exact sharing prompt, saved light/dark preferences, dark inputs, and legacy-note preservation in both engines.

`daily.cjs` checks dated and latest-file fetching, true verse numbering, stale/offline fallback, legacy snapshot isolation, frozen note drafts across midnight, historical note navigation, delayed responses without moving the reading, and malformed or changed snapshot rejection in Chromium and WebKit. Run the importer unit suite separately with `python3 -m unittest discover -s tests -p "test_*.py"`.

`interface.cjs` checks the annotated onboarding and reading-screen changes, compact retry control, local checkin names/avatars, circular centered photo uploads, and concise floating-toolbar/note titles.

`social.cjs` checks the real seven-day feed boundary in Taipei, private/own activity exclusion, unread persistence, inline reply drafts, Amen toggles, local member completion and glow levels 1–5, duplicate dates, missing-day decay, midnight rollover and narrow light/dark layouts.

`refinements.cjs` verifies 20% smaller logo with transparent dark treatment, equal annotation buttons, concise prompts, one group composer, historical reading dates/full verse excerpts, and visible emoji pixel centering.
