-- Research notification stack simulation.
--
-- Runs the SHIPPED vanilla files (lua/Hud/GUIEvent.lua, lua/Hud/GUINotificationItem.lua,
-- lua/Hud/GUINotificationMixin.lua, lua/TechTree_Client.lua, lua/TechNode.lua and the three tech
-- node message parsers out of lua/NetworkMessages.lua) against a stubbed engine, driving them with
-- a small model of the server side of ResearchMixin, so the behaviour of the notification stack can
-- be checked case by case without the game.
--
-- Run: lua.exe sim.lua "<path to ns2/lua>"

local NS2 = ...
NS2 = NS2 or "D:/SteamLibrary/steamapps/common/Natural Selection 2/ns2/lua"

--------------------------------------------------------------------------------------------------
-- Engine stubs
--------------------------------------------------------------------------------------------------

local now = 100 -- simulated clock, well past the notification mixin's 2 second start delay

local log = {}
local function Record(fmt, ...)
	table.insert(log, string.format("  %6.2f  " .. fmt, now, ...))
end

-- Vector with component wise arithmetic, as the GUI code multiplies and divides vectors
local VectorMT = {}
VectorMT.__index = VectorMT

local function Vec(x, y, z)
	return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, VectorMT)
end

local function Components(v)
	if type(v) == "number" then
		return v, v, v
	end
	return v.x, v.y, v.z
end

VectorMT.__add = function(a, b)
	local ax, ay, az = Components(a)
	local bx, by, bz = Components(b)
	return Vec(ax + bx, ay + by, az + bz)
end

VectorMT.__sub = function(a, b)
	local ax, ay, az = Components(a)
	local bx, by, bz = Components(b)
	return Vec(ax - bx, ay - by, az - bz)
end

VectorMT.__mul = function(a, b)
	local ax, ay, az = Components(a)
	local bx, by, bz = Components(b)
	return Vec(ax * bx, ay * by, az * bz)
end

VectorMT.__div = function(a, b)
	local ax, ay, az = Components(a)
	local bx, by, bz = Components(b)
	return Vec(ax / bx, ay / by, az / bz)
end

Vector = Vec

function Color(r, g, b, a)
	if type(r) == "table" then
		return { r = r.r, g = r.g, b = r.b, a = r.a }
	end
	return { r = r, g = g, b = b, a = a }
end

-- A GUI item that accepts any call. GetPosition has to give back a vector, and the progress bar's
-- guiItem takes float parameters.
local ItemMT = {}
ItemMT.__index = function(item, key)
	if key == "guiItem" then
		local guiItem = setmetatable({}, ItemMT)
		rawset(item, "guiItem", guiItem)
		return guiItem
	end

	if key == "GetPosition" then
		return function() return Vec(0, 0, 0) end
	end

	return function() end
end

local function NewItem()
	return setmetatable({}, ItemMT)
end

local script = {}
function script:CreateAnimatedGraphicItem() return NewItem() end
function script:CreateAnimatedTextItem() return NewItem() end

function GetGUIManager()
	return { CreateGraphicItem = function() return NewItem() end }
end

GUIItem =
{
	Left = 0, Right = 1, Middle = 2, Top = 3, Bottom = 4, Center = 5,
	Align_Min = 0, Align_Center = 1, Align_Max = 2,
}

GUI = { DestroyItem = function() end }

function PrecacheAsset(name) return name end
function GUIGetSizeFromCoords(coords) return Vec(coords[3] - coords[1], coords[4] - coords[2], 0) end
function GUIUnpackCoords(coords) return coords[1], coords[2], coords[3], coords[4] end
function GUIMakeFontScale() end
function GetScaledVector() return Vec(1, 1, 0) end
function GetTextureCoordinatesForIcon() return { 0, 0, 80, 80 } end
function AnimateLinear() end
function AnimateSin() end

Fonts = setmetatable({}, { __index = function(_, key) return key end })
Locale = { ResolveString = function(s) return s end }
string.UTF8Upper = string.upper

function ConditionalValue(condition, a, b)
	if condition then return a end
	return b
end

function Clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

function Log() end
function Print() end
ASSERT = assert

Shared = { GetTime = function() return now end, GetTestsEnabled = function() return false end }
Client = { GetTime = function() return now end }
Event = { Hook = function() end }
Entity = { invalidId = -1 }

