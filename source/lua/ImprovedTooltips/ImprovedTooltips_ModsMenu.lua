-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_ModsMenu.lua
--
-- The mod's own settings panel, under Options > Mods, alongside any other mod's.
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
--            away. parent may be a list of keys: the row then shows while ANY of them holds a
--            value outside hideValues, and folds only when none does.
--   section  optional; the heading the row sits under, "MARINES" or "ALIENS". Rows without one are
--            common to both teams and come first, under no heading. Keep each section's rows
--            together: a heading is drawn wherever the section changes.
--   available
--            optional; false leaves the row out of the panel. The saved value is still read.
local kOptions =
{
	-- 1.2 (build 345): the In Cooldown panel, weapon blip colors, corner minimap phase gate arrows, exo
	-- weapon bars and hive research display became vanilla options under Options > Advanced, and their
	-- rows went with them. Their saved BIT_ values stay in players' options files, unread.

	{
		-- 1.11. Both teams, so no section. Off by default (user's call, 2026-10-22).
		key = "BIT_CommanderHotkeyLabels", field = "kShowCommanderHotkeyLabels", type = "bool", default = false,
		widget = "checkbox",
		label = "HOTKEY LABELS ON COMMANDER BUTTONS",
		tooltip = "Shows each commander button's hotkey in its bottom-right corner. Follows your own key bindings.",
	},

	{
		-- 1.10.
		section = "MARINES",
		key = "BIT_WelderNameplateIcon", field = "kShowWelderNameplateIcon", type = "bool", default = true,
		widget = "checkbox",
		label = "WELDER ICON ON NAMEPLATES",
		tooltip = "Shows a welder icon next to the name of every marine teammate carrying one. Seen by the marine commander and by marines in the field.",
	},

	{
		-- 1.21. On by default (user's call, 2026-11-15).
		section = "ALIENS",
		key = "BIT_AlienShieldBar", field = "kShowAlienShieldBar", type = "bool", default = true,
		widget = "checkbox",
		label = "SHIELD BAR",
		tooltip = "With Centralized HUD bars, shows your mucous, vampirism and babbler shields as a bar beside your health bar, with their total underneath.",
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
--
-- Vanilla only ever folds a row under one parent. parentKeys may name several: the row shows while
-- any one of them is itself showing and holds a value outside hideValues.
local function CreateFoldUnderParentPostInit(parentKeys, hideValues)

	if type(parentKeys) ~= "table" then
		parentKeys = { parentKeys }
	end

	local hidden = { }
	for i = 1, #hideValues do
		hidden[hideValues[i]] = true
	end

	return function(self)

		local parentWidgets = { }
		for i = 1, #parentKeys do
			local parentWidget = GetOptionsMenu():GetOptionWidget(GetWidgetName(parentKeys[i]))
			if parentWidget then
				parentWidgets[#parentWidgets + 1] = parentWidget
			end
		end

		if #parentWidgets == 0 then
			return
		end

		local function GetShouldExpand()

			for i = 1, #parentWidgets do

				local parentWidget = parentWidgets[i]
				local parentExpanded = true
				if parentWidget.GetExpanded then
					parentExpanded = parentWidget:GetExpanded()
				end

				if parentExpanded and not hidden[parentWidget:GetValue()] then
					return true
				end

			end

			return false

		end

		local function Follow(child)
			child:SetExpanded(GetShouldExpand())
		end

		self:SetExpanded(GetShouldExpand())

		for i = 1, #parentWidgets do
			self:HookEvent(parentWidgets[i], "OnValueChanged", Follow)
			self:HookEvent(parentWidgets[i], "OnExpandedChanged", Follow)
		end

	end

end

local function BuildContents()

	local contents = { }

	local shown = { }
	for i = 1, #kOptions do
		if kOptions[i].available ~= false then
			shown[#shown + 1] = kOptions[i]
		end
	end

	local section = nil

	for i = 1, #shown do

		local option = shown[i]

		-- A heading wherever the section changes. Plain menu text at its default size, the same widget
		-- and tier as the line that heads CBM's panel. The Controls tab's divider at its group heading
		-- size (1.09) came out as large as the panel's own title bar, so the headings read as siblings
		-- of the panel instead of parts of it.
		if option.section ~= section then
			section = option.section
			contents[#contents + 1] =
			{
				name = "bitHeading" .. section:sub(1, 1) .. section:sub(2):lower(),
				class = GUIMenuText,
				params = { text = section },
			}
		end

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

		contents[#contents + 1] = entry

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
