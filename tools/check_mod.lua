-- Bleu's Improved Tooltips
-- tools/check_mod.lua
--
-- A static check of source/, run before committing. NS2 code only really runs in game, so this
-- catches the mistakes that can be caught without it:
--
--   1. Every file parses (luac).
--   2. Every Script.Load and ModLoader.SetupFileHook target in the mod exists.
--   3. Every IT.<name> or ImprovedTooltips.<name> that is read is assigned somewhere.
--   4. No function reads a global that its own file declares as a local. Lua silently treats a
--      name used before its "local" line as a global, which is nil at runtime - the mistake that
--      broke the research sound (originalUpdateRef) during development.
--   5. No new global names. Every global the mod reads is checked against
--      tools/check_mod_globals.txt, the NS2 API names already in use. A new one is either a typo or
--      a real new dependency; after checking which, add it with --write-baseline.
--   6. Every file's top level runs without error against a stub game: any global the game would
--      provide is a stand-in that accepts any use. This catches mistakes in code that runs at load,
--      not inside functions.
--   7. Every Mods panel default matches the config's value for the same field.
--
-- Lua 5.4, while NS2 runs 5.1, so a pass here is not proof of 5.1 compatibility.
--
-- Run from the repository root, with luac.exe beside lua.exe:
--
--   lua tools/check_mod.lua                   check
--   lua tools/check_mod.lua --write-baseline  also rewrite the known globals list

local kSourceRoot = "source/"
local kModDir = "source/lua/ImprovedTooltips/"
local kBaselinePath = "tools/check_mod_globals.txt"

local writeBaseline = false
for i = 1, #arg do
	if arg[i] == "--write-baseline" then
		writeBaseline = true
	end
end

-- luac beside the interpreter running this. Two substitutions, because a Lua pattern cannot make a
-- whole group optional.
local luac = arg[-1] or "lua"
if luac:match("lua%.exe$") then
	luac = luac:gsub("lua%.exe$", "luac.exe")
else
	luac = luac:gsub("lua$", "luac")
end
-- A Git Bash style path (/c/Users/...) means nothing to cmd.exe, which io.popen uses on Windows.
luac = luac:gsub("^/(%a)/", "%1:/")

local errors = { }
local warnings = { }

