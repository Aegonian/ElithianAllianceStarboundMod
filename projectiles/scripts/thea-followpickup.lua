require "/scripts/vec2.lua"

function init()
  self.homingSpeed = config.getParameter("homingSpeed")
  self.homingForce = config.getParameter("homingForce")
  
  self.pickupRange = config.getParameter("pickupRange")
  self.snapRange = config.getParameter("snapRange")
  self.snapSpeed = config.getParameter("snapSpeed")
  self.snapForce = config.getParameter("snapForce")
  
  self.minSpeed = config.getParameter("minSpeed")
  self.maxSpeed = config.getParameter("maxSpeed")
  if self.minSpeed and self.maxSpeed then
	local targetSpeed = math.random(self.minSpeed, self.maxSpeed)
	local currentVelocity = mcontroller.velocity()
	local newVelocity = vec2.mul(vec2.norm(currentVelocity), targetSpeed)
	mcontroller.setVelocity(newVelocity)
  end
  
  self.targetOffset = {0, 0}

  self.targetEntity = nil
  
  message.setHandler("setTargetEntity", setTargetEntity)
  
  if config.getParameter("homingStartDelay") ~= nil then
	self.homingEnabled = false
	self.countdownTimer = config.getParameter("homingStartDelay")
  else
	self.homingEnabled = true
  end
end

function update(dt)
  if self.targetEntity and self.homingEnabled then
    if world.entityExists(self.targetEntity) then	  
	  local targetPos = vec2.add(world.entityPosition(self.targetEntity), self.targetOffset)
      world.debugPoint(targetPos, "blue")
      local toTarget = world.distance(targetPos, mcontroller.position())
      local targetDist = vec2.mag(toTarget)
      if targetDist <= self.pickupRange then
        projectile.die()
      elseif targetDist <= self.snapRange then
        mcontroller.approachVelocity(vec2.mul(vec2.div(toTarget, targetDist), self.snapSpeed), self.snapForce)
	  else
		mcontroller.approachVelocity(vec2.mul(vec2.norm(toTarget), self.homingSpeed), self.homingForce)
      end
    else
      self.targetEntity = nil
      mcontroller.approachVelocity({0, 0}, self.homingForce)
    end
  else
	self.countdownTimer = math.max(0, self.countdownTimer - dt)
	if self.countdownTimer == 0 then
	  self.homingEnabled = true
	end
  end
end

function setTargetEntity(_, _, targetEntityId, targetOffset, inheritFromEntityId)
  self.targetEntity = targetEntityId
  self.targetOffset = targetOffset or {0, 0}
  
  if config.getParameter("inheritTargetVelocity") == true and inheritFromEntityId ~= nil and world.entityExists(inheritFromEntityId) then
	local velocity = world.entityVelocity(inheritFromEntityId)
	if velocity ~= nil then
	  mcontroller.setVelocity(velocity)
	end
  end
end
