# TagBible HTML rename — v0.15.6

User replaced the abandoned daymarkbible working name with TagBible, HTML first. Updated app title, welcome/header wordmarks, accessible labels, dynamic login title, backup filename and about/privacy/terms. Uses the supplied latest TagBible artwork unchanged; SHA256 945f487d7645bc42cd49af4dfa2bc194b22e18cd97e2401e744107514d99c59d. SVG clipping presents only the English wordmark, with render-time background removal and the existing dark-theme treatment. No subtitle or slogan added.

Preserved original storage keys, JS bridges, APIs, SQL, callback URLs, account/project names and existing data. Production remains paused. Older artwork and historical verification records remain as history, with no active UI reference.

Chromium/WebKit brand test passes after final clipping fix: titles and login copy, logo source, mobile geometry at 320/390/490 in both themes, old notes/checkins/highlights, backup contents and a newly saved note surviving navigation without reseeding. Final 320px light/dark screenshots inspected: full TagBible glyphs, no book fragment or pale rectangle, no avatar overlap.

10 scripts passed: brand-rename, public-info, presentation, interface, refinements, social, cloud-devices, groups-ui, google-login and annotations. Static asset allowlist and git diff whitespace checks passed. No live database or OAuth-setting changes.
