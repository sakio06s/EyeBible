# Study export verification ledger

Plan: docs/superpowers/plans/2026-11-26-study-export.md
Spec: docs/superpowers/specs/2026-11-26-study-export-design.md

- Task 1: complete. Pure selection/reference tests fail before module, then pass with date/book/own-private/marks and complete parent discussion cases.
- Task 2: DOCX ZIP/XML and Chinese PDF extraction passed. Visual rendering found invisible glyphs with fontkit subsetting despite valid CMaps. Reproducing raster-ink regression added. Full static TrueType embedding renders all tested glyphs and preserves searchable text.
- Ruling: embed the complete static CJK font rather than runtime-subset it, because the subset stream rendered incomplete Chinese. Cost: about 4.4 MB per PDF and a one-time 7 MB font download for this browser. Word remains the default and lightweight.
- Task 3: initial Chromium/WebKit downloads and privacy/full pagination/cancellation tests passed; final regression and review pending.

- Final review: fixed live activity-cursor omission with a final head-content/activity consistency check; a moved eleventh post is reproduced RED before the guard and GREEN afterward, with no partial download. Busy-feed exports ask for a retry instead of omitting threads.
- Final review: missing next/replyCount, duplicate reply identity and inconsistent reply counts now fail closed; Chromium/WebKit malformed-page cases pass.
- Final review: mixed-book general and verse-specific notes are filtered before grouping; displayed references derive from selected verses, repeated book names and trailing cross-chapter verse inheritance are covered RED→GREEN.
- Final review: XML U+FFFE/U+FFFF caused a real invalid DOCX, so treated as a file-validity issue and fixed with XML 1.0 sanitization and ZIP/XML regression.
- Existing interface, groups UI and independent Chromium/WebKit cloud-device regression tests passed. No SQL migration required.

- Final verification: pure model, genuine DOCX ZIP/XML/valid timestamp, CJK PDF extraction plus visible-glyph raster and margin tests passed. Chromium/WebKit download tests passed with cancellation during font loading, empty results, moved live threads, missing protocol fields, duplicate identities and all earlier pagination/privacy cases.
- Interface, group action/archive and independent-device private-cloud regression tests passed. No deferred code-review findings remain.
