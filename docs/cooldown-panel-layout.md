# In Cooldown panel: grid and marine backdrop

For 1.08. Built 2026-09-25; awaiting the user's in-game test. Chosen from a rendered concept sheet
(scratchpad `cdmm/concept_cooldowns.png`, built by `cdmm/render_cooldowns.ps1` from the game's own
textures, fonts and smoke shader).

## The problem

The panel is anchored right-center at offset (-210, -120), so its left edge sits 210 px from the
right of the screen. Three entries are 192 px wide and fit; a fourth ran 42 px off the screen, a
fifth 102 px. At the default 5 second cut-off aliens can already reach four at once (Shade Ink 15,
Hallucinate 12, Bone Wall 10, Heal Wave 6); a lower cut-off lets Rupture, Hatch, Contamination and
others in.

Marines had no backdrop at all, where aliens have the commander smoke.

## What was chosen (user, 2026-09-25)

- **A2: three to a row, short last row centered.** The top edge stays where it was; the panel grows
  downward. Both teams, no setting.
- **Smoke refitted.** The smoke mask's solid oval covers 16-84% of its width and 26-59% of its height,
  centered 42% down. The old sizing (1.6 x width, 2.2 x height, centered on the texture) left the
  bottom row on the fading edge, worse with two rows. Now 1.7 x 2.9 with the mask's own center on the
  panel. This also changes the one-row panel slightly. It was shown in the chosen A2 render but not
  asked as a separate question.
- **M2: the commander selection panel's plate** (`marine_commander_textures.dds` 466,0 - 778,250,
  `GUISelectionPanel.kSelectionTextureCoordinates`) behind marine panels: the same scanlines and
  frame as the selection panel. Nine-sliced (34 texel border drawn at 17 px) so the frame and the cut
  corner keep their shape; it reaches 8 px past the sides and bottom and 12 px above so the title
  sits inside.

Rejected: A1 (short row left), M1 (HUD scanline glow), M3 (tooltip box), no backdrop.

## Test checklist

To get many cooldowns at once, set the cut-off to 0 in the Mods panel and cast several abilities.

- Aliens, 1 to 3 abilities: one row, smoke around the whole panel, nothing off screen.
- Aliens, 4 to 6: two rows, short row centered, smoke covering both rows.
- Marines, Nano Shield and Power Surge: plate behind the panel, title inside the frame, cut corner
  bottom-left, frame edges crisp.
- Marines with four or more (low cut-off): plate grows with the second row.
- Resolution change and team switch: panel rebuilt with the right backdrop.
