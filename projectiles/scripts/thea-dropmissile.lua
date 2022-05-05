require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.targetSpeed = config.getParameter("targetSpeed")
  self.searchDistance = config.getParameter("searchRadius")
  self.controlForce = config.getParameter("baseHomingControlForce") * self.targetSpeed
  
  --Optional random lifetime
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
  
  --Optional homing delay
  if config.getParameter("homingStartDelay") ~= nil then
	self.homingEnabled = false
	self.countdownTimer = config.getParameter("homingStartDelay")
  else
	self.homingEnabled = true
  end
end

function update(dt)
  if self.homingEnabled == true then
	local targets = world.entityQuery(mcontroller.position(), self.searchDistance, {
      withoutEntityId = projectile.sourceEntity(),
      includedTypes = {"creature"},
      order = "nearest"
    })

	for _, target in ipairs(targets) do
	  if entity.entityInSight(target) and world.entityCanDamage(projectile.sourceEntity(), target) and not (world.getProperty("entityinvisible" .. tostring(target)) and not config.getParameter("ignoreInvisibility", false)) and entity.isValidTarget(target) then
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
end