local function Fail(fmt, ...)
	errors[#errors + 1] = string.format(fmt, ...)
end

local function ReadFile(path)
	local file = io.open(path, "rb")
	if not file then
		return nil
	end
	local text = file:read("a")
	file:close()
	return text
end

local function FileExists(path)
	local file = io.open(path, "rb")
	if file then
		file:close()
		return true
	end
	return false
end

local function Quote(path)
	return '"' .. path .. '"'
end

------------------------------------------------------------------------------------------------
-- The file list
------------------------------------------------------------------------------------------------

local files = { }

do
	local command = package.config:sub(1, 1) == "\\"
		and ('dir /b /a-d "' .. kModDir:gsub("/", "\\") .. '*.lua"')
		or ("ls -1 " .. kModDir .. "*.lua")
	local pipe = io.popen(command)
	for line in pipe:lines() do
		local name = line:match("([^/\\]+%.lua)%s*$")
		if name then
			files[#files + 1] = kModDir .. name
		end
	end
	pipe:close()
	table.sort(files)
end

if #files == 0 then
	print("check_mod: no files found under " .. kModDir .. " - run from the repository root")
	os.exit(2)
end

local sources = { }
for _, path in ipairs(files) do
	sources[path] = ReadFile(path)
end

------------------------------------------------------------------------------------------------
-- 1 and 4: parse, and list global reads and writes per file
------------------------------------------------------------------------------------------------

local globalReads = { }    -- [path] = { [name] = first line }
local globalWrites = { }   -- [name] = true

for _, path in ipairs(files) do

	local command = Quote(luac) .. " -p -l -l " .. Quote(path) .. " 2>&1"
	if package.config:sub(1, 1) == "\\" then
		-- cmd.exe strips the first and last quote of a command line that starts with one, which
		-- would break the quoted luac path. One more pair around the whole line is the usual cure.
		command = '"' .. command .. '"'
	end

	local pipe = io.popen(command)
	local listing = pipe:read("a")
	pipe:close()

	-- Every successful listing starts with the main chunk. Anything else is a parse error, or luac
	-- could not be run at all - which must not pass silently.
	if not listing:match("main <") then
		Fail("%s does not parse, or luac could not run:\n%s", path, listing)
	end

	local reads = { }
	for line, op, name in listing:gmatch("%s%d+%s+%[(%d+)%]%s+([GS]ETTABUP)%s[^\n]-; _ENV \"([%w_]+)\"") do
		if op == "GETTABUP" then
			reads[name] = reads[name] or tonumber(line)
		else
			globalWrites[name] = true
		end
	end
	globalReads[path] = reads

end

-- Classes declared with class 'Name' become globals without a SETTABUP.
for _, path in ipairs(files) do
	for name in sources[path]:gmatch("class%s*'([%w_]+)'") do
		globalWrites[name] = true
	end
end

for _, path in ipairs(files) do

	local text = sources[path]
	local locals = { }

	for name in text:gmatch("local%s+function%s+([%w_]+)") do
		locals[name] = true
	end
	for names in text:gmatch("\n%s*local%s+([%w_,%s]-)%s*=") do
		for name in names:gmatch("[%w_]+") do
			locals[name] = true
		end
	end
	for name in text:gmatch("\n%s*local%s+([%w_]+)%s*\n") do
		locals[name] = true
	end

	for name, line in pairs(globalReads[path]) do
		if locals[name] then
			Fail("%s:%d reads global '%s', which this file declares as a local - used before its declaration?", path, line, name)
		end
	end

end

------------------------------------------------------------------------------------------------
-- 5: unknown globals
------------------------------------------------------------------------------------------------

local baseline = { }
do
	local text = ReadFile(kBaselinePath)
	if text then
		for name in text:gmatch("[^\r\n]+") do
			baseline[name] = true
		end
	end
end

local allExternal = { }

for _, path in ipairs(files) do
	for name, line in pairs(globalReads[path]) do
		if not globalWrites[name] then
			allExternal[name] = true
			if not baseline[name] and not writeBaseline then
				Fail("%s:%d reads unknown global '%s' (a typo, or a new NS2 dependency: check, then --write-baseline)", path, line, name)
			end
		end
	end
end

if writeBaseline then
	local names = { }
	for name in pairs(allExternal) do
		names[#names + 1] = name
	end
	table.sort(names)
	local file = io.open(kBaselinePath, "wb")
	file:write(table.concat(names, "\n"), "\n")
	file:close()
	print(string.format("check_mod: wrote %d known globals to %s", #names, kBaselinePath))
end

------------------------------------------------------------------------------------------------
-- 2: load and hook targets
------------------------------------------------------------------------------------------------

for _, path in ipairs(files) do
	local text = sources[path]
	for target in text:gmatch("Script%.Load%(%s*\"(lua/ImprovedTooltips/[^\"]+)\"") do
		if not FileExists(kSourceRoot .. target) then
			Fail("%s loads missing file %s", path, target)
		end
	end
	for target in text:gmatch("SetupFileHook%(%s*\"[^\"]+\"%s*,%s*\"(lua/ImprovedTooltips/[^\"]+)\"") do
		if not FileExists(kSourceRoot .. target) then
			Fail("%s hooks missing file %s", path, target)
		end
	end
end

do
	local entry = ReadFile(kSourceRoot .. "lua/entry/ImprovedTooltips.entry")
	local hooks = entry and entry:match("FileHooks%s*=%s*\"([^\"]+)\"")
	if not hooks or not FileExists(kSourceRoot .. hooks) then
		Fail("lua/entry/ImprovedTooltips.entry is missing or names a missing FileHooks file")
	end
end

------------------------------------------------------------------------------------------------
-- 3: IT names read but never assigned
------------------------------------------------------------------------------------------------

do
	local defined = { }
	local reads = { }

	for _, path in ipairs(files) do
		local text = sources[path]
		for _, prefix in ipairs({ "IT", "ImprovedTooltips" }) do
			local pattern = "%f[%w_]" .. prefix .. "%.([%a_][%w_]*)"
			for name in text:gmatch(pattern .. "%s*=%f[^=]") do
				defined[name] = true
			end
			for name in text:gmatch("function%s+" .. prefix .. "%.([%a_][%w_]*)") do
				defined[name] = true
			end
			for name in text:gmatch(pattern) do
				reads[name] = reads[name] or path
			end
		end
	end

	for name, path in pairs(reads) do
		if not defined[name] then
			Fail("%s reads IT.%s, which nothing assigns", path, name)
		end
	end
end

------------------------------------------------------------------------------------------------
-- 6: run every file's top level against a stub game
------------------------------------------------------------------------------------------------

do
	-- A stand-in for anything the game provides: any field, call, arithmetic or comparison on it
	-- gives another stand-in, and fields assigned to it are kept.
	local Stub
	local stubMeta = { }

	local function Unwrap(value)
		return value
	end

	Stub = function(label)
		return setmetatable({ __label = label }, stubMeta)
	end

	stubMeta.__index = function(self, key)
		local value = Stub(tostring(rawget(self, "__label")) .. "." .. tostring(key))
		rawset(self, key, value)
		return value
	end
	stubMeta.__call = function(self, ...)
		return Stub(tostring(rawget(self, "__label")) .. "()")
	end
	for _, op in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__unm", "__pow", "__concat", "__idiv" }) do
		stubMeta[op] = function(a, b)
			if op == "__concat" then
				return tostring(Unwrap(a)) .. tostring(Unwrap(b))
			end
			return Stub("arith")
		end
	end
	stubMeta.__lt = function() return false end
	stubMeta.__le = function() return true end
	stubMeta.__len = function() return 0 end
	stubMeta.__tostring = function(self) return "stub:" .. tostring(rawget(self, "__label")) end

	local loaded = { }
	local configSnapshot = nil

	-- Names that must read as nil until a mod file assigns them, as they do in game.
	local kStartNil = { ImprovedTooltips = true }

	-- One shared environment, so ImprovedTooltips and the functions files define for each other are
	-- visible across files the way they are in game.
	local shared = setmetatable({ }, { __index = function(self, key)
		if kStartNil[key] then
			return nil
		end
		local value = _G[key]
		if value ~= nil then
			return value
		end
		value = Stub(key)
		rawset(self, key, value)
		return value
	end })

	shared.Script = { Load = function(target)
		local path = kSourceRoot .. target
		if target:match("^lua/ImprovedTooltips/") and not loaded[path] then
			loaded[path] = true
			local chunk, err = load(ReadFile(path) or "", "@" .. path, "t", shared)
			if not chunk then
				Fail("%s: %s", path, err)
				return
			end
			local ok, runErr = pcall(chunk)
			if not ok then
				Fail("%s fails at load against the stub game: %s", path, tostring(runErr))
			end
			-- The config's own values, before the Mods panel file writes stored options over them.
			if target == "lua/ImprovedTooltips/ImprovedTooltips_Config.lua" and not configSnapshot then
				configSnapshot = { }
				for key, value in pairs(rawget(shared, "ImprovedTooltips") or { }) do
					configSnapshot[key] = value
				end
			end
		end
	end }
	shared.class = function(name)
		shared[name] = shared[name] or Stub(name)
		return function() end
	end
	-- The few game functions whose results load-time code does arithmetic on.
	local function ReturnDefault(_, default) return default end
	shared.Client = Stub("Client")
	rawset(shared.Client, "GetOptionBoolean", ReturnDefault)
	rawset(shared.Client, "GetOptionInteger", ReturnDefault)
	rawset(shared.Client, "GetOptionFloat", ReturnDefault)
	rawset(shared.Client, "GetOptionString", ReturnDefault)
	shared.Clamp = function(value, low, high) return math.min(math.max(value, low), high) end
	shared.Server = Stub("Server")
	shared.decoda_name = "Client"

	for _, path in ipairs(files) do
		if not loaded[path] then
			shared.Script.Load(path:sub(#kSourceRoot + 1))
		end
	end

	-- 7: every Mods panel default matches the config's value for the same field.
	local IT = rawget(shared, "ImprovedTooltips")
	local options = IT and rawget(IT, "kModsMenuOptions")
	if not options or not configSnapshot then
		Fail("could not compare Mods panel defaults with the config (kModsMenuOptions or the config missing)")
	else
		for _, option in ipairs(options) do
			local expected = option.default
			if option.read then
				expected = option.read(expected)
			end
			if configSnapshot[option.field] ~= expected then
				Fail("Mods panel default for %s is %s, but the config sets IT.%s to %s",
					option.key, tostring(expected), option.field, tostring(configSnapshot[option.field]))
			end
		end
	end
end

------------------------------------------------------------------------------------------------

for _, message in ipairs(warnings) do
	print("warning: " .. message)
end

if #errors > 0 then
	for _, message in ipairs(errors) do
		print("error: " .. message)
	end
	print(string.format("check_mod: %d problem(s) in %d files", #errors, #files))
	os.exit(1)
end

print(string.format("check_mod: OK, %d files", #files))
