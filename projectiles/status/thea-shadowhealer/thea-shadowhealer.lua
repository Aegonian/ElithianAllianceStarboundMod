require "/scripts/vec2.lua"

function init()
  self.homingSpeed = config.getParameter("homingSpeed")
  self.homingForce = config.getParameter("homingForce")
  
  self.pickupRange = config.getParameter("pickupRange")
  self.snapRange = config.getParameter("snapRange")
  self.snapSpeed = config.getParameter("snapSpeed")
  self.snapForce = config.getParameter("snapForce")
  self.restoreBase = config.getParameter("restoreBase")
  self.restorePercentage = config.getParameter("restorePercentage")

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
      world.debugPoint(world.entityPosition(self.targetEntity), "blue")
	  
	  local targetPos = world.entityPosition(self.targetEntity)
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

function setTargetEntity(_, _, entityId)
  self.targetEntity = entityId
end
