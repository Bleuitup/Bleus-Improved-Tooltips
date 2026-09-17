# Hive research slots

Branch `feature/hive-research-slots`, a 1.07 candidate. Designed with the user on 2026-09-16 from
concept sheets v1 and v2, then shaped over five in-game test rounds on 2026-09-17 (history at the
end). **Status: tested in game, not yet published.**

## What it does

A setting, HIVE RESEARCH DISPLAY, picks where research done in hives is shown:

| Mode | Hive status panel row | Research notifications on the left |
| --- | --- | --- |
| 0 NOTIFICATIONS (default) | Busy ring with the DNA glyph, as in 1.06 | As vanilla |
| 1 HIVE PANEL | Up to two research slots, with progress and time left | Research done in hives no longer appears |

A third mode, BOTH (slots and notifications together), was built, tested and dropped on 2026-09-17.
The default stays closest to vanilla.

## Decisions

- **Two slots per hive**, because a hive researches in two places at once: the Hive itself (biomass
  or a hive type upgrade) and the EvolutionChamber it owns (lifeform abilities off the DNA menu).
  Each has its own `ResearchMixin`.
- **Left slot: hive (biomass, hive type). Right slot: evolution chamber (abilities).** A lone
  research always takes the left slot.
- **Each slot is the left part of vanilla's research notification, in miniature**: the ringed
  circle, the socket and progress bar, the icon inside the circle and the countdown under it, at the
  notification's own relative positions, scaled by `IT.kHiveResearchSlotScale = 0.85`. At that scale
  a slot is 75 tall from y 5, filling the hive image (y 6 to 78). Slots at x 139 and 203.
- **The frame is drawn in two pieces**: the circle down to atlas y 72, and the dark backing under the
  countdown squashed from 22 to 14 pixels to suit the smaller countdown. Its width is unchanged: the
  backing's top sits behind the rim inside the first piece, so a narrower lower part would step.
- **Icons use the notification's own per-tech size and position corrections.** Those tables are
  file-local in GUINotificationItem.lua, so the alien entries are copied, keyed by tech name. One
  addition of the mod's own: Biomass One +16 cell pixels, as its three-sphere art read small at 0.85.
  Anything not listed (other biomass researches, modded abilities) is drawn plain, as the
  notification draws it.
