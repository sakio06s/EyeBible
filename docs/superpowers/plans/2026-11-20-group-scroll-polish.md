# Group scrolling and action sizing

User spec: return Amen text/heart to the size and alignment of Reply/View verse; remove group title; composer 我要分享...; reading CTA 小組互動; save label 儲存/分享; shrink and place version away from avatar; investigate gestures and explain five-second polling costs.

Implementation choice: use one main vertical scroller for the group page, with natural-height feed and members after explicit 5-row load-more. Previously chosen inner scrolling addressed automatic infinite loading; with explicit expansion it now causes unnecessary gesture handoff. A contained inner scroller would still require users to aim outside the feed to reach members. Main-only scrolling is consistent across content and whitespace; each expansion moves members after the added posts. Keep main position and keyed article anchors on background updates; own acknowledged reply navigates to its pinned thread. Avoid changing scroll on background renders of a hidden group tab. Native textarea scrolling remains independent while editing.

1. Add failing mobile Chromium/WebKit tests for equal font/SVG/action centers, single scroller from feed and page whitespace, no window scroll, no automatic load, copy and avatar/version geometry at320/390/desktop.
2. Override inherited19px spans explicitly; 13px label, 14px SVG, 42px tap target. Remove nested overflow and update scroll anchoring/pinning/read visibility without compromising reactions/drafts.
3. Inline compact version into header flex before avatar; replace requested copy and remove heading; keep five-second schedule and existing hidden-page pause.
4. Verify existing feed/group/account/annotation regressions and one fresh final review. Deploy preview only, no SQL, keep main untouched. Explain polling load720 checks per hour per visible device (more with expanded pages), latency/network/battery and free quota consumption. No pricing changes claimed.
