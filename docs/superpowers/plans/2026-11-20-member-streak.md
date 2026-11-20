# Avatar completion streak label

Spec: user wants glowing avatar status 今天已完成 for continuous1–3 days, 持之以恆: X天 for4+ uninterrupted calendar dates through today. X is total, not capped at glow5. Not completed today retains 今天尚未完成. Count Taiwan calendar dates, ignore duplicates/future/malformed dates, stop at first missing day. Historical completion and glow algorithm unchanged. Apply shared cloud roster and local fallback; assistive labels include full streak.

Single task (inline, existing isolated feature checkout):
- Add tests/member-streak.cjs, RED missing4+ status, local+shared real UI both engines; thresholds, long run, gaps/duplicates, new day and gap repair.
- Add completionStreak and memberCompletionStatus shared via existing EyeBibleApp bridge in index.html; use both renderMembers implementations; version0.15.3.
- GREEN new test; social/groups-ui/recent-reading/cloud-devices/presentation/feed-five-ui regression. One fresh independent review and one fix pass; commit/publish preview only; no SQL or main merge.
