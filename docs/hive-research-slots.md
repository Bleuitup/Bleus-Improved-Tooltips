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
- **A countdown under each slot's icon** (`00:17`, the notification's font and color). First
  decided against, then asked for on 2026-09-17 to try; `IT.kShowHiveResearchSlotTimers = false`
  removes it. Progress arrives in whole percent at most once a second, so the slot keeps its own
  estimated finish time and counts down smoothly, only taking a new estimate when a research
  starts or the two drift more than 2 seconds apart.
- **CBM's Advanced (Fortress) structure upgrades are not in the hive panel** and stay on the left in
  every mode, sound included: they are researched on the Crag, Shade, Shift or Whip itself, which
  has no hive row, and the filter only takes hive and evolution chamber research.
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
  completes, so hiding the notification silenced it. `ImprovedTooltips_ResearchStack.lua` remembers
  each hidden research and plays the sound with GUIEvent's own rules: checked from
  `GUIEvent:Update`, progress exactly 1 is complete, neither complete nor in progress is a silent
  cancel. Vanilla only sounds for the 3 notifications on screen; hidden researches always sound.
- **Changing mode mid-round rebuilds the stack.** The filter only sees notifications as they are
  queued, so in the first test (2026-09-17) switching to HIVE PANEL ONLY left existing hive research
  on the left, and switching away never brought hidden research back. `ResearchStack.lua` now
  watches the filter's answer and, when it changes, clears the stack and re-queues every research
  in progress, as `GUIEvent:Initialize` does.
- **Icons are fitted by their drawn shape, not their cell.** The first test showed small, uneven,
  slightly off-center icons: buildmenu.dds cells vary widely (Biomass One's shape is 44px, Leap's
  56x30, Biomass Three's 62x66), and vanilla's per-tech size fixes are private to
  GUINotificationItem.lua. `HiveStatusGUI.lua` carries measured shape bounds per atlas index and
  fits each shape into a box centered on the bar; slots moved to x 136 and 198. After the second test (icons still small, room under the timers) the box became 50x40, the slots x 136 and 208 at y 14, and the timer sits under the icon box rather than the bar. Unlisted
  indices (modded abilities) use a typical 56px centered shape. The table was measured on vanilla's
  atlas; CBM ships its own buildmenu.dds, so check CBM icons in game.

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
| `ImprovedTooltips_ResearchStack.lua` | New. Post-hook on `lua/Hud/GUIEvent.lua`: rebuilds the stack on a mode change, and plays the completion sound for hidden research |
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
- **Switching modes mid-research**, in every direction between the three: the left stack gains or
  loses the hive research at once, and nothing appears twice.
- **Timers:** each slot counts down under its icon without stalling or jumping, agrees with the
  notification's time in BOTH to within a second or two, and never overlaps the next hive's row.
- **Icon sizes:** Leap, Bile Bomb, Metabolize, Biomass One to Three and a hive type upgrade all read
  about the same size and sit centered beside their bar. On CBM, check the same plus Babbler Bomb.
- **Joining mid-round:** rows fill in at once.
- **Devnull's Enhanced HUD:** BOTH and RING ONLY unaffected; check HIVE PANEL ONLY still filters.
- **Bars at real size:** the bar reads as progress and the icon is legible at 1080p.
- **Console:** no script errors.

## Third in-game test (2026-09-17)

The slot became **the left part of vanilla's research notification, in miniature**: the ringed
circle (frame cropped at x 72, where the rim ends and the name plate would begin), the socket and
bar, the icon inside the circle and the countdown under it, all at the notification's own relative
positions, scaled by `IT.kHiveResearchSlotScale = 0.85`. Asked for by the user, who wanted the circle
and outline kept, and the full height of the hive image used rather than the band under the name
plate: at 0.85 a slot is 75 tall from y 5, against the hive image's 6 to 78. Slots at x 139 and 203.

Icon sizing now copies GUINotificationItem's own per-tech corrections (its size and position offset
tables are file-local, so the alien entries are copied, keyed by tech name), replacing the measured
shape table. A tech it does not list - every biomass research, and modded abilities - is drawn plain,
exactly as the notification draws it. Mockup: scratchpad `hive/row_mock.png`.
