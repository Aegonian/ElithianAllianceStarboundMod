require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/quests/scripts/questutil.lua"
require("/quests/scripts/portraits.lua")

--QUEST INITIALIZATION
function init()
  self.radioMessages = config.getParameter("radioMessages")
  self.messageInterval = config.getParameter("messageInterval")

  setPortraits()
  
  self.description = config.getParameter("description")
  if self.description then
    quest.setObjectiveList({{ self.description, false }})
  end
  
  storage.messagesLeft = storage.messagesLeft or #self.radioMessages
  storage.currentMessageIndex = storage.currentMessageIndex or 1
  self.messageTimer = self.messageInterval - config.getParameter("initialMessageDelay")
  
  sb.logInfo("THEA MOD INFO: Started a THEA story quest")
  sb.logInfo("THEA MOD INFO: Number of radioMessages in this quest is " .. #self.radioMessages)
end

-- QUEST START ACTIONS
function questStart()
  local acceptItems = config.getParameter("acceptItems", {})
  for _,item in ipairs(acceptItems) do
    player.giveItem(item)
  end
end

--QUEST COMPLETION ACTIONS
function questComplete()
  setPortraits()

  questutil.questCompleteActions()
end

-- QUEST UPDATE FUNCTIONS
function update(dt)
  world.debugText(sb.printJson(quest.state()), world.entityPosition(player.id()), "red")
  
  if quest.state() == "Active" then
	self.messageTimer = math.min(self.messageInterval, self.messageTimer + dt)

	--While there are still messages left, play through the messages in sequence
	if storage.messagesLeft > 0 and self.messageTimer == self.messageInterval then
	--Play the next message
	player.radioMessage(self.radioMessages[storage.currentMessageIndex], 0)
	--Update current message index and count of messages left
	storage.currentMessageIndex = storage.currentMessageIndex + 1
	storage.messagesLeft = storage.messagesLeft - 1
	--Reset message timer so we can start timing our next message
	self.messageTimer = 0
	end

	world.debugText("messageTimer = " .. self.messageTimer, vec2.add(world.entityPosition(player.id()), {0,1}), "red")
	world.debugText("messages left = " .. storage.messagesLeft, vec2.add(world.entityPosition(player.id()), {0,2}), "red")
	world.debugText("current message = " .. storage.currentMessageIndex, vec2.add(world.entityPosition(player.id()), {0,3}), "red")
  end
  
  --If we have played all messages, allow the quest to be turned in
  if storage.messagesLeft <= 0 then
	quest.setCanTurnIn(true)
	if config.getParameter("turnInDescription") then
	  quest.setObjectiveList({{ config.getParameter("turnInDescription"), false }})
	end
  end
end
