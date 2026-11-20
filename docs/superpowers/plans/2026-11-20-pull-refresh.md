# Pull to refresh and inline Amen count

User confirms scrolling; remove5s polling and refresh when pulling down again at top. Keep immediate own-operation sync and existing initial/focus/online recovery. Count spacing must equal inline Reply number without reintroducing reaction layout jumps.

- Add failing Chromium/WebKit spacing/no-timer/pull tests; retain previous feed regressions via explicit focus refresh fixture helper.
- Put Amen count inline in a reserved-width label: ordinary space after 阿們, trailing reservation retains stable action width.
- Main-only single-touch pull, only group page at scrollTop<=1, reject focused text editing, horizontal/upward/multi/cancel gestures. Trigger on release after72px. Non-passive touchmove prevents browser bounce only after vertical pull intent. Fixed status overlay has no flow height. Serialize gestures; failed reads preserve data and allow retry. Reset gesture on session/tab change.
- Remove5s interval entirely, preserve five-row expansion on refresh. Keep own mutations/focus/reconnect existing sync. No SQL.
- Targeted pull/feed/group regressions, one fresh review, fix Important findings once, publish preview v0.14.2 only.
