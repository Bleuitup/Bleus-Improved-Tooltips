# Lost arms lab upgrades — plan and implementation

Branch `feature/armslab-lost-upgrades`. Tracking issue: #1 ("red alert on lost armslab upgrades?
Check vanilla behavior").

**Status: written, never run.** `luac -p` passes on the changed files, which proves they parse under
Lua 5.4 and nothing more. Needs an in-game pass.

All line numbers refer to `D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua`.

## What vanilla actually does

The upgrade icons **disappear** when the team loses its arms lab — identical to the early round
where nothing is researched. The expected red alert *exists in the source* but can never be seen.

`GUIMarineHUD:Update` (`Hud/Marine/GUIMarineHUD.lua:848-871`), in order:

```
armorLevel = PlayerUI_GetArmorLevel()            -- live availability, no argument
self.armorLevel:SetIsVisible(armorLevel ~= 0)    -- :851, hides at 0
...                                              -- 15 lines
if not MarineUI_GetHasArmsLab() then
    useColor = Color(1, 0, 0, 1)                 -- :868, the alert red
end
self.armorLevel:SetColor(useColor)               -- :871, painted on a hidden item
```

Both tests collapse to one event. `MarineUI_GetHasArmsLab()` is
`GetHasTech(player, kTechId.ArmsLab)` (`Marine_Client.lua:31-41`), and `PlayerUI_GetArmorLevel()`
with no argument asks the armour nodes' `GetHasTech()`. Lose the arms lab and both go false in the
same tech-tree update, so the icon is hidden and then coloured red.

**Destroyed and unpowered are the same event.** `TechMixin:UpdateTechAvailability` adds and removes a
structure's techId on `GetIsUnitActive`, which requires powered **and** alive **and** built
(`NS2Utility.lua:571-577`).

**The one case where the red is visible is warm-up.** `PlayerUI_GetArmorLevel` returns 3
unconditionally while warm-up is active (`Player_Client.lua:3180-3182`), before any arms lab exists —
non-zero level, so visible, and no arms lab, so red. Worth looking for in game as confirmation that
the analysis is right.

## The intent is vanilla's, not ours

- `PlayerUI_GetArmorLevel(researched)` takes a flag selecting `GetResearched()` over `GetHasTech()`
  (`Player_Client.lua:3176-3222`). The HUD never passes it.
- `Marine:GetArmorLevel()` and `Marine:GetWeaponLevel()` (`Marine.lua:381`, `:406`) are built on
  `GetResearched()` and have no callers anywhere in the lua tree.

Somebody meant to tell "you lost it" apart from "you never had it".

## What the red means

The upgrade really is inactive: `Marine:GetArmorAmount` (`Marine.lua:439`) uses the live
`GetHasTech`, so armour genuinely drops without a working arms lab. Hiding the icon was not a lie —
it just could not be told apart from the early game, which is the whole problem.

## The change

One new file, post-hooking `lua/Hud/Marine/GUIMarineHUD.lua`. After vanilla's `Update` runs: if
there is no arms lab and the upgrade was ever researched, restore the icon's visibility and colour.

It is small because two vanilla details cooperate:

- `ShowNewArmorLevel` / `ShowNewWeaponLevel` are **no-ops at level 0** (`:1007`, `:1018`), so the
  icon still holds the correct Armor-N or Weapons-N artwork. Only visibility has to come back.
- Vanilla has already set the red by the time the hook runs, since its colour block is after its
  visibility line. The hook re-applies it anyway rather than depending on load order.

| File | Change |
|---|---|
| `ImprovedTooltips_ArmsLabAlert.lua` | New, the post-hook |
| `ImprovedTooltips_FileHooks.lua` | Registers it |
| `ImprovedTooltips_Config.lua` | `kShowLostArmsLabUpgrades`, `kArmsLabLostColor` |

## Test checklist

- Research Armor 1, kill the arms lab: icon stays, turns red, keeps the Armor 1 artwork.
- Same with the arms lab unpowered rather than destroyed — should behave identically.
- Build a second arms lab: icons return to normal colour, no stale red.
- Research Armor 2 and 3, lose the lab at each level: the artwork should match the highest
  researched level, not the last one active.
- Early round with nothing researched: nothing shows. The whole point is that this stays different.
- Warm-up: vanilla already shows red here; confirm the hook does not double up or flicker.
- Weapons and armour independently — one researched, the other not.
