# Export dependencies

PDF: pdf-lib 1.17.1 and @pdf-lib/fontkit 1.1.1 browser distributions, downloaded from their npm release tarballs. Both MIT; license notices are beside the bundles (fontkit upstream license from foliojs/fontkit).

Chinese font: Noto Sans TC from google/fonts ofl/notosanstc/NotoSansTC[wght].ttf, source SHA256 864727d210d54f2537bbe23b3a839436c3992af72de9322af5270897246bd44f. Instanced at wght=400 with fontTools, with static Regular naming, retaining its OFL notice in fonts/OFL.txt. Only loaded for PDF generation. The complete static font is embedded (about 4.4 MB compressed per PDF) because fontkit runtime subsetting produced invisible CJK glyphs despite correct extracted text. Rendering and text extraction are both regression-tested. Unsupported glyphs (e.g. color emoji) use the device's local font rendering as inline images; surrounding PDF text stays searchable.

No document text is sent to these upstream services; all runtime assets are served from this site. DOCX uses a small local OOXML/ZIP writer with no external dependency.

SHA256 of shipped assets:

- study/vendor/pdf-lib-1.17.1.min.js: 0f9a5cad07941f0826586c94e089d89b918c46e5c17cf2d5a3c6f666e3bc694f
- study/vendor/fontkit-1.1.1.min.js: d8df561b9fba98e24f2e5130e40948809281bbbc55a20c412359f1a0a5eb35a6
- study/fonts/NotoSansTC-Regular.ttf: 9a458c49fc6cbb60e8e6cb06abf75ec057fc8202ff658b207b0950f56f00e981
