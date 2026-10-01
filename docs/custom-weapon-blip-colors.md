# Custom weapon blip colors

Built for 1.09 on 2026-10-01 (`release/1.09`), to the design settled with the user on 2026-09-26.
Awaiting the user's in-game test.

## The request

Let players choose the colors marine blips take by weapon, on the map and on the minimap, the way
vanilla lets them choose other map colors (Advanced > Map: MARINE PLAYER COLOR, MAP ELEMENTS COLOR,
and so on). Each map is either on the default weapon colors or on the custom ones:

| Map | Minimap |
|---|---|
| Default | Default |
| Custom | Custom |
| Custom | Default |
| Default | Custom |

"Default" is what the feature does today: the commander's ammo bar palette read from the game
(`GUIUnitStatus.lua:57-64`), plus the SMG override in blue. **There is ONE custom palette**, shared
when both maps use it (user's call, 2026-09-26). Two palettes were offered and declined.

## Menu: layout B (user's choice)

```
COLOR MAP BLIPS BY WEAPON          [x]      existing, key BIT_WeaponBlips, unchanged
COLOR MINIMAP BLIPS BY WEAPON      [x]      existing, key BIT_WeaponBlipsMinimap, unchanged
CUSTOM WEAPON COLORS               [ NONE | MAP ONLY | MINIMAP ONLY | MAP AND MINIMAP ]
   └ RIFLE                         [color]  rows fold open unless NONE
   └ SHOTGUN                       [color]
   └ GRENADE LAUNCHER              [color]
   └ FLAMETHROWER                  [color]
   └ HEAVY MACHINE GUN             [color]
   └ SMG (CBM)                     [color]
```

Rejected: A (a DEFAULT/CUSTOM row under each switch, shared palette block with two parents) and C
(one OFF / BY WEAPON / BY WEAPON, CUSTOM row per map, replacing the switches and migrating keys).

## Building blocks (vanilla, checked 2026-09-25)

- Color picker: `OP_TT_ColorPicker` (`menu2/MenuDataUtils.lua:65`), stored as an int `0xRRGGBB`
  (`optionType = "color"`, see `AdvancedOptions["playercolor_m"]`, `AdvancedOptions.lua`).
- Folding rows: the `Expandable` wrapper, `OP_TT_Expandable_ColorPicker` (`MenuDataUtils.lua:72`),
  shown or hidden by a parent's value the way `AdvancedMenuData.lua:31-58` does it for
  `commhighlightcolor` under `commhighlight` (`hideValues`). Layout B needs only this one-parent case.
- `kOptions` in `ImprovedTooltips_ModsMenu.lua` needs two new widget kinds (choice already exists):
  color, and a parent/hideValues pair. Keep the table-driven build.

## Decisions carried into the build

- Existing keys `BIT_WeaponBlips` and `BIT_WeaponBlipsMinimap` are not touched (never rename a key).
- The custom rows start at the default palette's values (rifle #00FFFF, shotgun #00FF00, grenade
  launcher #FF00FF, flamethrower #FFFF00, HMG #E60000, SMG #0000FF), so switching to custom changes
  nothing until a color is picked. DEFAULT keeps reading the live game palette.
- Custom colors feed the same path as today (`MapBlip.kCustomMarineColor` swapped around the
  original call), so Steam friend desaturation, the viewer-team gate and colorblind mode apply to
  them unchanged. Exos and weapon-colors-off marines stay on vanilla's MARINE PLAYER COLOR.
- A custom choice for a map whose switch is off does nothing until the switch is on; the tooltip
  says so.
- The SMG row is always shown, labeled "(CBM)": the main menu VM cannot tell whether CBM is loaded.
- Changes apply immediately; the Mods panel Reset covers the new rows.
- Workshop description has 29 bytes free at 1.07; a sentence here means trimming another.

## As built (2026-10-01)

- **Options** (`kOptions`, `ImprovedTooltips_ModsMenu.lua`): `BIT_CustomWeaponColors` (int, 0 to 3,
  field `kCustomWeaponColorsMode`) and six color rows, `BIT_WeaponColorRifle`, `Shotgun`,
  `GrenadeLauncher`, `Flamethrower`, `HeavyMachineGun`, `Submachinegun` (fields
  `kCustomWeaponColor<Name>`). The table gained a `color` type and widget, and `parent` /
  `hideValues` for rows that fold.
- **Colors are `0xRRGGBB` everywhere on the mod's side**: option default, config field and what
  `tools/check_mod.lua` compares. The game hands a stored color back as a `Color`
  (`Client.GetOptionColor`); the reader turns it back with `ColorToColorInt`.
- **Folding** restates `CreateAdvancedOptionPostInit_HideValues` (`AdvancedMenuData.lua:24`), which
  is a file-local tied to the `AdvancedOptions` table: the child looks its parent up with
  `GetOptionsMenu():GetOptionWidget(name)` and follows its `OnValueChanged`. The list layout already
  collapses the space of a folded row (`GUIListLayout`, which the Advanced tab uses through the same
  `ModsMenuUtils.CreateBasicModsMenuContents`).
- **Lookup** (`ImprovedTooltips_MapBlipColor.lua`): `GetUsesCustomColors(isBigMap)` decides per call,
  and `GetCustomColorForStatus` reads `IT["kCustomWeaponColor" .. statusName]` live, so a pick shows
  on the next map update. A weapon with no field keeps its usual color. Everything downstream is
  unchanged: the color is still fed through `MapBlip.kCustomMarineColor` around the original call.

## Test checklist

Weapon colors must be on for the map being checked (the two switches above the new row).

- NONE: the six color rows are folded away; maps look as in 1.08.
- MAP ONLY, nothing picked: rows fold out; the big map looks the same as before (same starting colors).
- Pick a new shotgun color: shotgunners change on the big map at once; the minimap keeps the old green.
- MINIMAP ONLY: the reverse. MAP AND MINIMAP: both use the picked colors.
- Back to NONE: both maps return to the game's colors and the rows fold away; the picks are kept for
  next time.
- Each row's reset button returns that color to its default.
- Restart the game: mode and colors are remembered.
- A Steam friend with a custom-colored weapon still shows at half strength.
- From the alien team: marine blips never take weapon colors, custom or not.
- With CBM: the SMG row colors SMG marines. Without CBM the row does nothing.
- From the main menu (not in a game): the panel opens, the rows fold and unfold, no script errors.

## Simplified to OFF / ON (2026-10-01)

After testing, the four-way choice (NONE / MAP ONLY / MINIMAP ONLY / MAP AND MINIMAP) was dropped
at the user's request: game colors on one map and custom colors on the other is a confusing choice
nobody needs. What replaced it:

- **CUSTOM WEAPON COLORS is OFF (default) or ON.** ON applies the palette to every map whose
  weapon-color checkbox is ticked. The two checkboxes alone decide which maps are colored.
- **Same saved key**, `BIT_CustomWeaponColors`, still an int: 0 is OFF, anything above reads as ON.
  The config field is now the boolean `kUseCustomWeaponColors`; `GetUsesCustomColors` is gone.
- **The row folds away when both checkboxes are off**, since there is nothing for it to apply to,
  and the six color rows fold with it. Vanilla never folds a row under two parents, so the fold
  helper takes a list: the row shows while any parent holds a value outside `hideValues`.

Test checklist, replacing the mode lines above:

- OFF: color rows folded; maps use the game's colors.
- ON, nothing picked: rows fold out; maps look the same.
- ON, pick a shotgun color: it changes on every map whose checkbox is ticked, and on no other.
- Untick both checkboxes: CUSTOM WEAPON COLORS and the color rows fold away. Tick either: the row
  returns, and the color rows with it if it was ON.

## SMG row only under CBM (2026-10-01)

The SMG color row was always listed, because the main menu cannot tell whether CBM will be loaded.
The user's call: without CBM it should not show. It is now listed only in a game where
`kPlayerStatus` has a `Submachinegun` entry, so it is also absent from the main menu's panel; a CBM
player sets that color from the in-game menu. The saved value is read either way.
