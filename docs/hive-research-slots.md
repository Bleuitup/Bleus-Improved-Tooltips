# Hive research slots

Branch `feature/hive-research-slots`, a 1.07 candidate. Designed with the user on 2026-09-16 from
concept sheets v1 and v2. **Status: written, never run.** `luac -p` passes on every changed file.

## What it does

The alien hive status panel (top left, Advanced Options > UI > hive status) can show what each hive
is researching, in that hive's row, instead of only a busy ring. A new setting, HIVE RESEARCH
DISPLAY, picks one of three modes:

| Mode | Hive row | Research notifications on the left |
| --- | --- | --- |
| 0 RING ONLY | Busy ring with the DNA glyph, exactly as in 1.06 | Unchanged |
| 1 BOTH (default) | Up to two research slots | Unchanged |
| 2 HIVE PANEL ONLY | Up to two research slots | Research done in hives no longer appears |

BOTH is the default so nothing vanilla is lost; players choose RING ONLY or HIVE PANEL ONLY.

## Decisions

- **Two slots per hive**, because a hive researches in two places at once: the Hive itself (biomass
  or a hive type upgrade) and the EvolutionChamber it owns (lifeform abilities off the DNA menu).
  Each has its own `ResearchMixin`.
- **Left slot: evolution chamber. Right slot: hive.** A lone research always takes the left slot.
- **The slot shows the research's own icon** (Leap, Metabolize, Biomass, Crag Hive), not the DNA
  glyph. The DNA glyph remains only in RING ONLY.
- **Progress uses the research notification's own vertical bar art** (`ui/research_notifications.dds`,
  alien socket and bar), filled the way GUIEvent fills it, including the glow handling. No new art.
- **No countdown in the row.** Times stay in the notifications.
- **Only hive research moves.** HIVE PANEL ONLY filters biomass, the three hive type upgrades and
  every ability in `EvolutionChamber.kUpgradeButtons`. CBM's Advanced Crag, Shift, Shade and Whip
  upgrades run on the structure itself, the Infested Tunnel upgrade on the tunnel, so their
  notifications stay on the left.
- **Field aliens only.** The panel is shown to `kShowAsClass["Alien"]`; spectators, dead aliens and
  the commander are unaffected, and the filter checks `isa("Alien")`.
- **HIVE PANEL ONLY does nothing when the hive status panel is off**, so nothing is hidden without a
  replacement.
- **HIVE PANEL ONLY hides the whole notification**: start, the green complete flash and the red
  cancel state share one item in GUIEvent. **The "trait available" sound is kept.** GUIEvent plays
  it itself (`TriggerEffects("upgrade_complete")`, GUIEvent.lua:348) when a notification it shows
  completes, so hiding the notification silenced it. `ImprovedTooltips_ResearchSound.lua` remembers
  each hidden research and plays the sound with GUIEvent's own rules: checked from
  `GUIEvent:Update`, progress exactly 1 is complete, neither complete nor in progress is a silent
  cancel. Vanilla only sounds for the 3 notifications on screen; hidden researches always sound.

## Why the data comes from the server

Research is only tracked per entity for the techs in `GetTechIdIsInstanced` (TechTree.lua:386); of
the alien ones, just the three hive type upgrades. Biomass and lifeform abilities keep one progress
value per tech, and two hives can research biomass at once. Hives are also not relevant to distant
clients. So the existing `ImprovedTooltipsHiveState` message gains four fields:
`hiveResearchId`, `hiveProgress`, `evoResearchId`, `evoProgress` (progress as 0-100).

`ImprovedTooltips_HiveSync.lua` sends a change of biomass or research id at once, and a progress
change at most once a second per location (`IT.kHiveResearchProgressSendInterval`). A research is
only reported while `GetIsResearching` is true, the same rule the ring always used.

## Files

| File | Change |
| --- | --- |
| `ImprovedTooltips_HiveState.lua` | State tables with the two slots; send, broadcast and resync take a state table |
| `ImprovedTooltips_NetworkMessages.lua` | Four new message fields |
| `ImprovedTooltips_HiveSync.lua` | Reads both entities' research and progress; throttled progress sends |
| `ImprovedTooltips_HiveStatusGUI.lua` | Research slots, and the mode switch between ring and slots |
| `ImprovedTooltips_ResearchNotifications.lua` | New. Post-hook on `lua/Hud/GUINotificationMixin.lua` for HIVE PANEL ONLY |
| `ImprovedTooltips_ResearchSound.lua` | New. Post-hook on `lua/Hud/GUIEvent.lua`: the completion sound for hidden research |
| `ImprovedTooltips_FileHooks.lua` | Registers both |
| `ImprovedTooltips_Config.lua` | `kHiveResearchDisplay` and slot geometry |
| `ImprovedTooltips_ModsMenu.lua` | HIVE RESEARCH DISPLAY combobox, key `BIT_HiveResearchDisplay` |

## Test checklist

Hive status panel on (Advanced Options > UI). Test in vanilla, then CBM.

- **BOTH, evolution only:** research Leap. Leap icon and a filling bar in the hive's left slot; the
  notification on the left as usual.
- **BOTH, hive only:** research Biomass. Biomass icon in the left slot.
- **BOTH, both at once:** research Biomass and Metabolize in the same hive. Metabolize left,
  Biomass right. Neither overlaps the biomass icons above or the name plate.
- **Hive type upgrade:** upgrade to a Crag Hive; its icon uses the right slot beside a lifeform
  research, or the left slot alone.
- **Two hives:** biomass in one hive and an ability in another, each in its own row.
- **Completion and cancel:** the slot disappears when a research finishes or is cancelled.
- **RING ONLY:** identical to 1.06 - ring and DNA glyph, no slots.
- **HIVE PANEL ONLY:** a new hive research adds no notification on the left; the row shows it.
- **HIVE PANEL ONLY sound:** the "trait available" sound plays once when that research finishes,
  and not at all when it is cancelled.
- **HIVE PANEL ONLY with CBM:** an Advanced Crag upgrade still appears on the left.
- **HIVE PANEL ONLY with the hive status panel off:** notifications on the left as normal.
- **Switching modes** in the Mods panel applies immediately.
- **Joining mid-round:** rows fill in at once.
- **Devnull's Enhanced HUD:** BOTH and RING ONLY unaffected; check HIVE PANEL ONLY still filters.
- **Bars at real size:** the bar reads as progress and the icon is legible at 1080p.
- **Console:** no script errors.
