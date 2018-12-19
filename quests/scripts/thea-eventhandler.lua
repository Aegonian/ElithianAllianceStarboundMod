--This quest script checks if any new events went live and displays a notification window to alert the player to the activation of that event
--The notification window will also share the essentials of each new event to clarify non-obvious mechanics to the player

require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/quests/scripts/questutil.lua"
require "/quests/scripts/portraits.lua"
require "/scripts/thea-eventutil.lua"

function init()
  self.events = config.getParameter("events")
  
  storage.activeEvent = storage.activeEvent or {}
  self.activeEvent = {}
  
  --For every configured event, check if it is active now
  local anyEventActive = false
  for _, event in ipairs(self.events) do
	if checkEventActive(event[1]) then
	  self.activeEvent = event
	  anyEventActive = true
	end
  end
  
  --If no event is active, reset the stored active event
  if not anyEventActive then
	storage.activeEvent = nil
  end
end

function questStart()
  
end

function update(dt)
  --If an event is now active that wasn't active before, show the associated notification window
  --Must run this in update() as the interact action fails when used during init()
  if self.activeEvent[1] ~= storage.activeEvent[1] then
	player.interact("ScriptPane", self.activeEvent[2], player.id())
	storage.activeEvent = self.activeEvent
  end
  
  --world.debugText("EVENT HANDLER ACTIVE", vec2.add(entity.position(), {-3, -10}), "yellow")
  --world.debugText(sb.printJson(storage.activeEvent, 1), vec2.add(entity.position(), {-3, -10}), "yellow")
end

function uninit()
  
end

--This function gets called if anything causes the quest to complete or fail. It will automatically reactivate the quest
function questComplete()
  player.startQuest("thea-eventhandler")
end