function IterableDict() return {} end

function enum(names)
	local e = {}
	for index, name in ipairs(names) do
		e[name] = index
		e[index] = name
	end
	return e
end
function GetWarmupActive() return false end
function CreateMixin() return {} end
function HasMixin() return true end

kMarineTeamType = 1
kAlienTeamType = 2
kIconColors = { [1] = Color(0, 0, 1, 1), [2] = Color(1, 1, 0, 1) }

kTechType = { Invalid = 1, Order = 2, Research = 3, Upgrade = 4, Action = 5, Buy = 6, Build = 7,
              EnergyBuild = 8, Manufacture = 9, Activation = 10, Menu = 11, EnergyManufacture = 12,
              PlasmaManufacture = 13, Special = 14, Passive = 15 }

-- kTechId in the game raises on an unknown name. Here any name asked for gets an id, which lets the
-- shipped files build their per tech tables untouched.
local techIdNames = {}
kTechId = setmetatable({}, {
	__index = function(t, name)
		local id = #techIdNames + 1
		techIdNames[id] = name
		rawset(t, name, id)
		return id
	end
})
kTechId.None = 0
techIdNames[0] = "None"

function EnumToString(_, id) return techIdNames[id] or tostring(id) end

kTechDataResearchName = "researchName"
kTechDataCostKey = "cost"
local kResearchTimeKey = "researchTime"
kTechDataResearchTimeKey = kResearchTimeKey

-- Filled in per scenario: [tech name] = { time = seconds, techType = kTechType.X, instanced = bool }
local techData = {}

function LookupTechData(techId, key, default)
	local entry = techData[EnumToString(kTechId, techId)]
	if key == kTechDataResearchName then
		return EnumToString(kTechId, techId)
	end
	if key == kResearchTimeKey and entry then
		return entry.time
	end
	if key == kTechDataCostKey then
		return 0
	end
	return default
end

local instancedTechIds = {}
function GetTechIdIsInstanced(techId)
	return instancedTechIds[techId] or false
end

local advancedOptions = { unlocks = true, hudbars_a = 0, hudbars_m = 0 }
function GetAdvancedOption(name) return advancedOptions[name] end

-- NS2's class syntax
function class(name)
	local cls = {}
	cls.__index = cls
	_G[name] = setmetatable(cls, { __call = function(c) return setmetatable({}, c) end })
	return function() end
end

Script = { Load = function() end }

--------------------------------------------------------------------------------------------------
-- The real files
--------------------------------------------------------------------------------------------------

local function LoadGameFile(relativePath)
	local path = NS2 .. "/" .. relativePath
	local chunk, err = loadfile(path)
	if not chunk then
		error("could not load " .. path .. ": " .. tostring(err), 0)
	end
	chunk()
end

-- The three message parsers, lifted out of NetworkMessages.lua so the rest of that file (which
-- registers network messages) does not have to load.
local function LoadFunctionsFrom(relativePath, names)
	local path = NS2 .. "/" .. relativePath
	local file = assert(io.open(path, "rb"))
	local source = file:read("*a"):gsub("\r\n", "\n")
	file:close()

	for _, name in ipairs(names) do
		local pattern = "\nfunction " .. name .. "%b()(.-)\nend\n"
		local body = source:match(pattern)
		local signature = source:match("\nfunction " .. name .. "(%b())")
		if not body or not signature then
			error("could not extract " .. name .. " from " .. path, 0)
		end
		local chunk = assert(load("function " .. name .. signature .. body .. "\nend"))
		chunk()
	end
end

class 'TechTree'
LoadGameFile("TechNode.lua")
LoadFunctionsFrom("NetworkMessages.lua", { "ParseTechNodeUpdateMessage", "ParseTechNodeInstanceMessage",
                                           "BuildTechNodeUpdateMessage", "BuildTechNodeInstanceMessage" })
LoadGameFile("TechTree_Client.lua")
LoadGameFile("Hud/GUINotificationMixin.lua")
LoadGameFile("Hud/GUINotificationItem.lua")
LoadGameFile("Hud/GUIEvent.lua")

--------------------------------------------------------------------------------------------------
-- Instrumentation: log what the stack does, without changing what it does
--------------------------------------------------------------------------------------------------

local sounds = {}

