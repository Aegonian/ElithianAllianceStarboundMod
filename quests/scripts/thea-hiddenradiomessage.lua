require "/scripts/util.lua"
require "/quests/scripts/questutil.lua"
require("/quests/scripts/portraits.lua")

function init()
  self.radioMessages = config.getParameter("radioMessages")
  self.messageInterval = config.getParameter("messageInterval")
  self.firstMessageDelay = config.getParameter("firstMessageDelay")

  setPortraits()
  
  sb.logInfo("THEA MOD INFO: Started an invisible quest to broadcast radiomessages to the player")
end

function questStart()
  
end

function questComplete()
  setPortraits()

  questutil.questCompleteActions()
end

function update(dt)  
  --Only start playing the messages once the player has beamed down to a planet, to prevent conflict with SAIL dialogue
  if player.worldId() ~= player.ownShipWorldId() then
	player.radioMessage(self.radioMessages.startMessage, self.firstMessageDelay)
	player.radioMessage(self.radioMessages.secondMessage, self.firstMessageDelay + self.messageInterval)
	player.radioMessage(self.radioMessages.thirdMessage, self.firstMessageDelay + self.messageInterval * 2)
	player.radioMessage(self.radioMessages.fourthMessage, self.firstMessageDelay + self.messageInterval *3 )
	player.radioMessage(self.radioMessages.endMessage, self.firstMessageDelay + self.messageInterval * 4)
	
	quest.complete()
  end
end
