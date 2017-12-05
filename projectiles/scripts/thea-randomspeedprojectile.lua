require "/scripts/vec2.lua"

function init()
  self.minSpeed = config.getParameter("minSpeed")
  self.maxSpeed = config.getParameter("maxSpeed")
  
  local targetSpeed = math.random(self.minSpeed, self.maxSpeed)
  local currentVelocity = mcontroller.velocity()
  local newVelocity = vec2.mul(vec2.norm(currentVelocity), targetSpeed)
  mcontroller.setVelocity(newVelocity)
  
  if config.getParameter("randomTimeToLive") == true then
	local minLifeTime = config.getParameter("minLifeTime")
	local maxLifeTime = config.getParameter("maxLifeTime")
	local lifeTime = math.random(minLifeTime, maxLifeTime)
	if config.getParameter("timeToLiveMilliseconds") == true then
	  projectile.setTimeToLive(lifeTime/100)
	else
	  projectile.setTimeToLive(lifeTime)
	end
  end
end

function update()
end
