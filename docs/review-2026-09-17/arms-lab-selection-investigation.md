# Arms Lab deselection near research completion — investigation

Reviewed 2026-09-17; world-click follow-up and expanded probe 2026-09-18. **Status: player-reported, not reproduced or source-confirmed.**

Reported behavior: a commander clicks an Arms Lab near the end of research (for example Armor 1); when the research finishes, the Arms Lab becomes deselected.

The user confirmed this means clicking the building in the world as a commander. Mouse-release timing, server/mod combination, and whether the selection ring disappears are not yet confirmed. Do not turn the hypotheses below into an asserted root cause or claim reproduction in CBM.

## What the source establishes

References below use installed vanilla build 344.3521, under:
D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua.

- Ordinary world selection starts on **mouse-down**, not mouse-up: Commander_MouseActions.lua:23–81,96–108. A normal click deselects the previous selection and then selects the hit entity.
- SelectableMixin.lua:84–136 updates the client selection cache and sends the selection request. NS2Utility.lua:437–459 switches the menu to RootMenu when an entity is selected.
- Research completion follows ResearchMixin.lua:60–94 -> the deferred completion queue in TechTree_Server.lua:577–626 -> PlayingTeam.lua:328–370 -> ResearchMixin:TechResearched at 348–419. For Armor 1 there is no manufacture/replacement entity.
- The Arms Lab has no class-specific completion handler. It inherits RecycleMixin:OnResearchComplete (58 onward), whose destructive work is guarded by researchId == kTechId.Recycle; Armor 1 does not enter that branch.
- ResearchMixin:ClearResearch (180–189) clears research fields, not selection.
- The command menu deliberately changes from Cancel to Recycle when research reaches 100% (Commander.lua:352–406; ResearchMixin:GetIsResearching at 191–201). That refresh does not itself deselect the building in the inspected code.
- A client's selected state can differ temporarily from the replicated server mask. SelectableMixin:GetIsSelected reads the client cache; the periodic client update (220–242) resends a selection request when the masks disagree. A stale server mask by itself is insufficient to establish a deselection bug.
- Completion alerts go through PlayingTeam:TriggerAlert and Player:TriggerAlert, which send a minimap alert. No direct Arms Lab deselection was found in that route.
- ArmsLab:OnTag handles deploy_end by setting its deployed flag. ArmsLab:OnUpdateRender and CommanderGlowMixin update visual effects; no selection mutation was found there. The engine's compiled animation graph was not simulated.
- Bleu's current selection-panel hook changes health/armor artwork only. This does not rule out other interactions among HUD mods.

## Checks and results

[arms-lab-selection-probe.lua](arms-lab-selection-probe.lua) runs actual loaded research and selection functions with engine-facing dependencies stubbed. [Saved output](arms-lab-selection-probe-results.txt).

| Source | Result in this isolated check |
| --- | --- |
| Installed vanilla | Selection preserved |
| Installed CBM release | Selection preserved |
| Local CBM dev | Selection preserved |
| Ghoul's NS2 beta source | Selection preserved |

The check covers clicking just before completion, reaching 100%, applying research-field updates to the client, final completion/cleanup, clicking again afterward, and an explicitly injected stale server selection mask. It also checks Cancel -> Recycle and verifies that a deliberate deselection is detected.

The follow-up loads the actual vanilla Commander:SetCurrentTech, left mouse-release callbacks, Commander_MarqueeSelection, Commander_Selection and GetSelectablesOnScreen functions. A stationary release before or after completion preserves selection. Moving exactly 5 pixels also preserves it. A 6-pixel drag whose small rectangle excludes the building's projected origin clears selection on release, both when research finishes and when it does not. That establishes an alternative input path, not the cause of the reported completion timing.

**Limits:** this is Lua 5.4, not the game's Lua 5.1/LuaJIT. It uses separate stub client/server objects, directly dispatches the completion callback, and stubs engine ray hits and world-to-screen projection. The world-input/menu-setting callbacks are from vanilla, combined with each variant's research/selection/Arms Lab/utility sources; this is not a complete mounted CBM session. It does not simulate engine replication, actual packet ordering, rendering/animation, the complete team callback chain, MouseTracker event dispatch, or the full GUI lifecycle. This is a negative check of a simple explanation, not proof that the reported bug cannot occur.

