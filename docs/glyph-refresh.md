# Glyph refresh

For 1.06. Approved by the user on 2026-09-15 ("Love it") after a review done with ChatGPT Codex;
integrated into `tools/build_icons.ps1` the same day.

The original handoff, preview images and preview builders are outside the repo, in
`G:\My Drive\[01] Martin\[07] Claude Code\Glyph Consistency Review\` (`HANDOFF.md`,
`build_preview.ps1`, `build_resized_preview.ps1`, `resized-glyphs-and-flat-speed.png`,
`candidate-resized-flat-speed.png`, `original-atlas.png`). This file records what was decided.

## Approved

- **Hourglass:** uniformly reduced to 88% of the glow version (12% smaller). Aspect ratio and details
  kept; never widened.
- **Hourglass sand (follow-up, 2026-09-15, picked "B" from a sheet of glowed candidates):** the
  lower mound drops from a peak at y 42 to a 3px hump at y 48.5 (base 22.5-41.5), and the stream is
  lengthened to reach it. With the glow the old mound bled into the bottom cap and the lower bulb
  looked full. The approved candidate image predates this, so cell 0 no longer matches it; cells 1-6
  still do.
- **Stopwatch:** uniformly reduced to 93% (7% smaller). Hands at 12 and 3, crown, and the external
  45-degree start button kept.
- **Marine speed:** smaller, thinner, flat double chevrons replacing the beveled vanilla-derived
  chevron, with the same soft glow. This supersedes the earlier "do not change marine speed".
- **Glow** on all three: a soft vanilla-style halo.
- **Unchanged:** health and armor (pixel-for-pixel, the benchmark), alien speed (vanilla's Celerity
  icon, not in this sheet) and the ready / not-ready pips.

## Recipe

Glow, per 64px cell, from the alpha mask:

```
core  = 0.4 * mask + 0.6 * GaussianBlur(mask, 0.70)
halo  = GaussianBlur(mask, 2.5)
alpha = core + 0.85 * halo * (1 - core)      outer texel ring forced to 0
```

RGB stays white for the runtime team tint.

Order: the hourglass and stopwatch are glowed at full size and the result scaled into the cell,
centered; the marine chevrons are drawn at 4x (`(18,13)->(28,32)->(18,51)` and
`(32,13)->(42,32)->(32,51)`, 5.2px pen, flat caps, round joins), scaled into the cell, then glowed.

## Sizing

Health and armor are sampled through a 48px window of their cell; the custom glyphs through the full
64px cell (`kOwnIconCoords`). Judge optical size through those windows, not raw atlas bounds. The 32px
samples in the review images are a comparison reference, not a game size.

## Verification (2026-09-15)

| Check | Result |
| --- | --- |
| Unchanged builder vs shipped atlas (`original-atlas.png`) | 0 px differ |
| Updated builder vs approved `candidate-resized-flat-speed.png` | 0 px differ |
| Decoded `source/ui/bleu_tooltip_icons.dds` vs approved candidate | 0 px differ |
| Cells 3-6 before vs after the refresh step | identical (the build throws otherwise) |

## Still to do

- The Workshop slide review set (`...\Improved Tooltips Images\Workshop Slides 1.05 Review`) predates
  this and shows the old glyphs.
