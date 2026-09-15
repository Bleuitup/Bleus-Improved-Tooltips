-- Dumps every TechData entry that has a tooltip, with its English name and text, as TSV.
--
--   lua tools/extract_tooltips.lua <root> <out.tsv> <file list>
--
-- <root> holds lua/ and gamestrings/enUS.txt (the NS2 ns2 folder, or a copy of a mod's lua/ with its
-- Locale.substitutions merged into enUS.txt). <file list> is `find . -name "*.lua"` run inside <root>/lua.
-- Flags column: R research, B buildable, C cooldown, v named in a commander or GetTechButtons file.
-- Used for docs/tooltip-text-audit.md.

local root, outPath, listPath = arg[1], arg[2], arg[3]
local function read(p) local f=io.open(p,"rb"); if not f then return nil end; local s=f:read("a"); f:close(); return s end
local strings = {}
for line in (read(root.."/gamestrings/enUS.txt") or ""):gmatch("[^\r\n]+") do
  local k, v = line:match('^%s*\239?\187?\191?([%w_]+)%s*=%s*"(.*)"%s*$')
  if k then strings[k] = v end
end
local td = read(root.."/lua/TechData.lua")
local tech, order, pos = {}, {}, 1
while true do
  local s, e, id = td:find("%[kTechDataId%]%s*=%s*kTechId%.([%w_]+)", pos)
  if not s then break end
  local nextS = td:find("%[kTechDataId%]", e) or #td
  local body = td:sub(e, nextS)
  if not tech[id] then tech[id] = {}; order[#order+1] = id end
  local t = tech[id]
  t.name = body:match('%[kTechDataDisplayName%]%s*=%s*"([%w_]+)"') or t.name
  t.tip = body:match('%[kTechDataTooltipInfo%]%s*=%s*"([%w_]+)"') or t.tip
  t.research = t.research or body:find("kTechDataResearchTimeKey") ~= nil
  t.build = t.build or body:find("kTechDataBuildTime") ~= nil
  t.cooldown = t.cooldown or body:find("kTechDataCooldown") ~= nil
  pos = e
end
-- visibility: any kTechId mention in commander/structure files (loose)
local seen = {}
for file in io.open(listPath):lines() do
  local src = read(root.."/lua/"..file:sub(3))
  if src and (src:find("GetTechButtons") or file:find("Commander")) then
    for id in src:gmatch("kTechId%.([%w_]+)") do seen[id] = true end
  end
end
local out = io.open(outPath, "wb")
for _, id in ipairs(order) do
  local t = tech[id]
  if t.tip then
    local flags = (t.research and "R" or "")..(t.build and "B" or "")..(t.cooldown and "C" or "")..(seen[id] and "v" or "")
    out:write(id,"\t",flags,"\t",strings[t.name or ""] or (t.name or ""),"\t",strings[t.tip] or ("<"..t.tip..">"),"\n")
  end
end
out:close()