local function Wrap(name, report)
	local original = GUINotificationItem[name]
	GUINotificationItem[name] = function(self, ...)
		report(self, ...)
		return original(self, ...)
	end
end

local function TechName(item)
	return EnumToString(kTechId, item.techId)
end

Wrap("Initialize", function(self) Record("shown       %s", EnumToString(kTechId, self.techId)) end)
Wrap("SetCompleted", function(self) Record("complete    %s", TechName(self)) end)
Wrap("SetCancelled", function(self) Record("CANCELLED   %s", TechName(self)) end)
Wrap("Destroy", function(self) Record("removed     %s", TechName(self)) end)

local originalFadeOut = GUINotificationItem.FadeOut
GUINotificationItem.FadeOut = function(self, duration)
	if self.destroyTime == 0 and duration == 0.5 then
		Record("PUSHED OUT  %s", TechName(self))
	end
	return originalFadeOut(self, duration)
end

--------------------------------------------------------------------------------------------------
-- Client and server model
--------------------------------------------------------------------------------------------------

local clientTechTree, serverTechTree, player, eventDisplay

local function NewTechTree()
	local techTree = TechTree()
	techTree.nodes = {}
	techTree.inProgressResearch = {}
	techTree.inProgressInstances = {}
	techTree.inProgressCancelled = false
	function techTree:GetTechNode(techId) return self.nodes[techId] end
	function techTree:AddNode(node) self.nodes[node.techId] = node end
	return techTree
end

function GetTechTree() return clientTechTree end
function GetTechNode(techId) return clientTechTree:GetTechNode(techId) end

function PlayerUI_ClearResearchNotifications()
	-- In game this also clears the GUIEvent, but during GUIEvent:Initialize the HUD has not yet
	-- stored the event display, so only the player's queue is cleared. Same here.
	if player then
		player.notifications = {}
	end
end

function PlayerUI_GetRecentNotification()
	if player and player:GetDelayTimePassed() then
		return player:GetAndClearNotification()
	end
end

local function NewPlayer()
	local p = {}
	p.AddNotification = GUINotificationMixin.AddNotification
	p.GetAndClearNotification = GUINotificationMixin.GetAndClearNotification
	p.GetDelayTimePassed = GUINotificationMixin.GetDelayTimePassed
	p.notifications = {}
	p.timeInitialized = 0
	function p:TriggerEffects(name)
		if name == "upgrade_complete" then
			table.insert(sounds, now)
			Record("SOUND")
		end
	end
	return p
end

Client.GetLocalPlayer = function() return player end

-- table.icount, used by the notification mixin
table.icount = function(t) return #t end

-- One entity researching one tech, as ResearchMixin does it on the server.
local researchers = {}

local function BuildNodes(techs)
	for name, entry in pairs(techs) do
		local techId = kTechId[name]
		techData[name] = entry
		if entry.instanced then
			instancedTechIds[techId] = true
		end
	end

	serverTechTree = NewTechTree()
	clientTechTree = NewTechTree()

	for name, entry in pairs(techs) do
		local techId = kTechId[name]

		local serverNode = TechNode()
		serverNode:Initialize(techId, entry.techType, kTechId.None, kTechId.None)
		serverNode.time = entry.time
		serverNode.available = true
		serverTechTree:AddNode(serverNode)

		-- The client gets the node through TechNodeBase before anything is researched.
		local clientNode = TechNode()
		clientNode:Initialize(techId, entry.techType, kTechId.None, kTechId.None)
		clientNode.time = entry.time
		clientNode.available = true
		clientTechTree:AddNode(clientNode)
	end
end

local changedNodes = {}

local function MarkChanged(node)
	changedNodes[node] = true
end

local function StartResearch(entityId, techName)
	local node = serverTechTree:GetTechNode(kTechId[techName])
	node:SetResearching()
	table.insert(researchers, { entityId = entityId, node = node, progress = 0, duration = node.time })
	MarkChanged(node)
	Record("started     %s", techName)
end

-- AbortResearch: the commander cancels, or the structure dies.
local function CancelResearch(techName)
	for _, researcher in ipairs(researchers) do
		if researcher.node.techId == kTechId[techName] and researcher.progress > 0 and researcher.progress < 1 then
			researcher.node:ClearResearching(researcher.entityId)
			researcher.progress = 1.01 -- stop advancing it
			MarkChanged(researcher.node)
			Record("cancelled   %s (by the commander)", techName)
			return
		end
	end
