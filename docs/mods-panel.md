# The mod's own settings panel, under Options > Mods

Shared infrastructure. Several planned features need a live toggle rather than a constant in
`ImprovedTooltips_Config.lua`: the exo charge figures, the marine weapon colours on the large map,
and whatever follows. This is the recipe, researched 2026-08-31, nothing built yet.

All line numbers refer to `D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua`.

## Two registries, do not confuse them

| Tab | Global | Fed by |
|---|---|---|
| Options > **Mods** | `gModsCategories` | `menu2/NavBar/Screens/Options/Mods/ModsMenuData.lua:135` |
| Options > **Advanced** | `gAdvancedSettingsCategories` | `menu2/AdvancedMenuData.lua:454` |

The NS2+ advanced options — including `playercolor_m` and the `drawviewmodel` family this mod cares
about — live in the **Advanced** tab. A mod's own panel, the CBM-style one, is a category in the
**Mods** tab. `AdvancedOptions` (`AdvancedOptions.lua`) is the data table behind the former and is
**not** the way to add our own panel.

## Registering a category

Post-hook `lua/menu2/NavBar/Screens/Options/Mods/ModsMenuData.lua` and append:

```
table.insert(gModsCategories,
{
    categoryName = "improvedTooltips",
    entryConfig =
    {
        name = "improvedTooltipsEntry",
        class = GUIMenuCategoryDisplayBoxEntry,
        params = { label = "Bleu's Improved Tooltips", height = 101 },
    },
    contentsConfig = ModsMenuUtils.CreateBasicModsMenuContents
    {
        layoutName = "improvedTooltipsOptions",
        contents = { -- widget configs -- },
    },
})
```

- **Append, never prepend.** `GUIMenuOptions.lua:425` asserts `gModsCategories[1].categoryName ==
  "manageMods"`.
- Categories are consumed by `GUIMenuOptions.lua:427-431`, which calls
  `modsCategoryDisplayBox:AddCategory(categoryName, entryConfig, contentsConfig)`.
- `ModsMenuUtils.CreateBasicModsMenuContents` (`ModsMenuData.lua:84`) wraps the contents in a
  `GUIMenuScrollPane` and requires `layoutName` (string) and `contents` (table).
- `AdvancedMenuData.lua:355-375` is a working example of exactly this shape — copy from it.

## It works in game

`ModsMenuData.lua` branches on `kInGame` only to disable the **mod management** screen (it swaps the
real screen for a "disabled" tooltip, `:138-172`). Custom categories are added outside that branch
and appear in both the main menu and the in-game options.

## Widgets

Same set the options menu uses. `OP_Checkbox` for toggles. The colour picker is
`GUIMenuColorPickerWidget`, which `AdvancedMenuData.lua:13` loads explicitly with the note
"doesn't get loaded by vanilla menu" — so load it the same way rather than assuming it is present.

Each widget config carries `optionPath` (the persisted key), `optionType`, `default`, and an
`immediateUpdate` function that pushes the new value where it is needed. Because our settings are
read every frame from the `IT` table, `immediateUpdate` can simply assign the `IT.k...` field, and
nothing needs restarting.

## Naming

Use a distinct `optionPath` prefix so we never collide with NS2+ or another mod's keys. Suggested:
`BIT_` (for example `BIT_ExoChargeNumbers`), matching the way CHUD prefixes its own.
