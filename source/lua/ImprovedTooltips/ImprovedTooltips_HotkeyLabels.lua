-- Bleu's Improved Tooltips
-- lua/ImprovedTooltips/ImprovedTooltips_HotkeyLabels.lua
--
-- Post-hook on lua/GUICommanderButtons.lua. Writes each commander button's hotkey small in its
-- bottom-right corner, the way Age of Mythology labels its command grid, so a new commander can
-- learn the grid without hovering every button for its tooltip. Both teams, tabs and grid. Off by
-- default; switched by IT.kShowCommanderHotkeyLabels.
--
-- THE KEYS ARE THE PLAYER'S OWN BINDINGS. The commander grid has eleven: Grid1-3 are the first three
-- tabs, Grid4-11 the eight grid buttons (BindingsDialog.lua), read from the options as
-- "input/GridN". The fourth tab never has one: vanilla's kGridHotkeys holds "" in that place
-- (Commander_Buttons.lua). The defaults here are Commander_Buttons.lua's, which is what the tooltip
-- title's "( A )" uses too, so the corner and the tooltip always agree.
--
-- ONLY KEYS THAT WORK GET A LABEL. Vanilla turns a grid binding into a hotkey through its gKey table
-- (Commander_Hotkeys.lua): the 26 letters, "Space" and "ESC". A grid bound to anything else - a
-- number, a mouse button - does nothing in vanilla, so it gets no label rather than a key that does
-- not work. ("ESC" never matches either: the escape binding is named "Escape".) Space is written
-- "SPC" (the user's call, 2026-10-22); every other label is one letter.
--
-- EMPTY SLOTS GET NO LABEL. The label is a child of the button's own item, which the game hides when
-- the slot holds nothing (status Disabled, GUICommanderButtons.kButtonStatusDisabled), so the label
-- goes with it. A button that is visible but cannot be used right now - not researched, too
-- expensive, on cooldown - keeps a bright label (the user's call, 2026-10-22).
--
-- THE MARINE AND ALIEN BUTTON SCRIPTS ARE SUBCLASSES (GUICommanderButtonsMarines and
-- GUICommanderButtonsAliens), and NS2 copies methods into a subclass when it is declared. Both
-- subclass files Script.Load this one's target first and are declared afterwards, so they copy the
-- wrapped methods; the subclasses are still patched by name below in case one was declared earlier.
-- CBM ships its own GUICommanderButtons.lua; it keeps tabs, bottomButtons, SharedInitializeButtons and
-- Update as vanilla has them, and a post-hook wraps whichever loaded.

if not Client then
	return
end

Script.Load("lua/ImprovedTooltips/ImprovedTooltips_Config.lua")

local IT = ImprovedTooltips

if type(GUICommanderButtons) ~= "table"
	or type(GUICommanderButtons.SharedInitializeButtons) ~= "function"
	or type(GUICommanderButtons.Update) ~= "function" then
	return
end

------------------------------------------------------------------------------------------------
-- Which key each button has
------------------------------------------------------------------------------------------------

-- Button index (as GUICommanderButtons numbers them: tabs 1-4, then the grid) -> grid binding and
-- the default it falls back to, exactly as Commander_Buttons.lua reads them.
local kBindingForIndex =
{
	[1] = { "Grid1", "Q" }, [2] = { "Grid2", "W" }, [3] = { "Grid3", "E" },
	[5] = { "Grid4", "A" }, [6] = { "Grid5", "S" }, [7] = { "Grid6", "D" }, [8] = { "Grid7", "F" },
	[9] = { "Grid8", "Z" }, [10] = { "Grid9", "X" }, [11] = { "Grid10", "C" }, [12] = { "Grid11", "V" },
}

local function GetLabelForBinding(binding)

	if type(binding) ~= "string" then
		return nil
	end

	if binding:match("^%a$") then
		return binding:upper()
	end

	if binding == "Space" then
		return "SPC"
	end

	return nil

end

-- Read again once a second rather than every frame, so a rebinding shows within a moment without
-- twelve option reads per frame.
local labelForIndex = { }
local nextBindingRead = 0

local function RefreshBindings()

	local now = Shared.GetTime()

	if now < nextBindingRead then
		return
	end

	nextBindingRead = now + 1

	local fresh = { }

	for index, binding in pairs(kBindingForIndex) do
		fresh[index] = GetLabelForBinding(Client.GetOptionString("input/" .. binding[1], binding[2]))
	end

	labelForIndex = fresh

end

------------------------------------------------------------------------------------------------
-- The labels
------------------------------------------------------------------------------------------------

local function CreateLabel(buttonItem)

	local unit = GUIScale(kCommanderGUIsGlobalScale)
	local inset = IT.kHotkeyLabelInset * unit

	local label = GUIManager:CreateTextItem()
	label:SetFontName(Fonts.kAgencyFB_Small)
	label:SetScale(GUIScale(Vector(1, 1, 1)) * (kCommanderGUIsGlobalScale * IT.kHotkeyLabelScale))
	GUIMakeFontScale(label)
	label:SetAnchor(GUIItem.Right, GUIItem.Bottom)
	label:SetTextAlignmentX(GUIItem.Align_Max)
	label:SetTextAlignmentY(GUIItem.Align_Max)
	label:SetPosition(Vector(-inset, -inset, 0))
	label:SetColor(IT.kHotkeyLabelColor)
	-- The same shadow the chat uses (GUIChat.lua:100), so a white letter reads over light icon art.
	label:SetDropShadowEnabled(true)
	label:SetIsVisible(false)

	-- A child of the button, so it moves, hides and is destroyed with it.
	buttonItem:AddChild(label)

	return label

end

local function CreateLabels(script)

	local labels = { }

	for t = 1, #(script.tabs or { }) do
		local tab = script.tabs[t]
		if kBindingForIndex[t] and tab and tab.TopItem then
			labels[t] = CreateLabel(tab.TopItem)
		end
	end

	local numberOfTabs = script.numberOfTabs or 0

	for i = 1, #(script.bottomButtons or { }) do
		local index = numberOfTabs + i
		if kBindingForIndex[index] then
			labels[index] = CreateLabel(script.bottomButtons[i])
		end
	end

	script.bitHotkeyLabels = labels

end

local function UpdateLabels(script)

	local labels = script.bitHotkeyLabels

	if not labels then
		return
	end

	local show = IT.kShowCommanderHotkeyLabels

	if show then
		RefreshBindings()
	end

	for index, label in pairs(labels) do

		local text = show and labelForIndex[index] or nil

		if text then
			if label:GetText() ~= text then
				label:SetText(text)
			end
			label:SetIsVisible(true)
		else
			label:SetIsVisible(false)
		end

	end

end

------------------------------------------------------------------------------------------------
-- The hooks
------------------------------------------------------------------------------------------------

-- A fault here must never take the commander's buttons down with it, so the labels run protected.
-- After the first error it says so once in the console and stops, rather than failing every frame.
local failed = false

local function Protected(fn, script)

	if failed then
		return
	end

	local ok, err = pcall(fn, script)

	if not ok then
		failed = true
		Print("[Bleu's Improved Tooltips] commander hotkey labels disabled after an error: %s", tostring(err))
	end

end

local originalSharedInitializeButtons = GUICommanderButtons.SharedInitializeButtons
local originalUpdate = GUICommanderButtons.Update

local function SharedInitializeButtons(self, settingsTable)
	originalSharedInitializeButtons(self, settingsTable)
	Protected(CreateLabels, self)
end

local function Update(self, deltaTime)
	originalUpdate(self, deltaTime)
	Protected(UpdateLabels, self)
end

GUICommanderButtons.SharedInitializeButtons = SharedInitializeButtons
GUICommanderButtons.Update = Update

for _, name in ipairs({ "GUICommanderButtonsMarines", "GUICommanderButtonsAliens" }) do

	local class = _G[name]

	if type(class) == "table" then
		if rawget(class, "SharedInitializeButtons") == originalSharedInitializeButtons then
			class.SharedInitializeButtons = SharedInitializeButtons
		end
		if rawget(class, "Update") == originalUpdate then
			class.Update = Update
		end
	end

end
