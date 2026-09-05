# Hive HUD research display — plan

Branch `feature/hive-hud-research`, cut from `release/1.01`. Nothing implemented yet.

Covers three requests that are really one redesign of how the top-left hive panel shows research.

All line numbers refer to `D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua` unless the
path says otherwise.

## The rule this settles

Today the panel shows a DNA glyph inside a rotating ring for **any** research at all — biomass, a
lifeform ability, or a hive type upgrade — because that is all the data it has. After this, each
kind of research is shown as the thing it actually is:

| Research | Shown as |
|---|---|
| Biomass | The next biomass icon filling as the work goes in |
| Hive type (Crag / Shade / Shift) | The type icon on the hive element, loading round like a cooldown dial |
| Lifeform ability | DNA glyph in the rotating ring — kept, and now exclusive to this |

The DNA ring stops meaning "busy" and starts meaning "the evolution chamber is working", which is
what it depicts. That is the point of the change, not a side effect.

## The blocker: the message carries a boolean

`ImprovedTooltips_NetworkMessages.lua` defines the hive state message as `locationId`, `biomass`,
`researching` (boolean) and `clear`, with the comment "Deliberately not which one, and not a
progress fraction - the HUD only shows that the hive is busy."

Both of the new behaviours need more than that:

- Which research is running, to tell biomass from a hive type upgrade from an ability, and to pick
  the right hive type icon.
- A progress fraction, for the biomass fill and the type dial.

So this branch has to extend that message and the server side that fills it —
`ImprovedTooltips_HiveState.lua`, `_HiveSync.lua` and `_HiveJoin.lua`. That is the bulk of the work
and the part most likely to need care: the message is also replayed on team join.

**Why it cannot be read on the client instead:** a Hive is only relevant within 40m
(`ScriptActor` sets `kMaxRelevancyDistance`), so `bioMassLevel` and `researchingId` are unreadable
on a field alien's client for exactly the hives this panel is about. That is why the message exists.
See the hive HUD section of `CLAUDE.md`.

Suggested fields, keeping the existing ones: `researchId = "enum kTechId"` and
`researchFraction = "float (0 to 1 by 0.01)"`. Zero and `kTechId.None` mean idle, so `researching`
becomes redundant and can go — check `_HiveJoin.lua` before removing it.

**Where the values come from, already established:** `hive.biomassResearchFraction` is a plain
server field written only while a biomass research is running, and `GetResearchingId()` names what
is running. Lifeform abilities are researched on the **evolution chamber**, not the hive
(`Hive.lua:159`), reached through `hive:GetEvolutionChamber()` — `Hive:GetIsResearching()` is false
during Leap or Metabolize. All three are in `CLAUDE.md`.

## 1. Biomass icons — bigger, and showing progress

Current sizing in `ImprovedTooltips_Config.lua`: `kHiveBiomassIconSize = 18`,
`kHiveBiomassIconSpacing = 19`, origin `Vector(140, -13, 0)`.

"Ever so slightly larger" against a row that is 228x50 with the name plate running to x=135. With
twelve possible icons at 19px spacing the row already runs to 140 + 12*19 = 368, well past the row
width, so the count in practice is what keeps it inside. **Check the widest realistic case — a hive
at biomass 5 under CBM — at the smallest supported resolution before settling on a size.**

The in-progress icon is the next one after those completed, drawn the same way the tech map draws a
node in progress. `release/1.01` already has the pattern to copy in
`ImprovedTooltips_BiomassOverlay.lua`: the icon lit in
`kTechMapIconColors[kAlienTeamType][kTechStatus.Available]` with a progress meter under it.

## 2. Hive type research — a loading dial

Vanilla shows the type icon only once the upgrade completes. It should appear while researching and
rotate like the commander cooldowns until it does.

The mod already does exactly this: `GUIImprovedTooltipsCooldowns.lua` drives vanilla's `GUIDial`
with `ui/{marine,alien}_command_cooldown.dds`, configured as in `GUICommanderButtons.lua:75-118`.
`CLAUDE.md` records the anchoring trick — Left/Bottom with a zero offset over an equally sized
parent, because `GUIDial:Initialize` applies its own `-BackgroundHeight` offset.

Existing geometry to fit around: hive type icon 39x36 at (52, 7), hive icon 75x72 at (69, 6).

## 3. DNA ring becomes ability-only

`kShowHiveResearchIcon` currently fires for any research. It should fire only when the evolution
chamber is the thing researching. Position and size stay as they are
(`kHiveResearchIconPosition`, `kHiveResearchIconSize`, `kHiveResearchDnaScale`), so this is a
condition change rather than a layout one.

## Test checklist

- Two hives researching different things at once, one biomass and one hive type.
- A biomass research and a lifeform ability at the same time on the same hive — the evolution
  chamber runs independently of the hive, so both indicators should show.
- A hive type upgrade from start to finish: dial fills, then the plain icon remains.
- A research cancelled part way.
- A hive dying mid-research, and a hive still under construction.
- Joining the team mid-round, which replays the state — the most likely place for the extended
  message to be wrong.
- CBM, where biomass 5 exists and the icon count is one higher than vanilla's.
