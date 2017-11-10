require "/scripts/vec2.lua"

function init()
  self.rotateInAir = config.getParameter("rotateInAir")
  
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

function update(dt)
  if self.hitGround or mcontroller.onGround() then
    mcontroller.setRotation(0)
    self.hitGround = true
  else
    if self.rotateInAir and self.rotateInAir == true then
      mcontroller.setRotation(math.atan(mcontroller.velocity()[2], mcontroller.velocity()[1]))
	end
  end
end