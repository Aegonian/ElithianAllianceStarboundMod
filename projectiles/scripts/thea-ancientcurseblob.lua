require "/scripts/vec2.lua"

function init()
  self.parentEntity = nil
  self.hasParentEntity = false
  
  self.wasKilled = false
  self.killSourceEntity = nil
  self.projectileSpawned = false
  
  if config.getParameter("randomTimeToLive") ~= nil then
	local minLifeTime = config.getParameter("minLifeTime")
	local maxLifeTime = config.getParameter("maxLifeTime")
	local lifeTime = math.random(minLifeTime, maxLifeTime)
	projectile.setTimeToLive(lifeTime/100)
  end
  
  message.setHandler("ancientcursekill", function(_, _, delay, sourceEntity)
	projectile.setTimeToLive(delay)
	
	self.killSourceEntity = sourceEntity
	self.wasKilled = true
  end)
end

function update(dt)
  if self.hasParentEntity then
	if not world.entityExists(self.parentEntity) then
	  projectile.die()
	end
  end
  
  if projectile.timeToLive() <= 0.1 and self.wasKilled and not self.projectileSpawned and world.entityExists(self.killSourceEntity) and config.getParameter("healProjectileType") then
	local distanceVector = world.distance(mcontroller.position(), world.entityPosition(self.killSourceEntity))
	local direction = vec2.norm(distanceVector)
	
	local projectileId = world.spawnProjectile(config.getParameter("healProjectileType"), mcontroller.position(), nil, direction, false)
	if projectileId then
	  world.sendEntityMessage(projectileId, "setTargetEntity", self.killSourceEntity)
	  self.projectileSpawned = true
	end
  end
end

function setParentEntity(entityId)
  self.parentEntity = entityId
  self.hasParentEntity = true
end

function setDamage(damage)
  projectile.setPower(damage)
end

function kill()
  projectile.die()
end