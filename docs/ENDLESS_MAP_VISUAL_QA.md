# Endless Map Visual QA

Captures were produced by `scripts/capture_endless_visual_qa.ps1` after the final presentation fixes and manually inspected. The images are retained under `build/visual-qa/endless/` for this review.

## Map and Stage presentation

| Screen | Capture |
| --- | --- |
| Map 1 with unknown destination, 1280×720 | [Minimum desktop](../build/visual-qa/endless/map1-unknown-minimum/1280x720.png) |
| Map 1 with unknown destination, 1600×900 | [Desktop](../build/visual-qa/endless/map1-unknown-mid/1600x900.png) |
| Map 1 with unknown destination, 1920×1080 | [Desktop](../build/visual-qa/endless/map1-unknown/1920x1080.png) |
| Map 1 with unknown destination, 2560×1440 | [Large desktop](../build/visual-qa/endless/map1-unknown-large/2560x1440.png) |
| Map 1 with unknown destination, 2400×1080 | [Landscape mobile](../build/visual-qa/endless/map1-unknown-mobile/2400x1080.png) |
| Map 1 with unknown destination, 2340×1080 | [Landscape mobile](../build/visual-qa/endless/map1-unknown-mobile-2340/2340x1080.png) |
| Map 1 Stage 6 boss | [1920×1080](../build/visual-qa/endless/map1-stage6-boss/1920x1080.png) |
| Revealed Map 2 | [1920×1080](../build/visual-qa/endless/next-map-reveal/1920x1080.png), [2400×1080 mobile](../build/visual-qa/endless/next-map-reveal-mobile/2400x1080.png) |
| Map 2 visited trail | [1920×1080](../build/visual-qa/endless/map2-visited-trail/1920x1080.png), [2400×1080 mobile](../build/visual-qa/endless/map2-visited-trail-mobile/2400x1080.png) |
| Long visited trail, latest page | [2560×1440](../build/visual-qa/endless/long-map-trail-latest/2560x1440.png), [2340×1080 mobile](../build/visual-qa/endless/long-map-trail-mobile/2340x1080.png) |
| Long visited trail, earlier page | [1920×1080](../build/visual-qa/endless/long-map-trail-earlier/1920x1080.png) |
| 120-digit map-depth display | [1920×1080](../build/visual-qa/endless/deep-counter-format/1920x1080.png) |

## Resume and death summary

| Screen | Capture |
| --- | --- |
| Resume Run on title screen | [1920×1080](../build/visual-qa/endless/resume-run-title/1920x1080.png), [2400×1080 mobile](../build/visual-qa/endless/resume-run-title-mobile/2400x1080.png) |
| Confirm replacement of active run | [1920×1080](../build/visual-qa/endless/new-run-confirmation/1920x1080.png) |
| Run summary | [1920×1080](../build/visual-qa/endless/run-summary/1920x1080.png), [2400×1080 mobile](../build/visual-qa/endless/run-summary-mobile/2400x1080.png) |
| Run summary with long build | [1920×1080](../build/visual-qa/endless/run-summary-long-build/1920x1080.png), [2340×1080 mobile](../build/visual-qa/endless/run-summary-long-build-mobile/2340x1080.png) |

## Review notes

- Map 1 presents only its current node and one unknown `?`; the new theme remains hidden until the map-completion reveal.
- Stage 6 is visibly marked as the boss stage. The reveal, resume and death-summary screens retain the established interface styling and fit both desktop and landscape mobile captures.
- Long histories page through five readable nodes. Review found the original page-range text overlapped its previous-page control; the spacing was corrected and the 15-map capture regenerated.
- The very deep map badge now uses a compact exponent label, while the complete depth remains in the map header. The stage counter and run summary remain readable at large map numbers.
- The long-run summary fixture was corrected to 81 cleared stages for 13 completed six-stage maps plus three stages on Map 14.
