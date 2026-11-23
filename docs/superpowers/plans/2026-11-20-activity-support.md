# Compact actions, latest-activity feed and in-app support

Latest user steers: replace ALL email delivery with in-app admin problem list (message/who/date, resolved/delete) and home notifications; retain pending compact equal-gap actions, direct-post newest ordering/Share-only label/history, normal group-name body weight. Admin login address provided privately; do not commit it into public repo/client.

Architecture: replace Resend API with authenticated Supabase feedback_read/feedback_action RPCs and protected reports/admin/read tables. Seed admin by verified auth.users email in a private generated SQL copy. No service_role, provider account or mail keys. Source migration uses placeholder only. Existing SQL activity feed sorts replied tier first; update to max(created_at,last_reply_at), id descending, cursor same shape. Preserve5-row UI/ten-row RPC and pull refresh.

1. Tests RED for chronological new post after reply, compact12px action boundaries, plain Share label/history, body group name, private admin list/unread/status/delete/permission boundaries.
2. Update SQL and single upgrade script (new tables/RPCs + existing feed functions), verify isolated Postgres17, no production execution credentials available.
3. UI: compact natural-width actions, plain Share CTA, own-post acknowledgment pin. Feedback ordinary form persists, admin sees paged reports with resolved/delete. Admin-only home tile and navigation/header count. Refresh on explicit/focus/tab/pull; no timer. Preserve account epochs and draft/error handling.
4. Remove mail endpoint/provider setup and tests, replace with DB/auth/UI coverage. Create private ready-to-run migration outside repo using supplied admin email. Need user to run it in Supabase; final required step after code/tests complete.
5. One fresh review, one important-fix pass with regression. Deploy preview, draftPR/main untouched. Do not claim live DB functionality until migration is run.
