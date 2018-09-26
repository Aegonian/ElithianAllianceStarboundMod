boomerangExtra = {}

--To be used in conjunction with the vanilla boomerang script

function boomerangExtra:init()
  self.targetPosition = nil
  
  self.minSpeed = config.getParameter("minSpeed")
  self.maxSpeed = config.getParameter("maxSpeed")
  
  self.searchDistance = config.getParameter("searchRadius")
  
  local targetSpeed = math.random(self.minSpeed, self.maxSpeed)
  local currentVelocity = mcontroller.velocity()
  local newVelocity = vec2.mul(vec2.norm(currentVelocity), targetSpeed)
  mcontroller.setVelocity(newVelocity)
  
  if config.getParameter("targetHoming") then
	if config.getParameter("homingStartDelay") ~= nil then
	  self.homingEnabled = false
	  self.countdownTimer = config.getParameter("homingStartDelay")
	else
	  self.homingEnabled = true
	end
  else
	self.homingEnabled = false
  end
end

function setTargetPosition(position)
  boomerangExtra.targetPosition = position
end

function boomerangExtra:update(dt)
  if self.targetPosition then
    local toTarget = world.distance(self.targetPosition, mcontroller.position())
    mcontroller.approachVelocity(vec2.mul(vec2.norm(toTarget), config.getParameter("speed")), config.getParameter("targetTrackingForce"))
  end
  
  if config.getParameter("targetHoming") then
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

		  mcontroller.approachVelocity(vec2.mul(vec2.norm(dist), config.getParameter("speed")), config.getParameter("targetTrackingForce"))
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
end

function boomerangExtra:projectileIds()
  return { entity.id() }
end
