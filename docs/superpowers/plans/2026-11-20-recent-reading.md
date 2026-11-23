# Recent Reading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Date picker 今天／昨天／前天 opens exact scripture and dated completion.
**Architecture:** Native select on existing date/time; reuse validated immutable snapshots and authenticated dated completions. Manual request generation/account guards; background today loading cannot replace manual history.
**Tech Stack:** Existing vanilla JS, Supabase RPC, Playwright.
**Spec:** docs/superpowers/specs/2026-11-20-recent-reading-design.md

## Global Constraints
- Exactly three options 今天、昨天、前天. Taipei dates; small arrow; no new subtitle.
- No SQL migration. Keep preview-only release, main unchanged.
- Historical failures retain prior real text/date, no wrong-day fallback/checkin.

## Review Focus
- Fast date switches and background requests: last intent wins.
- Account switch while delayed request: ignore old response.
- Taipei midnight/month/year boundaries: exact three days, preserve existing background draft behavior.
- Offline/missing date: cached exact version or retain prior reading, retry possible.
- Prior history outside two days: no forced jump, expose correct absolute date.

### Task 1: Recent date picker and date-safe loading
**Files:** Modify index.html; Create tests/recent-reading.cjs; docs/verification/2026-11-20-recent-reading.md.
**Interfaces:** chooseReadingDate(date) consumes allowed date; activateReading/rememberReading persist exact dated immutable snapshots; existing groupController.complete(date,value) unchanged.
- [x] Write Playwright failing tests for3 options, labels/arrow, dated scripture/checkin/note/history and completion RPC, focus retention, cache/offline, missing/wrong response, quick switch, account cancellation, Taipei date boundary.
- [x] Run tests/recent-reading.cjs; expect missing selector failure.
- [x] Implement picker and scoped manual loader; guard background today loads, old async/account changes; render relative labels only on recent picker choices, retain old history absolute dates. Retry selected date.
- [x] Run recent-reading, daily, daily-preview, annotations, cloud-devices, groups-ui, presentation, refinements; expect pass. Fresh whole-change review, one fix pass; verify then publish preview and update draftPR.
- [x] Commit tested code/docs; final preview version v0.15.2. No privileged SQL required.

Latest user constraint: all scripture entry points (picker, footprints, shared scripture) permit completion only 今天／昨天／前天; older readings remain readable/annotatable, existing completion retained read-only. Central UI handler and disabled state must enforce range. Existing dated storage/sync remains compatible; no SQL migration.
