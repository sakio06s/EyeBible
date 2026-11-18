# Account and Cloud Implementation Plan
> Execute inline using superpowers:executing-plans and obtain one independent whole-branch review.

**Goal:** Add account login and private cross-device storage without losing local records.
**Architecture:** Existing static app plus cloud bridge, official Supabase SDK, RLS-protected versioned personal snapshots with record-level three-way merging.
**Tech Stack:** Plain JS, Supabase Auth, PostgreSQL, Node tests and Playwright.
**Spec:** docs/superpowers/specs/2026-11-18-account-cloud-design.md

## Constraints / review focus
No service-role secrets in client or repo. Disabled by default until real public config exists. No claim of live cloud until project configured and verified. Existing private notes remain private; no group sharing in this stage. Avoid overwriting simultaneous edits, cross-account import, stale session callbacks and unsaved drafts.

## Task 1: Versioned private storage and merge core
- [x] Write tests/cloud-core.cjs for round-trip legacy/current records, independent edits, removals and conflicts; observe RED.
- [x] Implement cloud/core.js with encode/decode/merge and explicit ownership normalization.
- [x] Write PostgreSQL tests then cloud/schema.sql; verify anonymous/Alice/Bob isolation, stale revision rejection and successful update.

## Task 2: Account flow and app integration
- [x] Add disabled public config, local pinned SDK, login/sync UI and app bridge.
- [x] Verify Email OTP/optional Google, first-account import consent, offline cache, logout and session switching with Playwright mocked Auth/PostgREST endpoints.
- [x] Retain existing app regression coverage and complete independent review.

## Task 3: Configure and enable
- [x] Document exact Supabase project/email template/redirect/SQL setup.
- [x] Obtain project URL and publishable key after the user creates/selects a project; apply schema via authorized account access or user SQL setup.
- [ ] Confirm real account round-trip before enabling production login. Keep cloud changes in a draft PR until the real project is configured; production remains v0.9.2.