end

-- One server tick: advance research, then send what changed, exactly the way
-- TechTree:SendTechTreeUpdates does (node update first, then one message per instance, then the
-- finished instances are dropped on the server).
local function ServerTick(deltaTime)
	for _, researcher in ipairs(researchers) do
		if researcher.progress < 1 then
			local node = researcher.node
			local progress = math.min(1, researcher.progress + deltaTime / researcher.duration)
			researcher.progress = progress
			node:SetResearchProgress(progress, researcher.entityId)
			MarkChanged(node)
			if progress == 1 then
				node:SetResearched(true)
			end
		end
	end

	for node in pairs(changedNodes) do
		clientTechTree:UpdateTechNodeFromNetwork(BuildTechNodeUpdateMessage(node))

		if node.instances then
			local removed = {}
			for entityId, instance in pairs(node.instances) do
				clientTechTree:UpdateNodeInstanceFromNetwork(BuildTechNodeInstanceMessage(node, entityId))
				if instance.removed then
					table.insert(removed, entityId)
				end
			end
			for _, entityId in ipairs(removed) do
				node.instances[entityId] = nil
			end
		end
	end

	changedNodes = {}
end

--------------------------------------------------------------------------------------------------
-- Scenarios
--------------------------------------------------------------------------------------------------

local kTick = 1 / 30

