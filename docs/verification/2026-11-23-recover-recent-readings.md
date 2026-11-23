# Restore missing recent readings

Production initially returned 404 for data/daily/2026-11-21.json and 2026-11-22.json. Today 2026-11-23 already exists and is preserved.

Read-only GitHub Actions run 45131694773 on the isolated recovery branch used the shipped updater and fixed YouTube channel to resolve each explicit historical date into RUNNER_TEMP. validate/verify-sources succeeded; publish skipped. Retrieved the two generated public-domain JSON records from that run, then independently matched every verse against the pinned chi-cuv.usfx.xml source with the same canonical selector. No guesses or date shifts.

- 2026-11-21: 哥林多後書1:8-14, 7 verses, https://www.youtube.com/watch?v=HcGDzXxS6L4
- 2026-11-22: 哥林多後書1:15-24, 10 verses, https://www.youtube.com/watch?v=u1FyBPaWcqQ

Only add these missing daily files and this verification record to main. The one-off recovery workflow is NOT included in the publication diff. data/latest.json, sync-status.json, existing daily records, app code and live user data stay untouched.

Chromium and WebKit exercised the actual three-day JSON records: exact references, verse counts, source links, checkin eligibility for today/yesterday/day-before and persistence after reload. Selection is performed at the top of the reading pane, as in normal use; selecting programmatically while still at the lower checkin button correctly defers replacement rather than jumping the reading.
