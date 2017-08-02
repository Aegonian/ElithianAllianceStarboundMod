require "/scripts/vec2.lua"

function init()
  self.targetSpeed = vec2.mag(mcontroller.velocity())
end

function update()
  if projectile.collision() or mcontroller.isCollisionStuck() or mcontroller.isColliding() then
	projectile.die()
  end
  
  --Code for ensuring a constant speed
  local currentVelocity = mcontroller.velocity()
  local newVelocity = vec2.mul(vec2.norm(currentVelocity), self.targetSpeed)
  mcontroller.setVelocity(newVelocity)
end
