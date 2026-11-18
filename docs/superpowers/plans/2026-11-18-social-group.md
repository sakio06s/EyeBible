# Social Group Implementation Plan
> Execute inline using superpowers:executing-plans, then request one whole-branch review.

**Goal:** Implement the final supplied social UI specification.
**Architecture:** Existing static index.html, persisted local state, no backend.
**Tech Stack:** HTML/CSS/JS and Playwright Chromium/WebKit.
**Spec:** docs/superpowers/specs/2026-11-18-social-group-design.md

## Constraints and review focus
- Reference logo, no page eyebrow/subtitle. Retain functional section headings/date/verse data.
- Feed today plus six preceding Taipei dates; do not delete historical/private notes.
- Unread only others' public activity, persist seen IDs, clear on visible group page.
- Glow calculated by unique reading date, cap 5/floor 1, deduct missed completed dates, no premature today deduction.
- Legacy data, escaping, reply drafts, modal ownership and date rollover must remain safe.

## Task 1: Social UI and state
- [x] Write tests/social.cjs checking seven-day cutoff, privacy, ordering, Amen toggles, inline replies, unread persistence/clear, actual local roster, glow boundaries/gaps/duplicate dates/cancel, dark/light/narrow geometry.
- [x] Run to observe missing social UI failure.
- [x] Modify index.html: reference wordmark, remove page subtitles, composer/feed/roster, pure date-level calculation, activity seen IDs and safe reply binding.
- [ ] Run social and existing interface/daily/presentation/annotation suites; Python importer tests; git diff --check.
- [ ] Review whole change, fix important findings, commit and deploy with production content verification.
