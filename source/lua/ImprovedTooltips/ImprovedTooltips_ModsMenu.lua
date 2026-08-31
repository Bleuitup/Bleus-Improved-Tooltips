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
-- WIDGETS. OP_TT_Checkbox and OP_TT_Number are vanilla's own option wrappers (MenuDataUtils.lua:60,
-- :63). OP_TT_Number wraps GUIMenuSliderEntryWidget - a slider with an editable number beside it,
-- the same control mouse sensitivity uses (MenuData.lua:829-846). Typing in the box and dragging
-- the slider are two views of one value; nothing extra is needed for that.
--
-- The layout below mirrors AdvancedMenuData.lua:168-198, which builds the same shape for the
-- Advanced tab. Copy from there rather than inventing a config if this grows.

-- Two VMs load this file. The main menu VM has no mod state to write to, and touching
-- ImprovedTooltips there would either fail or write to a table nothing reads.
local kMainVM = decoda_name == "Main"

-- Prefixed so we can never collide with NS2+'s CHUD_ keys or another mod's.
local kOptionCooldownPanel   = "BIT_CooldownPanel"
local kOptionCooldownMinTime = "BIT_CooldownMinTime"

-- Repeated here rather than read from the config, because in the main menu VM the config is not
-- loaded. Keep in step with ImprovedTooltips_Config.lua.
local kDefaultCooldownPanel   = true
local kDefaultCooldownMinTime = 5

if not kMainVM then
	Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")
end

-- Push the stored values onto the live config. Both are read every frame by the panel
-- (GUIImprovedTooltipsCooldowns.lua:244 and :270), so this takes effect immediately with no
-- restart and no script reload.
local function ApplyStoredOptions()

	if kMainVM then
		return
	end

	local IT = ImprovedTooltips
	if not IT then
		return
	end

	IT.kShowCooldownPanel = Client.GetOptionBoolean(kOptionCooldownPanel, kDefaultCooldownPanel)

	-- The slider is a float because that is what GUIMenuSliderEntryWidget stores; the filter it
	-- feeds compares against whole seconds, so round rather than truncate.
	local minTime = Client.GetOptionFloat(kOptionCooldownMinTime, kDefaultCooldownMinTime)
	IT.kCooldownPanelMinDuration = math.max(0, math.floor(minTime + 0.5))

end

if not kMainVM and ImprovedTooltips then
	ImprovedTooltips.ApplyStoredOptions = ApplyStoredOptions
end

local kContents =
{
	{
		name = "bitCooldownPanel",
		class = OP_TT_Checkbox,
		params =
		{
			useResetButton = true,
			optionPath = kOptionCooldownPanel,
			optionType = "bool",
			default = kDefaultCooldownPanel,
			tooltip = "Show the In Cooldown panel listing the commander abilities your team currently has on cooldown. Cooldowns are shared by the whole team, so this is useful to every player, not only the commander.",
			immediateUpdate = ApplyStoredOptions,
		},
		properties =
		{
			{ "Label", "In Cooldown panel" },
		},
	},

	{
		name = "bitCooldownMinTime",
		class = OP_TT_Number,
		params =
		{
			useResetButton = true,
			optionPath = kOptionCooldownMinTime,
			optionType = "float",
			default = kDefaultCooldownMinTime,

			minValue = 0,
			maxValue = 30,
			decimalPlaces = 0,

			tooltip = "Abilities with a cooldown shorter than this are left out, so the panel does not flicker with the two and three second casts. At the default of 5 it lists Shade Ink, Bone Wall, Nano Shield, Heal Wave and Reverse Phase Gate. Set to 0 to list everything.",
			immediateUpdate = ApplyStoredOptions,
		},
		properties =
		{
			{ "Label", "Minimum cooldown shown (seconds)" },
		},
	},
}

table.insert(gModsCategories,
{
	categoryName = "bleusImprovedTooltips",

	entryConfig =
	{
		name = "bleusImprovedTooltipsEntry",
		class = GUIMenuCategoryDisplayBoxEntry,
		params =
		{
			label = "Bleu's Improved Tooltips",
			height = 101,
		},
	},

	contentsConfig = ModsMenuUtils.CreateBasicModsMenuContents
	{
		layoutName = "bleusImprovedTooltipsOptions",
		contents = kContents,
	},
})

-- Apply whatever was stored last session. The widgets only fire immediateUpdate when the user
-- moves them, so without this the mod would run on its compiled-in defaults until the panel was
-- opened and touched.
ApplyStoredOptions()
