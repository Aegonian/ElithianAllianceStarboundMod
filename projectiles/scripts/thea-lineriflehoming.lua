require "/scripts/vec2.lua"

function init()
  self.targetSpeed = vec2.mag(mcontroller.velocity())
  self.searchDistance = config.getParameter("searchRadius")
  self.controlForce = config.getParameter("baseHomingControlForce") * self.targetSpeed
  self.timedActions = config.getParameter("timedActions", {})
  
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
end

function update(dt)
  if projectile.collision() or mcontroller.isCollisionStuck() or mcontroller.isColliding() then
	projectile.die()
  end
  
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
  
  --Code for performing timed actions
  for _, action in pairs(self.timedActions) do
	processTimedAction(action, dt)
  end
end

function processTimedAction(action, dt)
  if action.complete then
    return
  elseif action.delayTime then
    action.delayTime = action.delayTime - dt
    if action.delayTime <= 0 then
      action.delayTime = nil
    end
  elseif action.loopTime then
    action.loopTimer = action.loopTimer or 0
    action.loopTimer = math.max(0, action.loopTimer - dt)
    if action.loopTimer == 0 then
      projectile.processAction(action)
      action.loopTimer = action.loopTime
      if action.loopTimeVariance then
        action.loopTimer = action.loopTimer + (2 * math.random() - 1) * action.loopTimeVariance
      end
    end
  else
    projectile.processAction(action)
    action.complete = true
  end
end
