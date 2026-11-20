# EyeBible 小組共用設計（已確認）

## 使用者確認摘要
- 已確定：組長建立小組、成員輸入邀請碼加入；留言與回覆、阿們、成員簽到和未讀數在同組內共用。
- 已確定：互動頁顯示台灣今天及前六天的留言；舊資料保留，足跡依日期顯示當日小組討論。私人筆記和標註僅本人可見。
- 實作提案：第一版每帳號同時加入一個小組；一般成員可退出，組長暫不提供退出或移交。
- 實作提案：邀請碼三十天有效，組長可產生新碼，舊碼立即失效。
- 實作提案：加入前的筆記與簽到不會自動公開。加入後新儲存的公開分享和新簽到才會傳到目前小組；私人筆記只走個人儲存。
- 實作提案：小組資料每二十秒及返回頁面時更新；斷線待送內容保留原小組，不會改送到另一小組。
- 組長可移除成員及管理不當留言；被移除者需組長解除限制才能重新加入，不能拿舊邀請碼自行重入。離組後不能再讀取該組的歷史，原本公開內容留在組內。
- 驗收：用兩個真實帳號確認邀請、分享、回覆、阿們、簽到、私人資料隔離和歷史查閱後，才更新正式版。

以下為實作與權限細節。

## Intent and confirmed requirements
The user approved Google login and cloud storage, then explicitly chose leader-created groups with invitation-code joining, with invitations valid for 30 days. Keep the current social-style interface: shared posts at the top, members at the bottom, Amen and inline replies, unread counts on the group navigation icon. The feed shows Taipei today and the previous six dates. Older data remains in the cloud and is available through footsteps; seven days is not a deletion policy. Private notes and highlights stay private. Completed members glow at levels 1–5, consecutive completions increase the level, missed complete days decrease it.

Cross-browser Google sign-in was reported successful. Automated private sync and database isolation tests pass; the user's real highlight/private-note/checkin roundtrip remains unconfirmed. Do not describe login success as proof of live data synchronization.

## Approaches
- All signed-in people in one shared group: simple, but grants unrelated people access. The user chose invitation-based membership instead.
- Dedicated group data in the existing Supabase project, next to owner-only personal snapshots: selected approach. Preserves the existing app/deployment and separates shared/private permissions.
- Exposing or merging personal snapshot payloads for peers: rejected; private records must never become readable to group members.

## User flow
After login, an ungrouped account can create a named group or enter an invitation code from the leader. Neither action is required to read or keep private notes. Joining uses a confirmation screen naming the group before committing membership. A group member sees the existing social feed and member roster. Group settings shows the group name and, for the leader, copy/regenerate invitation and remove member controls.

Builder proposal: first version permits one current group per account. The database enforces this, and the UI explains it. A member can leave and join another group; the leader must retain leadership and cannot leave their group in this version. Multi-group switching and leadership transfer are deferred. Leaving/removal immediately removes access to that group's cloud history; retained posts stay with the group. Personal notes/highlights/checkins remain available to their owner.

Builder proposal: invitation codes use a high-entropy random token that can be copied (not a guessable sequential ID), expire after thirty days, and can be replaced by the leader. Replacing invalidates the old code. Only the leader may see or regenerate a usable code. Builder decision after independent review: leader removal creates a group-specific blocked-member record. Join checks the block inside the membership transaction, even with a valid invite; the leader can explicitly lift it from group settings, after which the person still needs a valid invitation. Voluntary departure does not create a block. Removal revokes access immediately without requiring invitation rotation. A member may share the code they were given; anyone holding a valid code can request to join after authenticating, so the UI describes it as an invitation credential. Group names are revealed only after a valid code lookup.

## What is shared
Group public profile: chosen display name and avatar/photo only; no email addresses, Google tokens or personal settings.
Group posts: only notes the author explicitly saves as a group share while a member; include scripture reference/quotation and validated scripture snapshot needed for historical verse navigation. Private checkbox means personal storage only. Keep current personal copy for the author and use a stable shared post ID. Existing local/private-cloud notes are not automatically published on joining. If an old local public note is to be published later, require an explicit action naming the destination group.
Replies and Amen: group-scoped; immutable reply IDs and unique `(post, user)` reactions prevent duplicate retries and double counts. Only the author can remove their reply/reaction; leader can moderate shared posts/replies. No private note can be the parent of a shared reply. Members cannot set the author, another member's profile, membership role or another member's completion.
Completion: publish the member's own reading date and completion state, not their highlights/notes. First join does not automatically publish old checkins. New completion/cancellation updates group state and private personal state independently with visible success/failure. Glow is computed from the group's retained completion dates using the existing Taipei-date rule; only today's completed members glow.

