# Ten-post feed and current reading Implementation Plan

> Execute inline with superpowers:executing-plans; one independent whole-change review at completion.

**Goal:** Fix current scripture on previews and implement the user's revised social feed.
**Architecture:** Keep private storage unchanged. Preview-only same-origin scripture proxy reads validated daily JSON from main; group RPC provides all-history 10-post cursor pages ordered replied-first, latest reply, then new posts. Reply Amen uses a separate RLS-locked reaction table and the existing durable operation receipts.
**Tech Stack:** Vanilla JS, Vercel Node function, PostgreSQL, Playwright.
**Spec:** User 2026-11-19 message supersedes seven-day feed: latest10, scroll another10, replies pin, reply Amen, no tap background; current scripture must load. User confirmed real sharing/private isolation/private cross-device sync.

## Global Constraints
- No deletion of history or private data. Existing groups/members/invitations retained.
- 10 posts per wall page; all history eligible. Replied posts first by newest active reply; unreplied by publication date.
- Archive remains date-based. 30-day invitations unchanged. SQL migration re-runnable and additive.
- Preview daily data follows main's scheduled updates, not a frozen branch snapshot. Preserve dated annotations.

## Review Focus
- Reply deletion/pinning and cursor moves cannot mix groups or duplicate rows.
- Reply Amen must check group/post/reply ownership and not replay an accepted old operation.
- Async feed appends retain scroll/drafts and allow reaching the roster.
- Preview data proxy must not accept arbitrary URLs or expose credentials; date/network failures preserve readable fallback.
- Backwards compatibility until the new SQL migration is applied must fail visibly and preserve private sync.

### Task 1: Current scripture
- [x] Add failing tests for preview API date routing, source validation, timeout/error and browser fallback.
- [x] Add api/scripture.js: only fixed main-repo daily/latest paths, bounded size, timeout, validated response, cache headers. Preview hosts use it; production/local paths remain compatible.
- [x] Run API/browser daily tests + importer11, commit.

### Task 2: Feed and reply reactions
- [x] Add SQL failing tests: all-history10, reply-first ordering/keyset, reply Amen authorization/receipt/deletion and unread history.
- [x] Add reply reaction table, last_reply_at metadata, private post JSON helper, group_feed(p_cursor jsonb); keep group_read archive compatibility. Update mutation and grants.
- [x] Add UI failing tests: no tap highlight, reply Amen, 10-post scroll append, roster access, scroll/draft continuity and existing invitation/session regressions.
- [x] Integrate group_feed, same-size page loading, accessible scroll trigger and reply reactions; preserve pending operations and original permissions.
- [x] Verify PostgreSQL and browser suites, commit.

### Task 3: Review and preview
- [x] Independent review; fix important findings with regressions.
- [ ] Run relevant final suites, publish preview and updated additive SQL. Live SQL application remains user-operated without privileged tool access.
