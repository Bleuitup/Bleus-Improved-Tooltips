-- Source-level regression probes; never connects to or modifies the running game.
-- Lua 5.4 is the available harness VM, not NS2's Lua 5.1/LuaJIT runtime.
local vanilla, cbmRelease, cbmDev, snapshots = assert(arg[1]), assert(arg[2]), assert(arg[3]), assert(arg[4])
local function read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a")
    f:close()
    return s:gsub("\r\n", "\n")
end
local function env()
    local e = setmetatable({}, {__index = _G})
    e._G = e
    e.Script = {Load=function() end}
    e.PROFILE = function() end
    e.Server = {DestroyRelevancyPortal=function() end}
    e.Client = false
    e.Shared = {LinkClassToMap=function() end}
    e.CreateMixin = function(t) return t or {} end
    e.AddMixinNetworkVars = function() end
    e.PrecacheAsset = function(s) return s end
    e.class = function(name)
        local c = {}; e[name] = c
        return function(base)
            for k,v in pairs(base or {}) do c[k]=v end
        end
    end
    return e
end
local function file(e,path)
    assert(load(read(path),"@"..path,"t",e))()
end
-- Extract entire named functions, preserving all their control flow and nested bodies.
-- The expected terminating end must match the function's indentation.
local function method(e,path,signature,indent)
    indent = indent or ""
    local s=read(path)
    local first=assert(s:find(indent..signature,1,true),signature.." missing from "..path)
    local ending=assert(s:find("\n"..indent.."end",first,true),"function terminator missing")
    local body=s:sub(first,ending+#indent+3)
    assert(load(body,"@"..path..":"..signature,"t",e))()
end
local function powerProbe(label,powerPath,obsPath)
    local e=env()
    local now=0
    e.Shared.GetTime=function() return now end
    e.kPowerSurgeTriggerEMP=false
    file(e,powerPath)
    e.Observatory={}
    -- Compile the actual local helper and methods together so its lexical scope is retained.
    local helperSource=read(obsPath)
    local first=assert(helperSource:find("local function DestroyRelevancyPortal(self)",1,true))
    local ending=assert(helperSource:find("\nend",first,true))
    local helper=helperSource:sub(first,ending+3)
    local functions={helper}
    for _,name in ipairs({"CancelDistressBeacon","GetIsBeaconing","OnPowerOff"}) do
        local signature="function Observatory:"..name.."("
        local start=assert(helperSource:find(signature,1,true))
        local finish=assert(helperSource:find("\nend",start,true))
        functions[#functions+1]=helperSource:sub(start,finish+3)
    end
    assert(load(table.concat(functions,"\n"),"@"..obsPath..":beacon methods","t",e))()
    local stopped=false
    local obs={powered=false,powerBattery=false,distressBeaconSound={Stop=function() stopped=true end}}
    for k,v in pairs(e.PowerConsumerMixin) do obs[k]=v end
    for k,v in pairs(e.Observatory) do obs[k]=v end
    obs:SetPowerSurgeDuration(10)
    -- The node is repaired during the surge, and a beacon begins before expiry.
    now=8
    obs:SetPowerOn()
    obs.distressBeaconTime=14
    assert(obs:GetIsPowered() and obs:GetIsBeaconing())
    now=10.1
    obs:OnUpdate(0.1)
    assert(obs:GetIsPowered()==true)
    assert(obs.distressBeaconTime==nil and stopped)
    print(label..": surge expiry CANCELS beacon while GetIsPowered() remains true")
    -- Control: no surge expiry means the beacon survives.
    stopped=false; obs.distressBeaconTime=14
    obs:OnUpdate(0.1)
    assert(obs:GetIsBeaconing() and not stopped)
end
local function ammoProbe(label,root,paths)
    paths=paths or {root.."/DropPack.lua",root.."/AmmoPack.lua",root.."/Weapons/Marine/ClipWeapon.lua"}
    local e=env()
    e.ScriptActor={OnUpdate=function() end,OnInitialized=function() end}
    file(e,paths[1])
    file(e,paths[2])
    e.ClipWeapon={}
    method(e,paths[3],"function ClipWeapon:GiveReserveAmmo(")
    method(e,paths[3],"function ClipWeapon:GetNeedsAmmo(")
    local function weapon(name,ammo,max)
        return setmetatable({ammo=ammo,
            isa=function(_,t) return t==name or t=="ClipWeapon" end,
            GetAmmo=function(self) return self.ammo end,
            GetMaxAmmo=function() return max end
        },{__index=e.ClipWeapon})
    end
    local rifle,pistol=weapon("Rifle",200,200),weapon("Pistol",9,40)
    local marine={
        isa=function(_,t) return t=="Marine" end,
        GetNumChildren=function() return 2 end,
        GetTeamNumber=function() return 1 end,
        GetChildAtIndex=function(_,i) return i==0 and rifle or pistol end,
        GetActiveWeapon=function() return rifle end,
        GetCoords=function() return {} end
    }
    local pack=setmetatable({ammoPackSize=50,weapon=7,pickupRange=1,
        GetOrigin=function() return 0 end,
        GetTeamNumber=function() return 1 end,
        TriggerEffects=function() end
    },{__index=e.RifleAmmo})
    e.Shared.GetEntity=function() return {weaponWorldState=true,GetOrigin=function() return 0 end} end
    e.Shared.SortEntitiesByDistance=function() end
    e.GetEntitiesForTeamWithinXZRange=function() return {marine} end
    e.GetEntitiesWithinXZRange=function() return {marine} end
    e.DestroyEntity=function(x) x.destroyed=true end
    assert(pack:GetIsValidRecipient(marine)==true)
    pack:OnUpdate(0)
    assert(pack.destroyed and rifle.ammo==200 and pistol.ammo==9)
    print(label..": rifle ammo pickup DESTROYED; rifle remains 200/200, pistol remains 9/40")
    -- Control: when every weapon is full the same pack is correctly rejected.
    pistol.ammo=40
    assert(pack:GetIsValidRecipient(marine)==false)
end
local function chatProbe(label,path)
    local e=env()
    local now=100
    e.Server=false
    e.Client={GetSteamId=function() return 1 end,HookNetworkMessage=function() end}
    e.Event={Hook=function() end}
    e.Shared.GetSystemTime=function() return now end
    e.Color=function() return {} end
    e.ConditionalValue=function(test,a,b) if test then return a else return b end end
    e.io={open=function() return nil end}
    file(e,path)
    e.ChatUI_SetSteamIdTextMuted(2,true)
    assert(e.ChatUI_GetSteamIdTextMuted(2)==true)
    now=100+6*3600+1
    assert(e.ChatUI_GetSteamIdTextMuted(2)==true)
    -- Actual explicit unmute still works: the problem is expiry handling.
    e.ChatUI_SetSteamIdTextMuted(2,false)
    assert(e.ChatUI_GetSteamIdTextMuted(2)==false)
    print(label..": text mute remains ACTIVE after its six-hour expiry")
    local serverMuted=false
    local sent=0
    e.Client.GetLocalPlayer=function()
        return {GetClientIndex=function() return 1 end,GetTeamNumber=function() return 1 end}
    end
    e.Client.GetLocalClientIndex=function() return 1 end
    e.Client.GetVoiceChannelForClient=function() return 0 end
    e.Client.SendNetworkMessage=function(_,message) serverMuted=message.mute; sent=sent+1 end
    e.GetSteamIdForClientIndex=function(index) return index end
    e.BuildMutePlayerMessage=function(index,mute) return {index=index,mute=mute} end
    e.ChatUI_SetClientMuted(2,true)
    assert(serverMuted and e.ChatUI_GetClientMuted(2))
    now=now+6*3600+1
    e.ChatUI_GetVoiceChannelForClient(2)
    assert(serverMuted and e.ChatUI_GetClientMuted(2) and sent==1)
    e.ChatUI_SetClientMuted(2,false)
    assert(not serverMuted and not e.ChatUI_GetClientMuted(2))
    print(label..": voice mute remains ACTIVE after expiry; no unmute message is sent")
end
powerProbe("installed vanilla",vanilla.."/PowerConsumerMixin.lua",vanilla.."/Observatory.lua")
powerProbe("CBM release",cbmRelease.."/PowerConsumerMixin.lua",cbmRelease.."/Observatory.lua")
powerProbe("CBM dev",cbmDev.."/PowerConsumerMixin.lua",cbmDev.."/Observatory.lua")
powerProbe("Ghoul beta",snapshots.."/ns2-beta-PowerConsumerMixin.lua",snapshots.."/ns2-beta-Observatory.lua")
powerProbe("public CBM main",snapshots.."/cbm-main-PowerConsumerMixin.lua",snapshots.."/cbm-main-Observatory.lua")
ammoProbe("installed vanilla",vanilla)
ammoProbe("CBM release",cbmRelease)
ammoProbe("CBM dev",cbmDev)
chatProbe("installed vanilla (also inherited by local CBM)",vanilla.."/Chat.lua")
chatProbe("Ghoul beta",snapshots.."/ns2-beta-Chat.lua")
ammoProbe("Ghoul beta",nil,{snapshots.."/ns2-beta-DropPack.lua",snapshots.."/ns2-beta-AmmoPack.lua",snapshots.."/ns2-beta-ClipWeapon.lua"})
powerProbe("Ghoul master / hotfix-344 / bdt-344",vanilla.."/PowerConsumerMixin.lua",snapshots.."/ns2-master-Observatory.lua")
powerProbe("Ghoul CBM core-only",snapshots.."/ns2-beta-PowerConsumerMixin.lua",snapshots.."/ns2-core-only-Observatory.lua")
ammoProbe("public CBM fixes branch",nil,{cbmRelease.."/DropPack.lua",cbmRelease.."/AmmoPack.lua",snapshots.."/cbm-fixes-ClipWeapon.lua"})
print("All source probes reproduced. No live game or visual tests were performed.")
