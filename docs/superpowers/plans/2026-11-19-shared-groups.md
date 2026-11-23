# Shared Groups Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement task-by-task in the existing feature checkout.

**Goal:** Invite-only groups with 30-day invitations, shared interactions and permanent dated history.
**Architecture:** Add membership-guarded RPCs and separate shared tables beside private snapshots. A standalone group module observes account sessions and an explicit app bridge; public mutations use persistent destination-bound operation IDs.
**Tech Stack:** Vanilla JS, shipped Supabase SDK, PostgreSQL 17, Playwright Chromium/WebKit.
**Spec:** docs/superpowers/specs/2026-11-19-shared-groups-design.md

## Global Constraints
- One current group per account; invitations expire after 30 days and rotation invalidates old codes.
- Group feed: Taipei today plus prior six days. Archive retains older records. Private snapshots never visible to peers.
- Removed members blocked until leader lifts restriction. No historical automatic publication on joining.
- Existing UI copy, wordmark and verse annotation behavior retained. No service role keys, purchases or framework migration.

## Review Focus
- Delayed responses after logout/removal must not restore another account's group.
- Retry after network ambiguity must not duplicate posts or revive deleted ones.
- Joining while stale operations exist must not send them to another destination.
- Server dates and archive pagination must preserve discussion chronology independently of scripture date.
- RPC authorization must resist guessed cross-group IDs, author forgery and direct table writes.

### Task 1: Shared PostgreSQL boundary
**Files:** Create cloud/groups.sql, tests/groups-db.sql, tests/groups-db.sh.
**Interfaces:** RPC group_action(p_action text,p_data jsonb) returns jsonb; group_read(p_mode text,p_day date,p_before timestamptz,p_before_id uuid) returns jsonb. Each derives auth.uid. Modes overview/recent/archive; archive uses publication date and keyset pagination. Action names create/preview/join/rotate/leave/remove/unblock/profile/post/reply/amen/delete/read/complete. p_data contains explicit group_id for group mutations.
- [x] Write SQL tests for anonymous/nonmember/cross-group denial, 30-day invite/rotation, one group, blocked rejoin, private isolation, duplicate post/reply/reaction, tombstones, dated archive and departure.
- [x] Run tests against disposable PostgreSQL; expected missing RPC failure (RED).
- [x] Implement additive rerunnable tables/RLS/RPCs; no live project mutation.
- [x] Run tests; expected all assertions succeed (GREEN), commit.

### Task 2: Group module and app bridge
**Files:** Create cloud/groups.js; modify cloud/account.js, index.html; create tests/groups-ui.cjs.
**Interfaces:** window.EyeBibleAccount.subscribe(callback), .request(name,data) passes session-safe RPC; callback {userId,ready}. window.EyeBibleApp group hooks setGroup(view), context(), onGroupEvent(callback) with post/complete events; history day hook loads archive. Group module owns separate state, outbox and membership UI. Personal encode does not contain shared remote data.
- [x] Write browser tests for create/join preview confirmation, public/private paths, retry destination isolation, replies/Amen, completion, archive pagination, unread and logout late responses.
- [x] Run tests; expected absent group UI/module failure (RED).
- [x] Implement bridge and separate module with 20-second visible polling, safe deferred feed updates, persisted per-user/group outbox and bounded responses; use no SDK internals or token extraction.
- [x] Run groups UI and existing account/social/annotation suites; expected PASS, commit.

### Task 3: Setup, review and preview
**Files:** docs/groups-setup.md, tests/README.md, verification notes and version badge.
- [x] Document exact additive migration and two-real-account acceptance; live setup remains pending if backend access is unavailable.
- [x] Run full relevant browser, core and disposable database suites; expected PASS.
- [x] Obtain one fresh whole-change code review, fix important findings with failing regression then passing tests.
- [ ] Publish reviewed files to existing draft PR/preview and confirm Vercel success. Do not claim live group sharing until migration and two-account acceptance pass.
