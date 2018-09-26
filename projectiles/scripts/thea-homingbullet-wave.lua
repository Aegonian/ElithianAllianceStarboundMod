require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.targetSpeed = vec2.mag(mcontroller.velocity())
  self.searchDistance = config.getParameter("searchRadius")
  --Checking which type of homing code to use
  self.homingStyle = config.getParameter("homingStyle", "controlVelocity")
  if self.homingStyle == "controlVelocity" then
	self.controlForce = config.getParameter("baseHomingControlForce") * self.targetSpeed
  elseif self.homingStyle == "rotateToTarget" then
	self.rotationRate = config.getParameter("rotationRate")
	self.trackingLimit = config.getParameter("trackingLimit")
  end
  
  if config.getParameter("randomStartingSpeed") == true then
	local minSpeed = config.getParameter("minSpeed")
	local maxSpeed = config.getParameter("maxSpeed")
  
	local targetSpeed = math.random(minSpeed, maxSpeed)
	local currentVelocity = mcontroller.velocity()
	local newVelocity = vec2.mul(vec2.norm(currentVelocity), targetSpeed)
	mcontroller.setVelocity(newVelocity)
	
	self.targetSpeed = targetSpeed
  end
  
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
  
  if config.getParameter("homingStartDelay") ~= nil then
	self.homingEnabled = false
	self.countdownTimer = config.getParameter("homingStartDelay")
  else
	self.homingEnabled = true
  end
  
  --Seting up the sine wave movement
  self.wavePeriod = config.getParameter("wavePeriod") / (2 * math.pi)
  self.waveAmplitude = config.getParameter("waveAmplitude")

  self.timer = self.wavePeriod * 0.25
  local vel = mcontroller.velocity()
  if vel[1] < 0 then
    self.waveAmplitude = -self.waveAmplitude
  end
  self.lastAngle = 0
end

function update(dt)
  --Sine wave movement code
  self.timer = self.timer + dt
  local newAngle = self.waveAmplitude * math.sin(self.timer / self.wavePeriod)

  mcontroller.setVelocity(vec2.rotate(mcontroller.velocity(), newAngle - self.lastAngle))

  self.lastAngle = newAngle
  
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

		if self.homingStyle == "controlVelocity" then
		  mcontroller.approachVelocity(vec2.mul(vec2.norm(dist), self.targetSpeed), self.controlForce)
		elseif self.homingStyle == "rotateToTarget" then
		  local vel = mcontroller.velocity()
		  local angle = vec2.angle(vel)
		  local toTargetAngle = util.angleDiff(angle, vec2.angle(dist))
		  
		  if math.abs(toTargetAngle) > self.trackingLimit then
			return
		  end

		  local rotateAngle = math.max(dt * -self.rotationRate, math.min(toTargetAngle, dt * self.rotationRate))

		  vel = vec2.rotate(vel, rotateAngle)
		  mcontroller.setVelocity(vel)
		  
		  break
		end
		return
	  end
	end
  else
	self.countdownTimer = math.max(0, self.countdownTimer - dt)
	if self.countdownTimer == 0 then
	  self.homingEnabled = true
	end
  end
end
