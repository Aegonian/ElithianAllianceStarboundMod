require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  self.targetSpeed = vec2.mag(mcontroller.velocity())
  self.searchDistance = config.getParameter("searchRadius")
  self.controlForce = config.getParameter("baseHomingControlForce") * self.targetSpeed
  
  if config.getParameter("randomTimeToLive") ~= nil then
	local minLifeTime = config.getParameter("minLifeTime")
	local maxLifeTime = config.getParameter("maxLifeTime")
	local lifeTime = math.random(minLifeTime, maxLifeTime)
	projectile.setTimeToLive(lifeTime)
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
  self.maxWaves = config.getParameter("maxWaves", -1)
  self.waves = 0
  
  if config.getParameter("randomWavePeriod") then
	self.wavePeriod = self.wavePeriod * (math.random(5, 20) / 10)
  end
  
  self.timer = self.wavePeriod * 0.25
  local vel = mcontroller.velocity()
  if vel[1] < 0 then
    self.waveAmplitude = -self.waveAmplitude
  end
  self.lastAngle = 0
end

function update(dt)
  if projectile.collision() or mcontroller.isCollisionStuck() or mcontroller.isColliding() then
	projectile.die()
  end
  
  --Move the projectile in a sine wave motion by adjusting velocity direction
  if (self.maxWaves == -1) or (self.waves < self.maxWaves) then
	self.timer = self.timer + dt
	local newAngle = self.waveAmplitude * math.sin(self.timer / self.wavePeriod)

	mcontroller.setVelocity(vec2.rotate(mcontroller.velocity(), newAngle - self.lastAngle))

	self.lastAngle = newAngle
	
	--Count up the waves we've completed
	self.waves = self.timer / self.wavePeriod / (2 * math.pi)
  end
  
  --world.debugText(self.waves, mcontroller.position(), "red")
  --world.debugText(self.timer, vec2.add(mcontroller.position(), {0, -1}), "orange")
  
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

		mcontroller.approachVelocity(vec2.mul(vec2.norm(dist), self.targetSpeed), self.controlForce)
		return
	  end
	end
  else
	self.countdownTimer = math.max(0, self.countdownTimer - dt)
	if self.countdownTimer == 0 then
	  self.homingEnabled = true
	end
  end
  
  --Code for ensuring a constant speed
  local currentVelocity = mcontroller.velocity()
  local newVelocity = vec2.mul(vec2.norm(currentVelocity), self.targetSpeed)
  mcontroller.setVelocity(newVelocity)
end