- **A countdown under each icon** (`00:17`, the notification's font and color) at 0.64 scale,
  centered under the circle. Progress arrives in whole percent at most once a second, so a slot keeps
  its own estimated finish time and only takes a new estimate when a research starts or the two drift
  more than 2 seconds apart. `IT.kShowHiveResearchSlotTimers = false` removes it.
- **Only hive research moves.** HIVE PANEL filters biomass, the three hive type upgrades and every
  ability in `EvolutionChamber.kUpgradeButtons`. CBM's Advanced (Fortress) upgrades run on the
  structure itself and the Infested Tunnel upgrade on the tunnel, so their notifications stay.
- **Field aliens only.** The panel is shown to `kShowAsClass["Alien"]`; spectators, dead aliens and
  the commander are unaffected, and the filter checks `isa("Alien")`.
- **HIVE PANEL does nothing when the hive status panel is off**, so nothing is hidden without a
  replacement.
- **Hiding a notification hides all of it**: its start, green complete state and red cancel state
  are one item in GUIEvent.
- **Changing mode mid-round rebuilds the stack**: cleared and every research in progress queued
  again through the filter, as `GUIEvent:Initialize` does.

## Vanilla GUIEvent bugs fixed for the alien stack

Both apply in either mode. `ImprovedTooltips_ResearchStack.lua` skips the marine stack, which has
the same bugs (parked, below).

- **The "trait available" sound.** GUIEvent plays it (`TriggerEffects("upgrade_complete")`,
  GUIEvent.lua:348) only for a notification it is showing when the research completes, and aliens are
  shown three. The mod watches research in progress directly and plays the sound once per
  completion, shown or not, silencing GUIEvent's own call while GUIEvent updates. Entities are
  userdata, so the call is silenced on the player's class table, not the player.
- **Research pushed out of the stack.** When a notification sorts above the last one shown, the one
  pushed below the three is faded out, destroyed and dropped from GUIEvent's list, and nothing queues
  it again. After each update the mod re-queues any research in progress that is neither in that list
  nor in the player's queue; it waits below the three and shows when a place frees.

## Why the data comes from the server

Research is only tracked per entity for the techs in `GetTechIdIsInstanced` (TechTree.lua:386); of
the alien ones, just the three hive type upgrades. Biomass and lifeform abilities keep one progress
value per tech, and two hives can research biomass at once. Hives are also not relevant to distant
clients. So the existing `ImprovedTooltipsHiveState` message carries `hiveResearchId`,
`hiveProgress`, `evoResearchId` and `evoProgress` (progress as 0-100).

`ImprovedTooltips_HiveSync.lua` sends a change of biomass or research id at once, and a progress
change at most once a second per location (`IT.kHiveResearchProgressSendInterval`). A research is
only reported while `GetIsResearching` is true.

## Files

| File | Role |
| --- | --- |
| `ImprovedTooltips_HiveState.lua` | Hive state tables; send, broadcast and join resync |
| `ImprovedTooltips_NetworkMessages.lua` | The hive state message and its fields |
| `ImprovedTooltips_HiveSync.lua` | Server: reads both entities' research and progress; throttled sends |
| `ImprovedTooltips_HiveStatusGUI.lua` | The ring, the research slots, and the switch between them |
| `ImprovedTooltips_ResearchNotifications.lua` | Post-hook on `lua/Hud/GUINotificationMixin.lua`: the HIVE PANEL filter |
| `ImprovedTooltips_ResearchStack.lua` | Post-hook on `lua/Hud/GUIEvent.lua`: mode-change rebuild, sound, re-queue |
| `ImprovedTooltips_Config.lua` | `kHiveResearchDisplay` and slot geometry |
| `ImprovedTooltips_ModsMenu.lua` | HIVE RESEARCH DISPLAY combobox, key `BIT_HiveResearchDisplay` |

## Test checklist

Hive status panel on (Advanced Options > UI). Test in vanilla, then CBM.

- **NOTIFICATIONS (default):** ring and DNA glyph on a busy hive, no slots; notifications on the left
  as vanilla.
- **HIVE PANEL, one research:** it takes the left slot, and adds no notification on the left.
- **HIVE PANEL, two at once in one hive:** Biomass left, Metabolize right, neither overlapping the
  biomass icons above or the name plate.
- **Two hives:** each research in its own row.
- **Completion and cancel:** the slot disappears; the sound plays once on completion, never on cancel.
- **CBM:** an Advanced Crag upgrade still appears on the left in HIVE PANEL.
- **Hive status panel off:** notifications on the left as normal in HIVE PANEL.
- **Switching modes mid-research**, both ways: the left stack gains or loses the hive research at
  once, and nothing appears twice.
- **Six researches at once** (three hive type upgrades, three abilities), in NOTIFICATIONS: all six
  appear on the left in turn, and each plays the sound once.
- **Timers:** count down smoothly, and clear the next hive's row.
- **Icon sizes:** Leap, Bile Bomb, Metabolize, Biomass One to Three and a hive type upgrade read about
  the same size inside their circles. On CBM, also Babbler Bomb.
- **Joining mid-round:** rows fill in at once, and no sound plays for research already running.
- **Console:** no script errors.

## Test history (2026-09-17)

1. **First round:** icons small and off center; switching mode mid-research did not change the left
   stack. Fixed with fitted icons and the mode-change rebuild.
2. **Second round:** icons still small; room under the timers. Icons and slots enlarged.
3. **Third round:** keep the notification's circle and outline, use the hive image's full height,
   size icons as the notification does. Slots rebuilt as the notification in miniature.
4. **Fourth round:** order swapped to hive left; Biomass One enlarged; timer 20% smaller; sound missing
   with six researches. Sound taken over for the alien stack. The first attempt shadowed
   `TriggerEffects` on the player with `rawget`, which raises on userdata and threw every update.
5. **Fifth round:** the countdown's backing shortened; with six researches the last three never
   appeared on the left. Dropped research is re-queued.

After the fifth round the BOTH mode was dropped, leaving NOTIFICATIONS as the default.

## Parked: the same vanilla bugs in the marine stack

Both GUIEvent bugs above also affect marines, who are shown five notifications (three with the NS1
HUD bars). Left alone on 2026-09-17 at the user's call. To revisit: remove the `useMarineStyle` gate
in `ImprovedTooltips_ResearchStack.lua` (TriggerEffects already picks the marine sound), or report it
upstream as an issue on the ns2-game repository.