## Data and authorization
Add new group schema SQL alongside `cloud/schema.sql`; never modify existing private snapshot visibility. Tables cover groups, memberships/public profiles, invites, posts, replies, reactions, completions and read markers. All tables enable RLS, anonymous access is denied, and direct writes cannot bypass validation. Membership uniqueness, foreign keys, text/image size bounds and reaction uniqueness are database constraints.
Use narrow authenticated RPCs for creation, invite preview/join, membership changes and validated mutations. Each derives actor from `auth.uid()`, checks active membership/role inside the transaction, and sets a fixed safe search_path. Lock group/membership rows consistently for join, leave and leader removal so concurrent operations cannot leave orphan permissions. RLS helper functions avoid recursive membership policies. Invite storage is inaccessible to ordinary members. SECURITY DEFINER functions get explicit execute grants only; no service-role credential enters the browser.
Readers must be active members of the requested group for recent feed, archive, members, completion and reaction/reply queries. Cross-group IDs fail even when the user can access another group. Every mutation repeats this check; a guessed post ID is not authority. Removal and departure preserve historical content but revoke reading/writing permission. A tombstone for deletion/moderation prevents retries from recreating deliberately removed content.

## Feed, history and notifications
Recent feed is filtered by server-created post timestamps in Taipei, not user-editable scripture dates. It retains all replies to a visible post. Old posts and all replies remain accessible in footsteps by the post's actual Taipei publication date; replies show their own timestamps even when posted later. A shared scripture quote has a separate reading date so a reflection on an old passage does not disappear from today's feed or appear on the wrong archive date.
Footsteps keeps personal records and adds a clearly labeled group discussion area for the selected day, showing all current-group posts on that date including other members' posts, replies and Amen. Reading snapshots let people navigate to the full passage without importing another user's private annotations. Archive requests are paginated; no seven-day condition is applied there. No retention cleanup job is added.
Unread activity consists of other members' posts and replies, excluding the user's own activity and reactions. Read markers are server-backed per group/user, mark only activities actually loaded and viewed while the group page is visible, and cannot clear an unseen newer page. Footsteps archive viewing marks viewed activities only. Badge counts cover the recent feed, matching the seven-day screen rule; replies on archived posts are accessible in history and do not cause a badge with no visible target.

## Sync, offline and account changes
Retain the pinned SDK and separate group module; expose an account-session subscription from the account module instead of extracting tokens from local storage. Private and shared storage remain separate. Membership/context changes and logout invalidate all pending group requests, clear shared DOM/caches/drafts and prevent late responses appearing in another account/group.
Builder proposal: poll visible group data every 20 seconds and refresh on focus, successful mutation and online return. Use pending-operation IDs for idempotent retries, back off on failures, and preserve cursor/drafts/scroll when applying updates. Polling avoids requiring a Realtime publication or another service. Never replace the feed while a reply is being edited; defer or patch safely.
Offline private work remains usable. A pending group share is labeled pending and retains its original destination group, user and stable operation ID. Only retry after revalidating current session/membership; do not publish it into a newly joined group. A failure of one storage path cannot claim the other was successful. Loss of membership clears group content; network failure shows stale-state status rather than falsely claiming membership loss.

## Validation and rollout
1. Extend deterministic cross-browser tests to create/join, same-group visibility, private-note exclusion, membership removal, late responses after logout, idempotent retries and concurrent reactions.
2. PostgreSQL tests in a disposable local database: anonymous denial, nonmember and cross-group denial, forged author/role denial, invite expiry/regeneration, join races, author/leader permissions and membership revocation. Test archive retention across the seven-day boundary and no access to private snapshots by peers.
3. Browser tests in Chromium/WebKit: feed/roster order, real completions/glow/unread, preserved drafts/scroll, archive navigation and all current reading/annotation/account regressions.
4. Prepare an additive rerunnable SQL migration, setup instructions and a preview. No live schema execution can be claimed without authenticated backend access; if unavailable the user runs the reviewed SQL in their project.
5. Real two-account acceptance: leader creates group, member joins, both see a new post/reply/Amen/checkin, private note stays private, archived data remains accessible, removed member loses access. Confirm same-account personal roundtrip as well. Keep production deployment pending these real-account results.

## Scope boundaries
No purchases, billing enablement, domain change, Google branding changes, push notifications or global public directory. No rewriting the app into a new framework. No automated publication of historical personal data. Account deletion/privacy policy and production operations remain separate launch work unless added explicitly.

## Independent builder check
A fresh reviewer identified one gap: whether a removed person could use an existing invitation to rejoin. The builder proposal above closes this by blocking rejoin until the leader lifts the group-specific restriction. No other important planning questions were reported.
