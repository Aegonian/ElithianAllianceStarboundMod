require "/scripts/stagehandutil.lua"

function init()
  self.players = {}
  self.music = config.getParameter("music", {})
end

function update(dt)
  for playerId, _ in pairs(self.players) do
    if not world.entityExists(playerId) then
      -- Player died or left the mission
      self.players[playerId] = nil
    end
  end

  local newPlayers = broadcastAreaQuery({ includedTypes = {"player"} })
  for _, playerId in pairs(newPlayers) do
    if not self.players[playerId] then
      world.sendEntityMessage(playerId, "playAltMusic", self.music, config.getParameter("fadeInTime"))
      --self.players[playerId] = true
    end
  end
end
