require "/scripts/vec2.lua"

function init()
  self.approach = vec2.norm(mcontroller.velocity())

  self.controlForce = config.getParameter("controlForce")
  self.targetSpeed = vec2.mag(mcontroller.velocity())
end

function update()
  if projectile.collision() or mcontroller.isCollisionStuck() or mcontroller.isColliding() then
	projectile.die()
  end
  
  --Code for ensuring a constant speed
  local currentVelocity = mcontroller.velocity()
  local newVelocity = vec2.mul(vec2.norm(currentVelocity), self.targetSpeed)
  --mcontroller.setVelocity(newVelocity)
  
  mcontroller.approachVelocity(vec2.mul(self.approach, self.targetSpeed), self.controlForce)
end

function setApproach(approach)
  self.approach = approach
end
