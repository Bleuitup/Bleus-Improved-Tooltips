-- Probe for the tournament ready labels across a round reset.
--
-- Loads the real ImprovedTooltips_TournamentReady.lua and the real config against stubs for the
-- scoreboard, the GUI and Shine, then walks the sequence the user reported on 2026-09-21: both
-- commanders ready up, the round starts, and Shine's !reset puts the game back to NotStarted while
-- the scoreboard is never opened in between.
--
-- Run from the repo root:
--   lua.exe docs/tournament-ready-reset-probe.lua

--------------------------------------------------------------------------------------------------
-- Stubs
--------------------------------------------------------------------------------------------------

Client = true
Script = { Load = function() end }

local function Vec(x, y, z)
	return { x = x or 0, y = y or 0, z = z or 0 }
end

Vector = Vec

function Color(r, g, b, a)
	return { r = r, g = g, b = b, a = a }
end

GUIItem = { Left = 0, Top = 1, Align_Min = 0, NotEqual = 2 }

kTeam1Index = 1
kTeam2Index = 2
kGameState = { NotStarted = 1, WarmUp = 2, PreGame = 3, Countdown = 4, Started = 5,
               Team1Won = 6, Team2Won = 7, Draw = 8 }

-- A GUI item that answers anything, and remembers the few things the probe reads back.
local function NewItem(text)

	local item = { text = text or "", visible = false, position = Vec(10, 0, 0), scale = Vec(1, 1, 0) }

	function item:SetText(value) self.text = value end
	function item:GetText() return self.text end
	function item:SetIsVisible(value) self.visible = value end
	function item:GetIsVisible() return self.visible end
	function item:SetPosition(value) self.position = value end
	function item:GetPosition() return self.position end
	function item:SetScale(value) self.scale = value end
	function item:GetScale() return self.scale end
	function item:GetSize() return Vec(20, 20, 0) end
	function item:GetFontName() return "font" end
	function item:GetTextWidth(value) return #tostring(value) * 5 end
	function item:GetTextHeight() return 12 end
	function item:SetColor(value) self.color = value end

	setmetatable(item, { __index = function() return function() end end })

	return item

end

GUIManager =
{
	CreateGraphicItem = function() return NewItem() end,
	CreateTextItem = function() return NewItem() end,
}

-- The host scoreboard. Its UpdateTeam does nothing; the mod post-hooks it.
GUIScoreboard =
{
	screenWidth = 1920,
	kPlayerItemWidth = 275,
	kTeamColumnSpacingX = 20,
	kScalingFactor = 1,
	UpdateTeam = function() end,
	GetTeamItemWidth = function() return 900 end,
}

-- The game state the mod reads.
local gameState = kGameState.NotStarted

function GetGameInfoEntity()
	return { GetState = function() return gameState end }
end

-- Shine's tournament mode, with the three receivers the mod wraps.
local plugin =
{
	ReceiveTeamReadyChange = function() end,
	ReceiveTeamReadyWaiting = function() end,
	ReceiveTeamPlayerNotReady = function() end,
}

Shine =
{
	IsExtensionEnabled = function() return true, plugin end,
}

-- Client update hooks, kept so the probe can run a frame on demand.
local updateHooks = { }
Event = { Hook = function(name, fn)
	if name == "UpdateClient" then
		updateHooks[#updateHooks + 1] = fn
	end
end }

local function RunClientFrame()
	for _, fn in ipairs(updateHooks) do
		fn()
	end
end

--------------------------------------------------------------------------------------------------
-- The real files
--------------------------------------------------------------------------------------------------

assert(loadfile("source/lua/ImprovedTooltips/ImprovedTooltips_Config.lua"))()

local IT = ImprovedTooltips

-- Out of ImprovedTooltips_Common.lua, which pulls in far more than this needs.
IT.kOwnIconTexture = "ui/bleu_tooltip_icons.dds"
function IT.GetOwnIconCoords()
	return { 0, 0, 64, 64 }
end

assert(loadfile("source/lua/ImprovedTooltips/ImprovedTooltips_TournamentReady.lua"))()

--------------------------------------------------------------------------------------------------
-- Driving it
--------------------------------------------------------------------------------------------------

local scoreboard = { GetTeamItemWidth = GUIScoreboard.GetTeamItemWidth }

local function NewTeam(teamNumber, name)
	return {
		TeamNumber = teamNumber,
		PlayerList = { "a", "b" },
		GUIs =
		{
			Background = NewItem(),
			TeamName = NewItem(name),
			TeamSkill = NewItem(),
		},
	}
end

local marines = NewTeam(kTeam1Index, "Frontiersmen (6 Players)")
local aliens = NewTeam(kTeam2Index, "Kharaa (6 Players)")

-- What the scoreboard would show for a team right now.
local function LabelOf(team)

	GUIScoreboard.UpdateTeam(scoreboard, team)

	local prefix = team.itReadyPrefix

	if not prefix or not prefix.glyph:GetIsVisible() then
		return "hidden"
	end

	return prefix.text:GetText()

end

local failures = 0

local function Check(what, got, want)

	local ok = got == want

	if not ok then
		failures = failures + 1
	end

	print(string.format("  %s  %-58s %s", ok and "pass" or "FAIL", what,
		ok and got or string.format("got %s, wanted %s", got, want)))

end

-- Pre-game. One draw installs the wrapper on the plugin's receivers.
LabelOf(marines)

local function ReadyTeam(teamNumber)
	plugin:ReceiveTeamReadyChange({ Team = teamNumber, IsReady = true })
end

print("\nPre-game, both commanders ready up")
ReadyTeam(1)
ReadyTeam(2)
Check("marines", LabelOf(marines), IT.kReadyLabelText)
Check("aliens", LabelOf(aliens), IT.kReadyLabelText)

print("\nThe round begins, with the scoreboard never opened")
gameState = kGameState.Countdown
RunClientFrame()
gameState = kGameState.Started
RunClientFrame()
Check("marines, while the round runs", LabelOf(marines), "hidden")
Check("aliens, while the round runs", LabelOf(aliens), "hidden")

print("\nShine's !reset puts the game back to NotStarted")
gameState = kGameState.NotStarted
Check("marines", LabelOf(marines), IT.kNotReadyLabelText)
Check("aliens", LabelOf(aliens), IT.kNotReadyLabelText)

print("\nAnd a team can ready again afterwards")
ReadyTeam(2)
Check("marines", LabelOf(marines), IT.kNotReadyLabelText)
Check("aliens", LabelOf(aliens), IT.kReadyLabelText)

-- Control: the same round with no client frame run at all while it is on. That is what the old code
-- amounted to, because its bookkeeping only ran while the scoreboard was being drawn, and it is the
-- reported bug. In a real game frames always run, so the state is always seen; this only pins down
-- what the fix depends on.
print("\nControl: a round nobody's client ever sees a frame of (the old behavior)")
gameState = kGameState.NotStarted
ReadyTeam(1)
ReadyTeam(2)
gameState = kGameState.Started
gameState = kGameState.NotStarted
Check("marines read stale", LabelOf(marines), IT.kReadyLabelText)
Check("aliens read stale", LabelOf(aliens), IT.kReadyLabelText)

print("\nAnd a single frame anywhere inside the round is enough")
gameState = kGameState.Started
RunClientFrame()
gameState = kGameState.NotStarted
Check("marines", LabelOf(marines), IT.kNotReadyLabelText)
Check("aliens", LabelOf(aliens), IT.kNotReadyLabelText)

print(string.format("\n%s\n", failures == 0 and "all checks passed" or failures .. " check(s) FAILED"))
os.exit(failures == 0 and 0 or 1)
