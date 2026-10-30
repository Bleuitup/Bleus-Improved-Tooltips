# Commander hotkey labels

**Published in 1.11 (2026-10-22)**, after the user tested it in game. Built on
`feature/commander-hotkey-labels`; the stub-game harness has 23 checks.

NS2 line numbers refer to `D:\SteamLibrary\steamapps\common\Natural Selection 2\ns2\lua`.

## Settled with the user, 2026-10-22

| | |
| --- | --- |
| What | Each commander tab and grid button's hotkey, small in its bottom-right corner, as Age of Mythology labels its command grid |
| Who | Both teams' commanders |
| Setting | HOTKEY LABELS ON COMMANDER BUTTONS, no section (both teams), `BIT_CommanderHotkeyLabels`, default **off** |
| Empty slots | No label: the fourth tab (it has no key) and any empty grid slot |
| Unavailable buttons | Label stays bright, whether the button is gray, red or on cooldown |
| Long keys | Space is written "SPC"; the user expects it to be rare |
| Look | The game's Agency font, white, with the chat's drop shadow; about 11 px capitals on 81 px buttons at the user's 1080p UI scale. Approved from a mockup on the user's 2026-10-11 commander screenshot |

## Where the keys come from

The commander grid has eleven bindings (`BindingsDialog.lua:66-76`): Grid1-3 are the first three tabs,
Grid4-11 the eight grid buttons. Vanilla reads them as `Client.GetOptionString("input/GridN", default)`
and lays them out in `kGridHotkeys` with `""` in the fourth tab's place (`Commander_Buttons.lua:64-125`,
`Commander_Hotkeys.lua:12-73`). The mod reads the same options with the same defaults
(Commander_Buttons.lua's, so Grid10 is C; `BindingsDialog.lua` lists G there but is not what the game
uses), once a second, so a rebinding shows within a moment.

**Only keys that work get a label.** A grid binding becomes a hotkey through vanilla's `gKey` table:
the 26 letters, `Space` and `ESC`. Anything else - a number, a mouse button - does nothing, so it gets
no label. `ESC` never matches either, because the escape binding is named `Escape`.

## How it hooks in

Post-hook on `lua/GUICommanderButtons.lua`:

- `SharedInitializeButtons` creates one text item per tab (`self.tabs[t].TopItem`) and grid button
  (`self.bottomButtons[i]`, index `numberOfTabs + i`), as a child of that button's item, anchored
  Right/Bottom with Align_Max both ways and inset `IT.kHotkeyLabelInset` commander GUI units.
- `Update` refreshes them every frame. The tabs are drawn by a file-local `UpdateTabs`, and
  `UpdateButtonStatus` only runs for the grid, so `Update` is the one place that sees both.
- A label hides with its button, because the game hides the button's item when the slot is empty.

**The marine and alien scripts are subclasses** (`GUICommanderButtonsMarines.lua:13`,
`GUICommanderButtonsAliens.lua:13`), and NS2 copies methods into a subclass when it is declared. Both
subclass files `Script.Load` the base first, so they are declared after the post-hook and copy the
wrapped methods. They are also patched by name in case one already exists.

CBM ships its own `GUICommanderButtons.lua`; the only difference from vanilla is an extra
PassiveOff button status, so the hook applies unchanged.

Size is relative to the commander GUI's own scale, `GUIScale(kCommanderGUIsGlobalScale)` (0.75,
`GUIUtility.lua:10`), which the buttons are sized by: text scale `0.75 x IT.kHotkeyLabelScale`, through
`GUIMakeFontScale`, which picks the nearest Agency size (about AgencyFB tiny at 0.76 at 1080p).

The labels run under `pcall`; after an error they print once and stop, so a fault cannot take the
buttons down.

## Test checklist

1. Setting off (default): the grid looks exactly as before.
2. Setting on, marine commander: Q W E on the tabs, A S D F / Z X C V on the grid, nothing on the
   fourth tab or empty slots. Size and corner placement as in the mockup.
3. Alien commander: the same.
4. Gray, red and cooling-down buttons keep a bright label.
5. Rebind a grid key under Options: the label follows within a second. Bind one to a number: its
   label goes.
6. Switch the setting mid-round: labels appear and go at once.
7. With CBM.
