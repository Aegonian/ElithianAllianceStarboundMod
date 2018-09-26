require "/scripts/vec2.lua"

function init()
  self.maxSpeed = config.getParameter("maxSpeed")
  self.controlForce = config.getParameter("controlForce")
  
  self.searchDistance = config.getParameter("searchRadius")
  self.seekingControlForce = config.getParameter("baseHomingControlForce") * self.maxSpeed
  
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
  
  --Time until the projectile starts seeking targets. Before then, the projectile will attempt to straighten out any inaccuracy
  self.countdownTimer = config.getParameter("homingStartDelay")
end

function setApproach(approach)
  self.approach = approach
end

function update(dt)
  if self.homingEnabled == true then
	local targets = world.entityQuery(mcontroller.position(), self.searchDistance, {
      withoutEntityId = projectile.sourceEntity(),
      includedTypes = {"creature"},
      order = "nearest"
    })

	for _, target in ipairs(targets) do
	  if entity.entityInSight(target) and world.entityCanDamage(projectile.sourceEntity(), target) and not (world.getProperty("entityinvisible" .. tostring(target)) and not config.getParameter("ignoreInvisibility", false)) then
		local targetPos = world.entityPosition(target)
		local myPos = mcontroller.position()
		local dist = world.distance(targetPos, myPos)

		mcontroller.approachVelocity(vec2.mul(vec2.norm(dist), self.maxSpeed), self.seekingControlForce)
		return
	  end
	end
  else
	self.countdownTimer = math.max(0, self.countdownTimer - dt)
	if self.countdownTimer == 0 then
	  self.homingEnabled = true
	end
	--If homing isn't enabled yet, straighten out the projectile's path
	mcontroller.approachVelocity(vec2.mul(self.approach, self.maxSpeed), self.controlForce)
  end
  
  --Code for ensuring a constant speed
  if config.getParameter("constantSpeed") == true then
	local currentVelocity = mcontroller.velocity()
	local newVelocity = vec2.mul(vec2.norm(currentVelocity), self.maxSpeed)
	mcontroller.setVelocity(newVelocity)
  end
end
