require "/scripts/vec2.lua"

function init()
  self.tileDamage = config.getParameter("tileDamage", 1000)
  self.damageTileRadius = config.getParameter("damageTileRadius", 1)
  self.damageType = config.getParameter("damageType", "fire")
  self.harvestLevel = config.getParameter("harvestLevel", 0)
  self.tickTime = config.getParameter("tickTime", 1.0)
  
  self.tickTimer = self.tickTime
  
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
  
  script.setUpdateDelta(1) --Ensure the best possible update rate
end

function update(dt)
  self.tickTimer = math.max(0, self.tickTimer - dt)
  
  if self.tickTimer == 0 then
	world.damageTileArea(mcontroller.position(), self.damageTileRadius, "foreground", mcontroller.position(), self.damageType, self.tileDamage, self.harvestLevel)
  end
  
  if config.getParameter("forceUpright") then
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
end

--Function that gets called on the projectile's death
function destroy()
  
end