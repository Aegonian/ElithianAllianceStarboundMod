require "/scripts/vec2.lua"

function init()
  self.targetSpeed = config.getParameter("primerYSpeed")
  
  mcontroller.setXVelocity(0)
  mcontroller.setYVelocity(0)
  
  self.isAtTargetPosition = false
  
  self.startingPosition = mcontroller.position()
end

function update(dt)
  mcontroller.setYVelocity(self.targetSpeed)
  
  --Makes the noclip projectile visible in debug mode
  world.debugText("o", mcontroller.position(), "yellow")
end