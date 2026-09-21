-- Offline check of source functions; this does NOT reproduce the NS2 engine.
-- Run with Lua 5.4: this VM is not NS2's Lua 5.1/LuaJIT.
local vanilla, release, dev, cache = assert(arg[1]), assert(arg[2]), assert(arg[3]), assert(arg[4])
local function read(path)
    local f=assert(io.open(path,"rb")); local s=f:read("*a"); f:close()
    return s:gsub("\r\n","\n")
end
local function loadFile(e,path)
    assert(load(read(path),"@"..path,"t",e))()
end
local function method(e,path,signature)
    local s=read(path)
    local a=assert(s:find(signature,1,true),signature)
    local b=assert(s:find("\nend",a,true),"terminator")
    assert(load(s:sub(a,b+3),"@"..path..":"..signature,"t",e))()
end
local function environment(paths,isClient)
    local e=setmetatable({}, {__index=_G}); e._G=e
    e.PROFILE=function() end; e.ToString=tostring; e.kMaxHotkeyGroups=9
    e.CreateMixin=function(t) return t or {} end
    e.kTechId={None=0,RootMenu=1,BuildMenu=2,AdvancedMenu=3,AssistMenu=4,
        Armor1=5,Armor2=6,Armor3=7,Weapons1=8,Weapons2=9,Weapons3=10,
        Cancel=11,Recycle=12,Consume=13}
    e.Entity={invalidId=-1}; e.kResearchMod=1; e.kRecycleCancelButtonIndex=12
    e.bit={band=function(a,b)return a&b end,bor=function(a,b)return a|b end,bnot=function(a)return ~a end}
    e.bit_band=e.bit.band; e.bit_bor=e.bit.bor
    e.Shared={GetTime=function() return 100 end}
    e.Commander={}; e.ArmsLab={}; e.RecycleMixin={}
    local commander=setmetatable({
        currentTechId=0,menuTechId=2,
        isa=function(_,s)return s=="Commander" end,
        GetTeamNumber=function()return 1 end,
        GetMenuTechId=function(self)return self.menuTechId end,
        SetCurrentTech=function(self,id)self.menuTechId=id end,
        GetTeamType=function()return 1 end,
        GetQuickMenuTechButtons=function()return {2,3,4,1} end,
        GetIsInQuickMenu=function()return false end
    },{__index=e.Commander})
    local node={GetTechId=function()return 5 end,
        SetResearchProgress=function(self,p)self.progress=p end,
        SetResearched=function(self,r)self.researched=r end,
        GetIsEnergyManufacture=function()return false end,
        GetIsManufacture=function()return false end,
        GetIsPlasmaManufacture=function()return false end}
    local tree={GetTechNode=function(_,id)if id==5 then return node end end,
        SetTechNodeChanged=function()end,
        QueueOnResearchComplete=function(self,id,entity)self.queued={id,entity}end}
    local team={GetTechTree=function()return tree end}
    local lab={selectionMask=0,hotGroupNumber=0,researchProgress=.99,researchingId=5,
        GetId=function()return 100 end, GetTeamNumber=function()return 1 end,
        GetTeam=function()return team end,GetIsRecycled=function()return false end}
    e.HasMixin=function(entity,mixin)
        return entity==lab and (mixin=="Selectable" or mixin=="Team" or mixin=="Research" or mixin=="Recycle")
    end
    e.GetCommanderForTeam=function()return commander end
    e.GetEntitiesWithMixin=function()return {lab} end
    e.GetGamerules=function()return {GetAutobuild=function()return false end}end
    e.LookupTechData=function(_,_,default)return default end
    e.GetTechNode=function(id)
        if id and id>=1 and id<=4 then
            return {GetIsMenu=function()return true end,GetRequiresTarget=function()return false end,
                GetIsBuy=function()return false end,GetIsEnergyBuild=function()return false end}
        end
    end
    e.StatsUI_GetTechLoggedAsBuilding=function()return false end
    e.StatsUI_AddTechStat=function()end; e.StatsUI_AddExportResearch=function()end
    e.EnumToString=function()return "Armor1"end
    local messages={}
    e.BuildSelectUnitMessage=function(teamNo,unit,selected,keep)
        return {entity=unit,selected=selected,keep=keep}
    end
    e.Client=isClient and {
        GetLocalPlayer=function()return commander end,
        GetIsControllingPlayer=function()return true end,
        SendNetworkMessage=function(name,message) messages[#messages+1]={name,message}end
    } or false
    e.Server=not isClient
    loadFile(e,paths.selectable); loadFile(e,paths.research)
    method(e,paths.utility,"function UpdateMenuTechId(")
    method(e,paths.utility,"function DeselectAllUnits(")
    method(e,vanilla.."/Commander.lua","function Commander:GetCurrentTechButtons(")
    method(e,paths.arms,"function ArmsLab:GetTechButtons(")
    method(e,vanilla.."/RecycleMixin.lua","function RecycleMixin:OnResearchComplete(")
    method(e,vanilla.."/RecycleMixin.lua","function RecycleMixin:GetCanRecycle(")
    method(e,vanilla.."/RecycleMixin.lua","function RecycleMixin:GetRecycleActive(")
    for _,mixin in ipairs({e.ResearchMixin,e.SelectableMixin,e.ArmsLab,e.RecycleMixin}) do
        for k,v in pairs(mixin) do if type(v)=="function" then lab[k]=v end end
    end
    -- Relevancy updates are engine-facing; not simulated in this probe.
    lab.UpdateIncludeRelevancyMask=function()end
    if isClient then
        local listener
        local cursor={x=500,y=500}
        e.unique_set=function()
            local values={}
            return {Insert=function(_,value)values[#values+1]=value end,GetList=function()return values end}
        end
        e.kTeam1Index=1; e.kTeam2Index=2
        e.ConditionalValue=function(condition,a,b)if condition then return a else return b end end
        e.Client.GetScreenWidth=function()return 1920 end
        e.Client.GetScreenHeight=function()return 1080 end
        e.Client.WorldToScreen=function(origin)return origin end
        e.GetEntitiesWithMixinForTeam=function(_,teamNo)if teamNo==1 then return {lab}else return {}end end
        lab.isa=function(_,name)return name=="ArmsLab" or name=="Entity"end
        lab.GetClassName=function()return "ArmsLab"end
        lab.GetOrigin=function()return {x=530,y=530}end
        e.MainMenu_GetIsOpened=function()return false end
        e.CommanderGhostStructureSetTech=function()end
        commander.SendAction=function()end
        e.InputKey={MouseButton0=1,MouseButton1=2,MouseButton2=3}
        e.MouseTracker_ListenToButtons=function(l) listener=l end
        e.MouseTracker_ListenToMovement=function()end
        e.MouseTracker_GetCursorPos=function()return cursor end
        e.Vector=function(x,y,z)return {x=x,y=y,z=z}end
        e.CommanderUI_GetMouseIsOverUI=function()return false end
        e.GetMainMenu=function()return {GetVisible=function()return false end}end
        e.GetCommanderGhostStructureEnabled=function()return false end
        e.CreatePickRay=function()return {}end
        loadFile(e,vanilla.."/Commander_MarqueeSelection.lua")
        loadFile(e,vanilla.."/Commander_Selection.lua")
        method(e,paths.utility,"function GetSelectablesOnScreen(")
        method(e,vanilla.."/Commander_Client.lua","function Commander:ClientOnMouseRelease(")
        method(e,vanilla.."/Commander_Client.lua","function CommanderUI_OnMouseRelease(")
        method(e,vanilla.."/Commander_Client.lua","function Commander:SetCurrentTech(")
        commander.SetCurrentTech=e.Commander.SetCurrentTech
        -- Stub the engine ray hit; the tested click hits the building away from its projected origin.
        commander.GetUnitUnderCursor=function()return lab end
        loadFile(e,vanilla.."/Commander_MouseActions.lua")
        e.click=function()listener.OnMouseDown(nil,1,false)end
        e.release=function()listener.OnMouseUp(nil,1)end
        e.move=function(x,y)cursor={x=x,y=y}; listener.OnMouseMove()end
    end
    return e,lab,commander,tree,messages
end
local variants={
    {"installed vanilla",vanilla},
    {"installed CBM release",release},
    {"local CBM dev",dev},
    {"upstream beta",cache.."/ns2-beta-",true}
}
for _,v in ipairs(variants) do
    local function path(file)
        if v[3] then return v[2]..file end
        local candidate=v[2].."/"..file
        local f=io.open(candidate,"rb")
        if f then f:close(); return candidate end
        return vanilla.."/"..file
    end
    local paths={research=path("ResearchMixin.lua"),selectable=path("SelectableMixin.lua"),
        arms=path("ArmsLab.lua"),utility=path("NS2Utility.lua")}
    local c,cl,comm,_,messages=environment(paths,true)
    local s,sl,_,tree=environment(paths,false)
    c.click(); assert(cl:GetIsSelected(1) and comm.menuTechId==1)
    sl:SetSelected(1,true)
    assert(comm:GetCurrentTechButtons(1,cl)[12]==11,"research must show Cancel")
    sl:UpdateResearch(.001)
    assert(tree.queued and sl.researchProgress==1 and sl:GetIsSelected(1))
    -- Apply the replicated research fields; leave client selection untouched.
    cl.researchProgress=sl.researchProgress
    assert(cl:GetIsSelected(1) and comm.menuTechId==1)
    assert(comm:GetCurrentTechButtons(1,cl)[12]==12,"completed progress should show Recycle")
    sl:TechResearched(sl,5)
    assert(sl.researchingId==0 and sl:GetIsSelected(1))
    cl.researchProgress=sl.researchProgress; cl.researchingId=sl.researchingId
    assert(cl:GetIsSelected(1) and comm.menuTechId==1)
    c.click(); assert(cl:GetIsSelected(1) and comm.menuTechId==1)
    -- A stale server selection value alone must not overwrite the local cache.
    cl.selectionMask=0; cl.timeLastSelectionAutoUpdate=0
    assert(cl:GetIsSelected(1))
    cl:OnUpdate(.1)
    assert(messages[#messages][1]=="SelectUnit" and messages[#messages][2].selected==true)
    assert(cl:GetIsSelected(1) and comm.menuTechId==1)
    -- Negative control: an actual deselect DOES fail the selected-state checks.
    cl.selectionMask=1
    c.DeselectAllUnits(1)
    assert(not cl:GetIsSelected(1) and comm.menuTechId==2)
    print(v[1]..": click / 100% progress / completion / re-click preserve selection; Cancel -> Recycle; stale selection resends true; explicit deselect control detected")
    for _,releaseBefore in ipairs({true,false})do
        local e,entity,commander=environment(paths,true)
        e.click()
        if releaseBefore then e.release()end
        entity.researchProgress=1
        assert(entity:GetIsSelected(1) and commander.menuTechId==1)
        entity.researchingId=0; entity.researchProgress=0
        if not releaseBefore then e.release()end
        assert(entity:GetIsSelected(1) and commander.menuTechId==1)
    end
    -- Same world click with exactly five pixels of motion is still an ordinary click.
    local e,entity,commander=environment(paths,true)
    e.click(); e.move(505,500); e.release()
    assert(entity:GetIsSelected(1) and commander.menuTechId==1)
    -- A six-pixel drag with a rectangle excluding the projected origin clears the selection,
    -- both with and without research finishing. This is NOT proof of the reported cause.
    for _,complete in ipairs({false,true})do
        local e,entity,commander=environment(paths,true)
        e.click(); e.move(506,501)
        assert(e.GetIsCommanderMarqueeSelectorDown())
        if complete then entity.researchProgress=0;entity.researchingId=0 end
        assert(entity:GetIsSelected(1))
        e.release()
        assert(not entity:GetIsSelected(1) and commander.menuTechId==2)
    end
    print(v[1]..": stationary release before/after completion and 5-pixel motion preserve selection; 6-pixel empty marquee clears it on release, independently of completion")
end
print("Scope: actual source mouse callbacks, menu-setting and marquee functions with stubs; no engine ray tracing, actual packet ordering, rendering or full GUI lifecycle. The research-specific bug remains unconfirmed.")
