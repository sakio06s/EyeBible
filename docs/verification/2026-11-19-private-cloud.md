# Personal cloud verification — 2026-11-19

## Confirmed
- The user reported successful real Google sign-in on the preview.
- Fresh `tests/cloud-core.cjs`: ownership normalization, record roundtrip, independent edits/deletions, explicit conflicts.
- Fresh `tests/cloud-ui.cjs` in Chromium and WebKit: shipped SDK against simulated Auth/PostgREST; import consent, save/retry, conflict choices, account switching and logout isolation.
- Fresh `tests/cloud-devices.cjs`: independent Chromium and WebKit contexts share only the simulated API. Real UI creates a highlight, private note and checkin; another browser receives all three. Concurrent independent edits merge; a second account has none of the first account's records; logout removes the first account's displayed records.
- Fresh `sh tests/cloud-db.sh`: PostgreSQL 17 in the disposable `eyebible-cloud-test` container; owner isolation, anonymous denial, stale revision rejection. No live project data touched.

## Still requires a real account
Use the preview, not production v0.9.2. Create a highlight, private note and checkin, wait for 已同步到雲端 in 我的設定, then sign into the same Google account in another browser and confirm all three. Report errors without sharing session tokens or passwords. The user subsequently confirmed item 5 (same-account cross-browser records) on 2026-11-19. This is separate from today’s scripture-source issue and from the simulated tests.

## Shared groups are a separate boundary
Private snapshots are readable only by their owner. Do not expose them to group members. A separate group schema and explicit membership controls must publish only shared posts, replies, Amen reactions, public member identity and reading completions. Seven days is a feed filter; historical records must remain accessible through the footsteps view under the same group membership permissions. Do not silently publish historical local/individual records when joining a group.
