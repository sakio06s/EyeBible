# Stable Five-post Feed Implementation Plan

> Execute inline in existing feature branch using superpowers:executing-plans; one fresh whole-change review at completion.

**Goal:** Stable light-theme Amen, live reply ordering, explicit five-post expansion and group settings under My Settings.
**Architecture:** Keep the existing authenticated SQL/RPC unchanged. Buffer its ten-post pages but reveal five at a time. Keyed article reconciliation patches reaction controls in place, preserving nodes, scroll and drafts. Settings/status live in profile; background polling every five seconds plus immediate post-mutation follow-up reads.
**Tech Stack:** Vanilla JS, existing Supabase RPC, Chromium/WebKit tests.
**Spec:** User2026-11-20:1/2 verified live; fix Amen rectangle/vertical flash and delayed reply pinning; first5, click Load more adds5; move group name/settings to My Settings; delete refresh button; automatic updates.

## Global Constraints
- No SQL or membership/data migration. Existing server10-row cursor/receipts/privacy unchanged.
- Five initially; only a button reveals another five; scrolling alone never loads more.
- Group board contains no group name/settings/refresh button. Join/setup/management remain available in My Settings.
- Poll every5000ms while visible; focus/online and successful local mutations refresh promptly. This is background sync, not a claimed push subscription.
- Same reading/current scripture/invitation/member-state guards retained.

## Review Focus
- No article/control replacement on a reaction; no layout/scroll/width change on pending/ack states.
- New replies sort at the visible top without a whole-page reload when already at the top; preserve deep reading/drafts.
- Client five-row limits must not skip hidden prefetched rows or lose cumulative count on polls.
- Settings moves must retain all owner/member/privacy/session guards and no duplicate handlers.
- Failed/ambiguous/offline reactions retain operation IDs and show desired pending state without unsafe retries.

### Task1: Regression and stable rendering
- [ ] Write failing test: light/dark pointer Amen keeps article/button/path identity, scroll and width; keyboard focus ring remains available.
- [ ] Reconcile articles by ID and structural signatures excluding reaction/unread fields; patch SVG heart/count/aria only for reactions; overlay queued desired states.
- [ ] Move group controls and status into profile card; render setup/management only when membership confirmed. Make repeated bindings idempotent.
- [ ] Run relevant invite/account/group regressions; commit.

### Task2: Five rows and automatic ordering
- [ ] Write failing tests for 5/10/15 expansion, no scroll auto-fetch, profile placement, no refresh button, automatic reply pinning and five-second sync.
- [ ] Reveal five from existing buffer or fetch another server page; preserve visible count, cursor and typed drafts on background reads.
- [ ] Preserve top0 for reordered live feed; focus own replied thread after successful reply; schedule follow-up if a mutation finishes during an earlier read.
- [ ] Run browser/core/private regressions, commit.

### Task3: Review/deploy
- [ ] Fresh independent review; reproduce/fix important findings once; run relevant final suite.
- [ ] Update setup/verification notes and preview version; confirm deployment. Keep production draft unchanged.
