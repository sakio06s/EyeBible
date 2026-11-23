# TagBible production release verification

Authorized by the owner after confirming the new domain still served EyeBible v0.9.2. Candidate PR10 is merged with current main in an isolated release worktree. Main daily JSON stays unchanged; existing account/cloud/group/SQL identifiers retained for compatibility. No live SQL, credentials or permissions modified.

Pre-release regression runs cover standalone and Chromium/WebKit UI suites. Daily-preview test initially failed because frozen 2026-11-19 clock read updated main 2026-11-20 fixture, correctly rejected as future. Fix uses deterministic 2026-11-18 fallback and waits for non-legacy reading, rather than checking before loading starts. Corrected test passes both engines. Product fallback code unchanged.

Live importer reproduced missing range and retained old data. Inspected source explicitly announces maintenance. This is an upstream outage, not a repository-rename error. No fabricated replacement daily data published. Supabase public auth settings confirms Google enabled; private redirect whitelist cannot be verified through the public settings endpoint. Google branding and new-origin auth callback acceptance remain manual post-deployment checks.

Final production SHA, public page and deployment checks are recorded in the release report/PR after merge. Database test harnesses were not rerun against production; existing user-confirmed schema retained.

26 standalone/browser scripts passed on the main+candidate tree, plus 11 Python importer tests. Both daily-preview and social fixtures were pinned to valid dates relative to their frozen clocks; corrected fixtures pass Chromium/WebKit. The new TagBible preview origin was also checked separately. Tests depending on disposable PostgreSQL were not rerun in this environment; no SQL change in this release preparation and live DB remains untouched.
