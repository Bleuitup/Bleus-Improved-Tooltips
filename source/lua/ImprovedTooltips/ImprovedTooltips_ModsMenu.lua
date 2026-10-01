-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_ModsMenu.lua
--
-- The mod's own settings panel, under Options > Mods, alongside CBM's and anyone else's.
--
-- WHICH MENU THIS IS. There are two registries and they are easy to confuse:
--
--   gModsCategories             Options > Mods      ModsMenuData.lua:135
--   gAdvancedSettingsCategories Options > Advanced  AdvancedMenuData.lua:454
--
-- NS2+'s advanced options (playercolor_m, the drawviewmodel family, and so on) live in the second.
-- A mod's own panel is a category in the FIRST, which is what this file adds. `AdvancedOptions` is
-- the data table behind the Advanced tab and is NOT the way in here.
--
-- Categories are consumed by GUIMenuOptions.lua:427-431. `manageMods` must stay first in the list -
-- GUIMenuOptions.lua:425 asserts it - so this appends and never prepends.
--
-- It works in game as well as from the main menu: ModsMenuData branches on kInGame only to disable
-- the mod MANAGEMENT screen, not to suppress custom categories.
--
-- WIDGETS. OP_TT_Checkbox, OP_TT_Number and OP_TT_Choice are vanilla's own option wrappers
-- (MenuDataUtils.lua:60, :63). OP_TT_Number wraps GUIMenuSliderEntryWidget - a slider with an
-- editable number beside it, the same control mouse sensitivity uses (MenuData.lua:829-846). Typing
-- in the box and dragging the slider are two views of one value; nothing extra is needed for that.
--
-- The layout mirrors AdvancedMenuData.lua:168-198, which builds the same shape for the Advanced tab.
--
-- ONE ENTRY PER OPTION. Everything about an option is in kOptions below: its saved key, its default,
-- the config field it drives, and its widget. The panel and ApplyStoredOptions are both built from
-- that table, so adding an option is adding an entry.
--
-- Defaults are written here rather than read from ImprovedTooltips_Config.lua, because in the main
-- menu VM the config is not loaded. tools/check_mod.lua checks each one against the config's value.

-- Two VMs load this file. The main menu VM has no mod state to write to, and touching
-- ImprovedTooltips there would either fail or write to a table nothing reads.
local kMainVM = decoda_name == "Main"

if not kMainVM then
	Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")
end

-- CBM adds an SMG, which the map colors blue rather than the commander palette's orange (see
-- IT.kMapBlipColorOverrides). The tooltip says so only when that weapon exists: kPlayerStatus gains a
-- Submachinegun entry under CBM and has none in vanilla. Only knowable in game - the main menu VM
-- loads no gameplay Lua, so from the main menu the tooltip reads as it does without CBM.
local kCBMSmgNote = ""
if not kMainVM and type(kPlayerStatus) == "table" and rawget(kPlayerStatus, "Submachinegun") ~= nil then
	kCBMSmgNote = " SMGs are colored blue."
end