local function RunScenario(scenario)
	log = {}
	sounds = {}
	researchers = {}
	changedNodes = {}
	techData = {}
	instancedTechIds = {}
	now = 100

	advancedOptions.hudbars_a = scenario.hudBars or 0
	advancedOptions.hudbars_m = scenario.hudBars or 0

	BuildNodes(scenario.techs)
	player = NewPlayer()

	eventDisplay = CreateEventDisplay(script, 1, NewItem(), scenario.marine == true)

	print(string.format("\n=== %s", scenario.name))
	print(string.format("    %s stack, %d shown", scenario.marine and "marine" or "alien", eventDisplay.maxNotifications))

	local startTime = now
	local pending = {}
	for i, start in ipairs(scenario.starts) do
		pending[i] = start
	end

	local nextStart = 1
	local nextEvent = 1
	local events = scenario.events or {}

	while now - startTime < (scenario.duration or 180) do

		while pending[nextStart] and now - startTime >= pending[nextStart].at do
			StartResearch(nextStart, pending[nextStart].tech)
			nextStart = nextStart + 1
		end

		while events[nextEvent] and now - startTime >= events[nextEvent].at do
			local event = events[nextEvent]
			if event.cancel then
				CancelResearch(event.cancel)
			elseif event.respawn then
				-- Dying destroys the HUD, respawning builds it again, which is where
				-- GUIEvent:Initialize queues every research in progress afresh.
				Record("--- player died and respawned, HUD rebuilt ---")
				eventDisplay:Destroy()
				eventDisplay = CreateEventDisplay(script, 1, NewItem(), scenario.marine == true)
			end
			nextEvent = nextEvent + 1
		end

		ServerTick(kTick)
		eventDisplay:Update(kTick, PlayerUI_GetRecentNotification())

		now = now + kTick
	end

	for _, line in ipairs(log) do
		print(line)
	end

	-- Did every research that ran get a completion sound?
	print(string.format("    sounds played: %d of %d researches", #sounds, #scenario.starts))
end

local kAlienTechs =
{
	Leap             = { time = 40, techType = kTechType.Research },
	BileBomb         = { time = 40, techType = kTechType.Research },
	MetabolizeEnergy = { time = 40, techType = kTechType.Research },
	Umbra            = { time = 75, techType = kTechType.Research },
	Spores           = { time = 60, techType = kTechType.Research },
	UpgradeToCragHive  = { time = 20, techType = kTechType.Upgrade, instanced = true },
	UpgradeToShadeHive = { time = 20, techType = kTechType.Upgrade, instanced = true },
	UpgradeToShiftHive = { time = 20, techType = kTechType.Upgrade, instanced = true },
}

local kMarineTechs =
{
	Weapons1              = { time = 75, techType = kTechType.Research },
	Armor1                = { time = 75, techType = kTechType.Research },
	PhaseTech             = { time = 45, techType = kTechType.Research },
	AdvancedMarineSupport = { time = 60, techType = kTechType.Research },
	ShotgunTech           = { time = 30, techType = kTechType.Research },
	GrenadeTech           = { time = 45, techType = kTechType.Research },
	MinesTech             = { time = 20, techType = kTechType.Research },
	AdvancedArmoryUpgrade = { time = 90, techType = kTechType.Upgrade, instanced = true },
	UpgradeRoboticsFactory = { time = 20, techType = kTechType.Upgrade, instanced = true },
}

RunScenario
{
	name = "Alien, default HUD bars: four researches, the last one the quickest",
	techs = kAlienTechs,
	starts =
	{
		{ at = 0, tech = "BileBomb" },
		{ at = 2, tech = "MetabolizeEnergy" },
		{ at = 4, tech = "UpgradeToCragHive" },
		{ at = 6, tech = "UpgradeToShadeHive" },
	},
	duration = 60,
}

RunScenario
{
	name = "Alien, default HUD bars: the same four, quickest started FIRST",
	techs = kAlienTechs,
	starts =
	{
		{ at = 0, tech = "UpgradeToCragHive" },
		{ at = 2, tech = "UpgradeToShadeHive" },
		{ at = 4, tech = "Leap" },
		{ at = 6, tech = "BileBomb" },
	},
	duration = 60,
}

RunScenario
{
	name = "Alien, NS1 HUD bars (2 shown): three researches",
	techs = kAlienTechs,
	hudBars = 2,
	starts =
	{
		{ at = 0, tech = "BileBomb" },
		{ at = 2, tech = "UpgradeToCragHive" },
		{ at = 4, tech = "UpgradeToShadeHive" },
	},
	duration = 60,
}

RunScenario
{
	name = "Marine, default HUD bars (5 shown): six researches, the last one the quickest",
	techs = kMarineTechs,
	marine = true,
	starts =
	{
		{ at = 0, tech = "AdvancedArmoryUpgrade" },
		{ at = 2, tech = "Weapons1" },
		{ at = 4, tech = "Armor1" },
		{ at = 6, tech = "AdvancedMarineSupport" },
		{ at = 8, tech = "ShotgunTech" },
		{ at = 10, tech = "MinesTech" },
	},
	duration = 110,
}

RunScenario
{
	name = "Alien: a pushed out research is CANCELLED - is there a warning?",
	techs = kAlienTechs,
	starts =
	{
		{ at = 0, tech = "BileBomb" },
		{ at = 2, tech = "MetabolizeEnergy" },
		{ at = 4, tech = "UpgradeToCragHive" },
		{ at = 6, tech = "UpgradeToShadeHive" },
	},
	events =
	{
		{ at = 15, cancel = "MetabolizeEnergy" },
	},
	duration = 45,
}

RunScenario
{
	name = "Alien: four researches, none lost, then the player dies and respawns",
	techs = kAlienTechs,
	starts =
	{
		{ at = 0, tech = "UpgradeToCragHive" },
		{ at = 2, tech = "UpgradeToShadeHive" },
		{ at = 4, tech = "Leap" },
		{ at = 6, tech = "BileBomb" },
	},
	events =
	{
		{ at = 10, respawn = true },
	},
	duration = 60,
}

RunScenario
{
	name = "Marine, NS1 HUD bars (3 shown): four researches",
	techs = kMarineTechs,
	marine = true,
	hudBars = 2,
	starts =
	{
		{ at = 0, tech = "AdvancedArmoryUpgrade" },
		{ at = 2, tech = "Armor1" },
		{ at = 4, tech = "AdvancedMarineSupport" },
		{ at = 6, tech = "MinesTech" },
	},
	duration = 100,
}

-- Check: a research that is merely WAITING its turn and completes before a place frees.
kAlienTechs.BoneShield = { time = 40, techType = kTechType.Research }

RunScenario
{
	name = "Alien: the fourth research waits, and completes while still waiting",
	techs = kAlienTechs,
	starts =
	{
		{ at = 0, tech = "BileBomb" },
		{ at = 0.5, tech = "MetabolizeEnergy" },
		{ at = 1, tech = "Leap" },
		{ at = 1.5, tech = "BoneShield" },
	},
	duration = 55,
}
