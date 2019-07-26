require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.regionChecked = false
end

function update(dt)
  if self.regionChecked then
	stagehand.die()
  else
	--For every nearby player, check if the region around them is player modified, and message them about it
	local nearbyPlayers = world.playerQuery(entity.position(), 25)
	for _, playerId in ipairs(nearbyPlayers) do
	  local regionIsPlayerModified = world.isPlayerModified(nearbyRegion(playerId))
	  local dungeonAtPosition = world.dungeonId(world.entityPosition(playerId))
	  world.sendEntityMessage(playerId, "thea-regionUpdate", regionIsPlayerModified, dungeonAtPosition)
	  sb.logInfo("Region is player modified: " .. sb.print(regionIsPlayerModified))
	end
	self.regionChecked = true
  end
end

function nearbyRegion(playerId)
  local region = {-50, -25, 50, 25}
  local pos = world.entityPosition(playerId)
  sb.logInfo("Player position: " .. sb.print(pos))
  return {
      math.ceil(region[1] + pos[1]),
      math.ceil(region[2] + pos[2]),
      math.ceil(region[3] + pos[1]),
      math.ceil(region[4] + pos[2])
    }
end
