require "/scripts/status.lua"

function die()
  local players = world.players()
  for _,playerId in pairs(players) do
	world.sendEntityMessage(playerId, config.getParameter("monsterDeathMessage"))
  end
  sb.logInfo("THEA MOD INFO: A scripted monster just died and attempted to send a message to all players")
end