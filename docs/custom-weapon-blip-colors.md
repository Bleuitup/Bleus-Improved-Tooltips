# Custom weapon blip colors

Planned for 1.09. Design settled with the user on 2026-09-26; nothing built yet.

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
