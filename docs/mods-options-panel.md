# Settings panel under Options > Mods

Branch `feature/mods-options-panel`. Tracking issue: #1.

**Status: written, never run.** `luac -p` passes on the changed files, which proves they parse and
nothing more. Needs an in-game pass.

This is the shared infrastructure the other feature branches need — the exo charge figures and the
marine weapon colours both want live toggles rather than constants. It is on its own branch for that
reason: building it inside either of those would mean writing it twice and merging it once.

All line numbers refer to `D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua`.

## What it adds

A "Bleu's Improved Tooltips" category in **Options > Mods**, beside CBM's, with two controls:

| Control | Setting | Range |
|---|---|---|
| Checkbox — In Cooldown panel | `IT.kShowCooldownPanel` | on / off |
| Slider — Minimum cooldown shown (seconds) | `IT.kCooldownPanelMinDuration` | 0–30, whole seconds |

The slider is `OP_TT_Number`, which wraps `GUIMenuSliderEntryWidget` — a slider with an editable
number beside it, the same control mouse sensitivity uses (`menu2/MenuData.lua:829-846`). Dragging
and typing are two views of one value; nothing extra was needed for the text entry.

## Two registries, do not confuse them

| Tab | Global | Declared in |
|---|---|---|
| Options > **Mods** | `gModsCategories` | `ModsMenuData.lua:135` |
| Options > **Advanced** | `gAdvancedSettingsCategories` | `AdvancedMenuData.lua:454` |

NS2+'s advanced options — `playercolor_m`, the `drawviewmodel` family — live in the Advanced tab.
`AdvancedOptions` is the data table behind that one and is **not** the way to add our own panel.

`manageMods` must stay first in `gModsCategories`; `GUIMenuOptions.lua:425` asserts it. This appends.

It works in game as well as from the main menu: `ModsMenuData` branches on `kInGame` only to disable
the mod *management* screen, not to suppress custom categories.

## How the values reach the mod

Both settings are read **every frame** by the panel — `GUIImprovedTooltipsCooldowns.lua:244` for the
minimum duration and `:270` for the on/off — so writing them takes effect immediately, with no
restart and no script reload.

`ApplyStoredOptions` reads the persisted values with `Client.GetOptionBoolean` / `GetOptionFloat` and
assigns them onto the `IT` table. It runs in two places:

- from each widget's `immediateUpdate`, when the user moves a control;
- **once at file load**, which is the part that is easy to forget — without it the mod would run on
  its compiled-in defaults until someone opened the panel and touched something.

## Things that were not obvious

- **Two VMs load this file.** The main menu runs its own VM, where there is no mod state to write to.
  `kMainVM = decoda_name == "Main"` guards both the config load and every write, the same test
  `AdvancedOptions.lua` uses.
- **The defaults are duplicated** in the menu file rather than read from the config, because in the
  main menu VM the config is not loaded. They must be kept in step with
  `ImprovedTooltips_Config.lua`.
- **The slider stores a float** because that is what `GUIMenuSliderEntryWidget` does, while the
  filter it feeds compares whole seconds. The value is rounded, not truncated.
- **Option keys are prefixed `BIT_`** so they can never collide with NS2+'s `CHUD_` keys or another
  mod's.

## Note on the 5 second default

Left at 5, deliberately. `kReversePGCooldown = 5` exactly (`Balance.lua:157`) and the filter is
`>=`, so Reverse Phase Gate is listed — which matters, because a reversed gate is time-critical
information and marines otherwise stand on a gate calling for a reverse that has already happened.
Raising the default to 6, or changing the comparison to `>`, would drop it.

With the slider in place this is a preference rather than a decision: anyone who finds the panel
busy can raise it themselves.

## Test checklist

- The category appears under Options > Mods, from the main menu and from in game.
- `manageMods` is still the first entry and still works.
- Toggling the checkbox hides and shows the panel immediately, without leaving the menu.
- Dragging the slider changes which abilities are listed, live.
- Typing a number into the box does the same, and out-of-range values clamp rather than break.
- The reset buttons restore 5 and on.
- Settings survive a restart — this is what the load-time `ApplyStoredOptions` is for, so check it
  by setting a value, quitting fully, and coming back.
- Nothing errors at the main menu, where the mod's own state does not exist.
