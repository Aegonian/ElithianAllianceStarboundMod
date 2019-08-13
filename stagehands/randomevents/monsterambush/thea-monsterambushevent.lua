require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.monsterTypes = config.getParameter("monsterTypes")
  self.monsterCount = config.getParameter("monsterCount")
  self.monsterTestPoly = config.getParameter("monsterTestPoly")
  self.spawnOnGround = config.getParameter("spawnOnGround")
  self.spawnAnimation = config.getParameter("spawnAnimation")
  self.minDistanceToPlayer = config.getParameter("minDistanceToPlayer")
  self.spawnRangeX = config.getParameter("spawnRangeX")
  self.spawnRangeY = config.getParameter("spawnRangeY")
  self.spawnTolerance = config.getParameter("spawnTolerance")
  
  self.hasSpawnedMonsters = false
end

function update(dt)  
  if self.hasSpawnedMonsters then
	stagehand.die()
  else
	for i = 1, math.random(self.monsterCount[1], self.monsterCount[2]) do
	  --Calculate initial x and y offset for the spawn position
	  local xOffset = math.random(self.minDistanceToPlayer, self.spawnRangeX)
	  xOffset = xOffset * util.randomChoice({-1, 1})
	  local yOffset = math.random(0, self.spawnRangeY)
	  local position = vec2.add(entity.position(), {xOffset, yOffset})
	  
	  --Optionally correct the position by finding the ground below the projected position
	  local correctedPositionAndNormal = {position, nil}
	  if self.spawnOnGround then
		correctedPositionAndNormal = world.lineTileCollisionPoint(position, vec2.add(position, {0, -50})) or {position, 0}
	  end
	  
	  --Resolve the monster poly collision to ensure that we can place an monster at the designated position
	  local resolvedPosition = world.resolvePolyCollision(self.monsterTestPoly, correctedPositionAndNormal[1], self.spawnTolerance)
	  
	  if resolvedPosition then
		--Spawn the monster and optionally force the monster spawn effect on them
		local entityId = world.spawnMonster(util.randomChoice(self.monsterTypes), resolvedPosition, {level = world.threatLevel(), aggressive = true})
		if self.spawnAnimation then
		  world.callScriptedEntity(entityId, "status.addEphemeralEffect", "thea-monsterspawn")
		end
	  end
	end
	self.hasSpawnedMonsters = true
  end
end
