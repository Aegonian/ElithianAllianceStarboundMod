require "/scripts/vec2.lua"

function init()
  message.setHandler("kill", function()
	projectile.die()
  end)
  
  self.lifetimeAfterCollision = config.getParameter("lifetimeAfterCollision")
  self.hasCollided = false
end

function update(dt)
  
  --If the projectile has collided with tiles, set its damage to zero and reduce time to live
  if mcontroller.isColliding() and self.hasCollided == false then
	projectile.setPower(0.0)
	projectile.setTimeToLive(self.lifetimeAfterCollision)
	self.hasCollided = true
  end
  
end
