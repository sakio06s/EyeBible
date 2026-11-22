# daymarkbible HTML rename verification — 2026-11-22

Preview version 0.15.5. Supplied original artwork preserved byte-for-byte (SHA256 c9458e4e48d935e72efb760697afd531d0b6f4abf9063c7d2831c89e78b08bd3). SVG clips the English wordmark and removes the pale backdrop at render time. No generated replacement or Chinese subtitle.

Changed visible branding on welcome/header/login/about/privacy/terms, browser titles, accessible names and backup download filename. Internal storage keys, JS bridges, account/group APIs, SQL, callbacks and deployed service names remain unchanged. Production publication and the earlier legal-only PR remain paused.

## Evidence

New browser test initially failed on old EyeBible title. After implementation, Chromium and WebKit pass with the real account script and mock auth endpoint. Tests cover existing local notes/checkins/highlights, backup contents, dynamic login heading, info pages and header geometry at 320/390/490 in light/dark themes.

Review identified that recurring setup could hide persistence failures. Fixed by seeding once on an inert same-origin page, then adding and saving a new note before navigating away and returning. Both engines pass old-state and newly persisted-note assertions without reseeding.

15 regression scripts passed: brand-rename, public-info, presentation, interface, refinements, social, cloud-devices, groups-ui, google-login, login-mobile, annotations, recent-reading, recent-reading-edges, member-streak, composers-feedback. The corrected brand-rename test was rerun and passed on both engines.

Manually inspected 320px light/dark header screenshots and dark about-page screenshot: recognizable supplied glyphs, no pale rectangle, no header/avatar overlap. Automated transparency assertion covers the SVG container; pixel appearance was checked visually rather than inferred from that assertion. Artwork is the original approximately 1.7 MiB PNG, so first load may cost more bandwidth than an optimized standalone logo.

No live auth settings, production data or database migrations were changed. Preview deployment must be confirmed separately after commit.