To rerun, use C:\Users\maost\AppData\Local\Programs\Lua\bin\lua.exe with the probe path followed by four arguments:

1. D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua
2. D:\SteamLibrary\steamapps\workshop\content\4920\2934445221\lua
3. G:\My Drive\[01] Martin\[03] Gaming\NS2 Server\Workshop Mods\Community Balance Mod (dev)\lua
4. C:\Users\maost\AppData\Local\Temp\bleu-ui-audit-20260917

The beta inputs are cached source files, not vendored game code. If absent, retrieve ArmsLab.lua, ResearchMixin.lua, SelectableMixin.lua and NS2Utility.lua from the pinned beta commit below, using filenames ns2-beta-<name>.lua.

## Upstream and CBM comparison

- [NS2 master, inspected revision](https://github.com/GhoulofGSG9/ns2-game/tree/14508c8ed2b4c43b9ebf0ea300ca31e6430ef2bf): the nine compared Arms Lab/research/selection/menu files match the installed vanilla Git blob hashes.
- [NS2 beta, inspected revision](https://github.com/GhoulofGSG9/ns2-game/tree/bc7bb36d54d0ab5f63ee1aaf3ecf046f2019cdae): Commander_MouseActions.lua and Commander_Selection.lua are unchanged from vanilla. The inspected changes to ArmsLab.lua and ResearchMixin.lua concern animation/rendering and the blowtorch mixin; SelectableMixin changes do not add an Arms Lab completion fix. Menu changes concern passive button states.
- The same world-click/selection files are unchanged on the checked hotfix-344, bdt-344 and both v344.1-CBM-core branches.
- [CBM main, inspected revision](https://github.com/GhoulofGSG9/CommunityBalanceMod/tree/9c4ae8a769340b1854ab7cfe5c9fe8dfd159fc1a): its ResearchMixin matches the beta source blob. Local CBM release/dev selection and research functions also preserve selection in the limited probe.
- Refreshed open/closed issue and PR title/body search found no match for this specific timing. [#92](https://github.com/GhoulofGSG9/ns2-game/pull/92) and [#71](https://github.com/GhoulofGSG9/ns2-game/pull/71) concern mixed group selection, cancel-button availability and movement formation. They do not describe this report. This is not an exhaustive search of every historical comment or external tracker.

These comparisons establish no obvious fix in the inspected paths. They do **not** establish that the bug reproduces on each branch.

## Focused in-game reproduction still needed

Use ordinary research; no cheat/testing console commands are necessary.

1. Start Armor 1. Select the lab well before completion and leave the mouse alone through completion. Record whether both the selection ring and structure command panel remain.
2. Repeat with another available armor/weapon research, selecting the world building during the final second. Release the button before completion and keep the pointer stationary.
3. Separately, hold the click across completion, then release. Record whether the change occurs at 100%, on mouse release, or after another click.
4. Record the build, server mods and client HUD mods; compare vanilla/CBM once the original sequence is reproducible.

Watch the **selection ring and command panel separately**. A ring that remains with a menu that changes suggests a different fault from selection being cleared.

One input path to rule out: movement greater than 5 pixels while holding the left button starts marquee selection (Commander_MouseActions.lua:84,151–165). On release, marquee selection can replace the original click selection (Commander_Selection.lua:100–130). This behavior was reproduced in the source probe, **not demonstrated as the explanation** for the reported research timing.

If it reproduces with a clean stationary click, the next useful step is a temporary diagnostic recording entity ID, research state, client/server selection masks, menu ID, and call stacks for selection changes around completion. Do not deploy a fix that forcibly reselects the lab: it could override intentional player input and conceal the cause.

No production mod/game files were changed and no issue was posted. Keep this investigation separate from the source-confirmed upstream drafts.
