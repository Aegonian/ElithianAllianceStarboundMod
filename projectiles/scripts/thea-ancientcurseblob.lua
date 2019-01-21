require "/scripts/vec2.lua"

function init()
  self.parentEntity = nil
  self.hasParentEntity = false
  
  if config.getParameter("randomTimeToLive") ~= nil then
	local minLifeTime = config.getParameter("minLifeTime")
	local maxLifeTime = config.getParameter("maxLifeTime")
	local lifeTime = math.random(minLifeTime, maxLifeTime)
	projectile.setTimeToLive(lifeTime/100)
  end
end

function update(dt)
  if self.hasParentEntity then
	if not world.entityExists(self.parentEntity) then
	  projectile.die()
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