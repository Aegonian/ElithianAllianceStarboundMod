require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.npcSpecies = config.getParameter("npcSpecies")
  self.npcTypes = config.getParameter("npcTypes")
  self.npcCount = config.getParameter("npcCount")
  self.npcTestPoly = config.getParameter("npcTestPoly")
  self.minDistanceToPlayer = config.getParameter("minDistanceToPlayer")
  self.spawnRangeX = config.getParameter("spawnRangeX")
  self.spawnRangeY = config.getParameter("spawnRangeY")
  self.spawnTolerance = config.getParameter("spawnTolerance")
  
  self.hasSpawnedNPCs = false
end

function update(dt)  
  if self.hasSpawnedNPCs then
	stagehand.die()
  else
	for i = 1, math.random(self.npcCount[1], self.npcCount[2]) do
	  --Calculate initial x and y offset for the spawn position
	  local xOffset = math.random(self.minDistanceToPlayer, self.spawnRangeX)
	  xOffset = xOffset * util.randomChoice({-1, 1})
	  local yOffset = math.random(0, self.spawnRangeY)
	  local position = vec2.add(entity.position(), {xOffset, yOffset})
	  
	  --Correct the position by finding the ground below the projected position
	  local correctedPositionAndNormal = world.lineTileCollisionPoint(position, vec2.add(position, {0, -50})) or {position, 0}
	  
	  --Resolve the NPC poly collision to ensure that we can place an NPC at the designated position
	  local resolvedPosition = world.resolvePolyCollision(self.npcTestPoly, correctedPositionAndNormal[1], self.spawnTolerance)
	  
	  if resolvedPosition then
		--Spawn the NPC and force the beamin effect on them
		local entityId = world.spawnNpc(resolvedPosition, util.randomChoice(self.npcSpecies), util.randomChoice(self.npcTypes), world.threatLevel())
		world.callScriptedEntity(entityId, "status.addEphemeralEffect", "beamin")
	  end
	end
	self.hasSpawnedNPCs = true
  end
end
