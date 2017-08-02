require "/scripts/stagehandutil.lua"

function init()
  self.containsPlayers = {}
  self.radioMessages = config.getParameter("radioMessages") or {config.getParameter("radioMessage")}
end

function update(dt)
  local newPlayers = broadcastAreaQuery({includedTypes = {"player"}})
  local oldPlayers = table.concat(self.containsPlayers, ",")
  for _, id in pairs(newPlayers) do
    if not string.find(oldPlayers, id) then	  
	  for _, message in ipairs(self.radioMessages) do
        world.sendEntityMessage(id, "queueRadioMessage", message)
      end
    end
  end
  self.containsPlayers = newPlayers
end
