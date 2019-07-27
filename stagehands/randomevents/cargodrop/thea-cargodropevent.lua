require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.projectileType = config.getParameter("projectileType")
  self.vehicleType = config.getParameter("vehicleType")
  self.dropPodTestPoly = config.getParameter("dropPodTestPoly")
  self.minDistanceToPlayer = config.getParameter("minDistanceToPlayer")
  self.spawnRangeX = config.getParameter("spawnRangeX")
  self.spawnRangeY = config.getParameter("spawnRangeY")
  self.spawnTolerance = config.getParameter("spawnTolerance")
  
  self.hasSpawnedVehicle = false
end

function update(dt)  
  if self.hasSpawnedVehicle then
	stagehand.die()
  else
	--Calculate initial x and y offset for the spawn position
	local xOffset = math.random(-self.spawnRangeX, self.spawnRangeX)
	local yOffset = math.random(self.minDistanceToPlayer, self.spawnRangeY)
	local position = vec2.add(entity.position(), {xOffset, yOffset})
	  
	--Resolve the NPC poly collision to ensure that we can place an NPC at the designated position
	local resolvedPosition = world.resolvePolyCollision(self.dropPodTestPoly, position, self.spawnTolerance)
	  
	--Spawn the NPC and force the beamin effect on them
	local entityId = world.spawnVehicle(self.vehicleType, resolvedPosition)
	self.hasSpawnedVehicle = true
	
	--Optionally spawn an accompanying projectile (usually a flare)
	if self.projectileType then
	  world.spawnProjectile(self.projectileType, resolvedPosition)
	end
  end
end
