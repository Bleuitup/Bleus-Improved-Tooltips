-- Audit probes: real source functions with minimal engine/GUI stand-ins.
-- Run using Lua 5.4: lua audit-probes.lua <repo> <downloaded-source-directory>
local repo, upstream = assert(arg[1]), assert(arg[2])
local function read(path)
 local f=assert(io.open(path,"rb")); local s=f:read("*a"); f:close(); return s
end
local function loadInto(path, env)
 assert(loadfile(path,"t",env))()
end
local function baseEnv()
 local env=setmetatable({}, {__index=_G})
 env.Script={Load=function() end}
 env.kTechId={None=0}
 env.Server=true
 env.Client=false
 env.Clamp=function(x,a,b) return math.max(a,math.min(b,x)) end
 env.Shared={GetTime=function() return 100 end}
 env.ImprovedTooltips={
  SendToPlayer=function() end,
  SendToTeam=function() end,
  GetTechIdsWithCooldown=function() return {10} end
 }
 return env
end
local mod=repo.."/source/lua/ImprovedTooltips/"
do
 local env=baseEnv()
 local sent={}
 env.BuildImprovedTooltipsCooldownMessage=function(techId,startTime,clear)
  return {techId=techId,startTime=startTime,clear=clear}
 end
 env.ImprovedTooltips.SendToPlayer=function(player,name,message) sent[#sent+1]=message end
 env.LookupTechData=function() return 20 end
 local commander={GetCooldownFraction=function() return .5 end}
 local team={GetCommander=function() return commander end}
 env.GetGamerules=function() return {GetTeam=function() return team end} end
 loadInto(mod.."ImprovedTooltips_CooldownState.lua",env)
 env.ImprovedTooltips.ResyncPlayerCooldowns({},2)
 assert(#sent==2 and sent[1].clear and sent[2].startTime==90)
 local occupied=#sent
 commander=nil
 sent={}
 env.ImprovedTooltips.ResyncPlayerCooldowns({},2)
 assert(#sent==1 and sent[1].clear)
 print("MOD cooldown join: occupied seat sends clear + active cooldown; empty seat sends only clear.")
end
do
 local env=baseEnv()
 local sent={}
 env.ImprovedTooltips.SendToPlayer=function(player,name,msg)
  sent[#sent+1]={team=player:GetTeamNumber(),msg=msg}
 end
 env.ImprovedTooltips.ResyncPlayerCooldowns=function() end
 env.BuildImprovedTooltipsHiveStateMessage=function(locationId,state,clear)
  return {locationId=locationId,state=state,clear=clear}
 end
 local player={GetTeamNumber=function() return 1 end}
 env.NS2Gamerules={JoinTeam=function() return true,player end}
 loadInto(mod.."ImprovedTooltips_HiveState.lua",env)
 env.ImprovedTooltips.publishedHiveState[42]=env.ImprovedTooltips.MakeHiveState(3,10,.5,11,.2)
 loadInto(mod.."ImprovedTooltips_TeamJoin.lua",env)
 env.NS2Gamerules:JoinTeam(player,1,false)
 assert(#sent==2 and sent[2].team==1 and sent[2].msg.locationId==42)
 print("MOD team join: marine recipient receives clear + alien Hive location 42, biomass and both researches.")
end
local function runNotificationProbe(fileName)
 local env=setmetatable({}, {__index=_G})
 local now=0
 local sounds=0
 env.Script={Load=function() end}
 env.class=function(name) env[name]={}; return function() end end
 env.Vector=function() return setmetatable({}, {__add=function(a,b) return a end}) end
 env.Color=function() return {} end
 env.Event={Hook=function() end}
 env.Client={GetTime=function() return now end,GetLocalPlayer=function()
  return {TriggerEffects=function() sounds=sounds+1 end}
 end}
 env.Shared={GetTime=function() return now end}
 env.Clamp=function(x,a,b) return math.max(a,math.min(b,x)) end
 env.ConditionalValue=function(x,a,b) if x then return a else return b end end
 local nodes={}
 local tree={
  GetTechNode=function(_,id) return nodes[id] end,
  GetResearchInProgress=function(_,id) return nodes[id].active end,
  GetAndClearTechTreeResearchCancelled=function() return false end
 }
 env.GetTechTree=function() return tree end
 env.GetTechNode=function(id) return nodes[id] end
 env.GUIUnpackCoords=function() return 0,0,1,1 end
 local function noOp() end
 local function graphic()
  return {SetText=noOp,SetSize=noOp,SetPosition=noOp,SetTexturePixelCoordinates=noOp,FadeOut=noOp}
 end
 local item={kResearchCompleteStayTime=0}
 env.GUINotificationItem=item
 local originalItems=read(upstream.."/ns2-beta-GUINotificationItem.lua")
 local tail=assert(originalItems:find("function GUINotificationItem:FadeOut",1,true))
 assert(load(originalItems:sub(tail),"@actual-GUINotificationItem-fade-tail","t",env))()
 env.CreateNotificationItem=function(_,id,scale,frame,marine,entityId)
  local n=setmetatable({
   techId=id,entityId=entityId,lastProgress=0,position=0,destroyTime=0,
   bottomText=graphic(),progressBar=graphic(),progressBarSize={x=1,y=10},
   progressBarTextureCoords={0,0,1,10},
   guiOffsets={ProgressBarGlowRadius=1,ProgressBarPos=env.Vector()},
  },{__index=item})
  return n
 end
 item.UpdateItem=noOp
 item.FadeIn=noOp
 item.SetPositionInstant=function(self,p) self.position=p end
 item.ShiftDown=function(self) self.position=self.position+1 end
 item.ShiftUp=function(self,n) self.position=self.position-(n or 1) end
 item.Destroy=function(self) self.destroyed=true end
 item.GetCompleted=function(self) return self.completed end
 item.GetCancelled=function(self) return self.cancelled end
 item.SetCompleted=function(self) self.completed=true;self.completeTime=now end
 item.SetCancelled=function(self) self.cancelled=true;self.completeTime=now end
 loadInto(upstream.."/"..fileName,env)
 local ui=setmetatable({
   displayedNotifications={},notificationsData={},maxNotifications=2,
   scale=1,useMarineStyle=false,frame={}
 },{__index=env.GUIEvent})
 for id,duration in ipairs({100,80,10}) do
  local node={time=duration,progress=.1,active=true}
  node.GetResearchProgress=function(self) return self.progress end
  nodes[id]=node
  ui:Update(0,{techId=id})
 end
 -- Long research 1 was pushed out of the two visible slots by shorter research 3.
 now=.6
 ui:Update(.6,nil)
 local found=false
 for _,v in ipairs(ui.notificationsData) do if v.techId==1 then found=true end end
 assert(not found and nodes[1].active)
 -- Finish and retire the remaining visible researches.
 nodes[2].progress=1;nodes[2].active=false
 nodes[3].progress=1;nodes[3].active=false
 ui:Update(0,nil)
 now=1;ui:Update(.4,nil)
 now=2.1;ui:Update(1.1,nil)
 assert(#ui.notificationsData==0 and nodes[1].active)
 local before=sounds
 nodes[1].progress=1;nodes[1].active=false
 ui:Update(0,nil)
 assert(sounds==before)
 print("UPSTREAM "..fileName..": active overflow research lost from queue; stays absent when space frees; later completion has no sound.")
end
for _,name in ipairs({
 "ns2-beta-GUIEvent.lua","ns2-master-GUIEvent.lua",
 "ns2-core-GUIEvent.lua","ns2-devnull-GUIEvent.lua"
}) do runNotificationProbe(name) end
print("All six source-level probes reproduced the investigated behaviors. Not an in-game rendering test.")
