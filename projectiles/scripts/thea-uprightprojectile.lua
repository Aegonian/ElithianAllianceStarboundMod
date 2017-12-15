require "/scripts/vec2.lua"

function init()
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
    if config.getParameter("rotateInAir") then
      mcontroller.setRotation(math.atan(mcontroller.velocity()[2], mcontroller.velocity()[1]))
	end
	if config.getParameter("alwaysUpright") then
      mcontroller.setRotation(0)
	end
  end
end