-- CASING, matching vanilla. Option labels and category names are written in CAPITALS; the tooltip
-- beneath them is ordinary sentence case with full stops. This is in the strings themselves, not a
-- transform the widget applies - from ns2/gamestrings/enUS.txt:
--
--   ADVANCED_OPTION_MARINE_HEALTHBARS         = "MARINE HEALTH BARS"
--   ADVANCED_OPTION_MARINE_HEALTHBARS_TOOLTIP = "Toggles the health bars from the bottom left of
--                                                the marine HUD and only leaves the numbers."
--   MENU_MANAGE_MODS                          = "MANAGE MODS"
--
-- So write labels upper and tooltips normally. Vanilla's tooltips also run one or two sentences;
-- keep to that.
--
-- Each entry:
--
--   key      the saved option name. Prefixed BIT_ so it cannot collide with NS2+'s CHUD_ keys or
--            another mod's. NEVER rename one: it is what keeps a player's saved setting.
--   field    the ImprovedTooltips config field the stored value is written to.
--   type     "bool", "int", "float" or "color", the option type the value is saved as. A color is
--            0xRRGGBB, in the default, in the config field and as the game stores it.
--   default  must match the config's own value for field.
--   read     optional; turns the stored value into the field's value.
--   widget   "checkbox", "number" (a slider with minValue, maxValue, decimalPlaces), "choice"
--            (with choices) or "color" (vanilla's color picker).
--   parent, hideValues
--            optional; the key of an earlier entry and the values of it for which this row folds
--            away.
local kOptions =
{
	{
		key = "BIT_CooldownPanel", field = "kShowCooldownPanel", type = "bool", default = true,
		widget = "checkbox",
		label = "IN COOLDOWN PANEL",
		-- The inner quotes are escaped, not smart quotes: this is a plain double-quoted Lua string, so
		-- an unescaped " would close it early.
		tooltip = "Show the \"In Cooldown\" panel listing the commander abilities your team currently has on cooldown. Cooldowns are shared by and to the whole team.",
	},

	{
		key = "BIT_CooldownMinTime", field = "kCooldownPanelMinDuration", type = "float", default = 5,
		-- The slider stores a float; the filter it feeds compares against whole seconds, so round
		-- rather than truncate.
		read = function(value) return math.max(0, math.floor(value + 0.5)) end,
		widget = "number", minValue = 0, maxValue = 30, decimalPlaces = 0,
		label = "MINIMUM COOLDOWN SHOWN (SECONDS)",
		-- Deliberately names no abilities: any list here goes stale under a mod that retunes
		-- cooldowns, and CBM retunes some.
		tooltip = "Abilities with a cooldown shorter than this are left out. Default is 5. Set to 0 to list everything.",
	},

	{
		-- The big map only from 1.04, and keeps its 1.03 key so a stored ON carries over.
		key = "BIT_WeaponBlips", field = "kColorMarineBlipsByWeapon", type = "bool", default = true,
		widget = "checkbox",
		label = "COLOR MAP BLIPS BY WEAPON",
		-- Says what it covers rather than listing exceptions. Exos are named because a player WILL
		-- notice theirs staying the team color and wonder whether it is broken; the rifle and the
		-- sidearms are not, because keeping the color you already chose reads as normal rather than
		-- as an omission.
		tooltip = "Colors marines on the map (the one on the map key) by their primary weapon. Weapon color matches the dropped weapon outline. Exosuits are ignored. Seen by marines and spectators only." .. kCBMSmgNote,
	},

	{
		key = "BIT_WeaponBlipsMinimap", field = "kColorMarineMinimapBlipsByWeapon", type = "bool", default = false,
		widget = "checkbox",
		label = "COLOR MINIMAP BLIPS BY WEAPON",
		tooltip = "The same weapon colors on the minimap: the one in the corner of the marine HUD, and the commander's and spectator's corner map. Set separately from the big map.",
	},

	{
		-- 1.09. Which maps use the player's own palette instead of the game's. One palette, shared when
		-- both do (user's call, docs/custom-weapon-blip-colors.md). Values are
		-- IT.kCustomWeaponColorsMode in the config; clamped against a hand-edited options file.
		key = "BIT_CustomWeaponColors", field = "kCustomWeaponColorsMode", type = "int", default = 0,
		read = function(value) return math.max(0, math.min(3, value)) end,
		widget = "choice",
		choices =
		{
			{ value = 0, displayString = "NONE" },
			{ value = 1, displayString = "MAP ONLY" },
			{ value = 2, displayString = "MINIMAP ONLY" },
			{ value = 3, displayString = "MAP AND MINIMAP" },
		},
		label = "CUSTOM WEAPON COLORS",
		tooltip = "Use your own weapon colors on the map, the minimap or both, in place of the game's. Only applies where weapon colors are switched on above.",
	},

	-- The palette. Each row folds away while CUSTOM WEAPON COLORS is NONE (parent, hideValues), the
	-- way vanilla folds the building highlight color under its checkbox. Defaults are the colors the
	-- map uses without this, so choosing a custom mode changes nothing until a color is picked.
	{
		key = "BIT_WeaponColorRifle", field = "kCustomWeaponColorRifle", type = "color", default = 0x00FFFF,
		widget = "color", parent = "BIT_CustomWeaponColors", hideValues = { 0 },
		label = "RIFLE COLOR",
		tooltip = "Map color for marines carrying a rifle.",
	},

	{
		key = "BIT_WeaponColorShotgun", field = "kCustomWeaponColorShotgun", type = "color", default = 0x00FF00,
		widget = "color", parent = "BIT_CustomWeaponColors", hideValues = { 0 },
		label = "SHOTGUN COLOR",
		tooltip = "Map color for marines carrying a shotgun.",
	},

	{
		key = "BIT_WeaponColorGrenadeLauncher", field = "kCustomWeaponColorGrenadeLauncher", type = "color", default = 0xFF00FF,
		widget = "color", parent = "BIT_CustomWeaponColors", hideValues = { 0 },
		label = "GRENADE LAUNCHER COLOR",
		tooltip = "Map color for marines carrying a grenade launcher.",
	},

	{
		key = "BIT_WeaponColorFlamethrower", field = "kCustomWeaponColorFlamethrower", type = "color", default = 0xFFFF00,
		widget = "color", parent = "BIT_CustomWeaponColors", hideValues = { 0 },
		label = "FLAMETHROWER COLOR",
		tooltip = "Map color for marines carrying a flamethrower.",
	},

	{
		key = "BIT_WeaponColorHeavyMachineGun", field = "kCustomWeaponColorHeavyMachineGun", type = "color", default = 0xE60000,
		widget = "color", parent = "BIT_CustomWeaponColors", hideValues = { 0 },
		label = "HEAVY MACHINE GUN COLOR",
		tooltip = "Map color for marines carrying a heavy machine gun.",
	},

	{
		-- Always listed: the main menu cannot tell whether CBM is loaded. Without CBM no marine
		-- ever carries one, so the row is simply never used.
		key = "BIT_WeaponColorSubmachinegun", field = "kCustomWeaponColorSubmachinegun", type = "color", default = 0x0000FF,
		widget = "color", parent = "BIT_CustomWeaponColors", hideValues = { 0 },
		label = "SMG COLOR (CBM)",
		tooltip = "Map color for marines carrying CBM's submachine gun.",
	},

	{
		key = "BIT_MinimapPhaseGateArrows", field = "kCommanderMinimapPhaseGateArrows", type = "bool", default = true,
		widget = "checkbox",
		label = "PHASE GATE ARROWS ON CORNER MINIMAP",
		tooltip = "Shows phase gate arrows on the commander's and spectator's corner minimap, like the big map. Follows your phase gate lines setting under Advanced.",
	},

	{
		key = "BIT_ExoWeaponBars", field = "kShowExoWeaponBars", type = "bool", default = true,
		widget = "checkbox",
		label = "EXO WEAPON BARS",
		tooltip = "Shows heat and charge bars beside the crosshair for each exo arm, in place of the Centralized HUD bars' weapon bar. Only while the exo viewmodel is hidden.",
	},

	{
		-- 0 notifications, 1 hive panel: IT.kHiveResearchDisplay* in the config. Clamped so a
		-- hand-edited options file cannot select a mode that does not exist.
		key = "BIT_HiveResearchDisplay", field = "kHiveResearchDisplay", type = "int", default = 0,
		read = function(value) return math.max(0, math.min(1, value)) end,
		widget = "choice",
		choices =
		{
			{ value = 0, displayString = "NOTIFICATIONS" },
			{ value = 1, displayString = "HIVE PANEL" },
		},
		label = "HIVE RESEARCH DISPLAY",
		tooltip = "Where research done in hives is shown. Notifications keeps it on the left, with a ring on the busy hive. Hive panel shows it in each hive's row instead, with progress and time left. Needs the hive status panel on.",
	},
}

local kReadOption =
{
	bool = function(key, default) return Client.GetOptionBoolean(key, default) end,
	int = function(key, default) return Client.GetOptionInteger(key, default) end,
	float = function(key, default) return Client.GetOptionFloat(key, default) end,
	-- The game hands a color option back as a Color (Client.GetOptionColor, what vanilla's own color
	-- options read through). The config keeps colors as 0xRRGGBB, like the defaults above, so it is
	-- turned back into that here.
	color = function(key, default)
		local color = Client.GetOptionColor(key, default)
		if type(color) == "number" then
			return color
		end
		if color ~= nil and type(color.r) == "number" and type(ColorToColorInt) == "function" then
			return ColorToColorInt(color)
		end
		return default
	end,
}

-- Push the stored values onto the live config. Every field is read at use - every frame, or every
-- time a notification is queued - so this takes effect immediately with no restart.
local function ApplyStoredOptions()

	local IT = not kMainVM and ImprovedTooltips
	if not IT then
		return
	end

	for i = 1, #kOptions do
		local option = kOptions[i]
		local value = kReadOption[option.type](option.key, option.default)
		if option.read then
			value = option.read(value)
		end
		IT[option.field] = value
	end

end

if not kMainVM and ImprovedTooltips then
	ImprovedTooltips.ApplyStoredOptions = ApplyStoredOptions
	-- For tools/check_mod.lua, which compares the defaults against the config.
	ImprovedTooltips.kModsMenuOptions = kOptions
end

local kWidgetClass =
{
	checkbox = OP_TT_Checkbox,
	number = OP_TT_Number,
	choice = OP_TT_Choice,
	color = OP_TT_ColorPicker,
}

-- The same widgets with vanilla's Expandable wrapper, for rows that fold under a parent
-- (MenuDataUtils.lua:67-72). AdvancedMenuData.lua keeps the same pairing for the Advanced tab.
local kExpandableWidgetClass =
{
	checkbox = OP_TT_Expandable_Checkbox,
	number = OP_TT_Expandable_Number,
	choice = OP_TT_Expandable_Choice,
	color = OP_TT_Expandable_ColorPicker,
}

-- The widget name the panel gives an option.
local function GetWidgetName(key)
	return "bit" .. key:gsub("^BIT_", "")
end

-- Folds a row away while its parent holds one of hideValues, and follows the parent as it changes.
-- What AdvancedMenuData.lua's CreateAdvancedOptionPostInit_HideValues does for the Advanced tab;
-- that one is a file-local tied to the AdvancedOptions table, so it is restated here.
local function CreateFoldUnderParentPostInit(parentKey, hideValues)

	local hidden = { }
	for i = 1, #hideValues do
		hidden[hideValues[i]] = true
	end

	return function(self)

		local parentWidget = GetOptionsMenu():GetOptionWidget(GetWidgetName(parentKey))
		if not parentWidget then
			return
		end

		local function GetShouldExpand()
			local parentExpanded = true
			if parentWidget.GetExpanded then
				parentExpanded = parentWidget:GetExpanded()
			end
			return parentExpanded and not hidden[parentWidget:GetValue()]
		end

		self:SetExpanded(GetShouldExpand())

		self:HookEvent(parentWidget, "OnValueChanged", function(child)
			child:SetExpanded(GetShouldExpand())
		end)

		self:HookEvent(parentWidget, "OnExpandedChanged", function(child)
			child:SetExpanded(GetShouldExpand())
		end)

	end

end

local function BuildContents()

	local contents = { }

	for i = 1, #kOptions do

		local option = kOptions[i]

		local params =
		{
			useResetButton = true,
			optionPath = option.key,
			optionType = option.type,
			default = option.default,
			tooltip = option.tooltip,
			immediateUpdate = ApplyStoredOptions,
			minValue = option.minValue,
			maxValue = option.maxValue,
			decimalPlaces = option.decimalPlaces,
		}

		local properties = { { "Label", option.label } }
		if option.choices then
			properties[#properties + 1] = { "Choices", option.choices }
		end

		local entry =
		{
			-- The widget names the panel used before it was built from this table.
			name = GetWidgetName(option.key),
			class = kWidgetClass[option.widget],
			params = params,
			properties = properties,
		}

		if option.parent then
			entry.class = kExpandableWidgetClass[option.widget]
			-- Vanilla's own margin for a folding option row (AdvancedMenuData.lua).
			params.expansionMargin = 4.0
			entry.postInit = CreateFoldUnderParentPostInit(option.parent, option.hideValues or { })
		end

		contents[i] = entry

	end

	return contents

end

table.insert(gModsCategories,
{
	categoryName = "bleusImprovedTooltips",

	entryConfig =
	{
		name = "bleusImprovedTooltipsEntry",
		class = GUIMenuCategoryDisplayBoxEntry,
		params =
		{
			-- No height. GUIMenuCategoryDisplayBoxEntry defaults to kHeight = 166 (:40, applied at
			-- :132 as "params.height or kHeight"), which is what vanilla's MANAGE MODS and every
			-- other mod's category use. An earlier 101 here was copied from AdvancedMenuData, but
			-- that is the ADVANCED tab, whose entries are deliberately denser - it made ours the
			-- one short bar in the list.
			label = "BLEU'S IMPROVED TOOLTIPS",
		},
	},

	contentsConfig = ModsMenuUtils.CreateBasicModsMenuContents
	{
		layoutName = "bleusImprovedTooltipsOptions",
		contents = BuildContents(),
	},
})

-- Apply whatever was stored last session. The widgets only fire immediateUpdate when the user
-- moves them, so without this the mod would run on its compiled-in defaults until the panel was
-- opened and touched.
ApplyStoredOptions()
