# Study Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Export selected devotional annotations/notes/group discussion to genuine DOCX or searchable Chinese PDF.
**Architecture:** Pure selection/reference model, browser-only document writers, modal/controller pagination adapter. Reuse existing authenticated read RPCs.
**Tech Stack:** Vanilla JavaScript, OOXML ZIP, pdf-lib 1.17.1, @pdf-lib/fontkit 1.1.1, Noto Sans CJK TC (OFL).
**Spec:** docs/superpowers/specs/2026-11-26-study-export-design.md

## Global Constraints
- Word＋PDF; full Chinese book names plus space and 章:節; ranges use – and disjoint verses use 、.
- Preserve highlight colors and own private notes only in personal mode; no private cloud data in group mode.
- Date/book searches and every page/reply must be complete; no new SQL.

## Review Focus
- Cross-chapter/disjoint references and ambiguous text-only group posts: normalized full references and strict book matching.
- Older records, duplicate snapshots and legacy partial highlights: preserve original text and dates without duplication.
- >10 posts and >100 replies with repeated/missing cursors: complete pagination or visible failure.
- Account/group switching or cancellation during generation: no stale file download.
- Chinese, emoji, XML/control characters and long multiline notes: readable real DOCX/PDF without injection.

### Task 1: Selection and document model
**Files:** study/export-core.js; tests/study-export-core.cjs.
**Interfaces:** collectPersonal(state, options), collectGroup(posts, options), formatReference(text), buildDocument(items, options).
- [x] Write/run failing tests for date inclusivity, strict ownership, book/chapter order, legacy partial/full colors, quoted notes and reference formatting.
- [x] Implement pure model and verify tests pass.

### Task 2: File generation
**Files:** study/export-files.js; study/vendor; study/fonts; tests/study-export-files.cjs.
**Interfaces:** docx(document), pdf(document, {check, progress}) return Uint8Array.
- [x] Vendor pinned PDF libraries/font with licenses and provenance.
- [x] Implement real DOCX packaging and PDF layout/font embedding; verify ZIP/XML text/highlights and extracted Chinese PDF text/page breaks.
- [x] Verify long text, emoji fallback and XML/control escaping.

### Task 3: UI, pagination, integration and release
**Files:** index.html; cloud/groups.js; study/export-ui.js; tests/static-assets.cjs; tests/study-export-ui.cjs.
**Interfaces:** app.exportIdentity(), app.exportGroupPosts(options, control); controller exports all filtered posts and replies via existing RPCs.
- [x] Add modal search/content/format controls, progress/cancel and download.
- [x] Test pagination, >100 replies, empty/invalid input, cancel/account/group invalidation, formats and narrow themes in Chromium/WebKit.
- [x] Run relevant existing cloud/groups/history regressions and independent code review.
- [ ] Publish and verify live artifacts.
