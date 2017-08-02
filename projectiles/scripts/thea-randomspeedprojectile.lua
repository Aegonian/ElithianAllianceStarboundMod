require "/scripts/vec2.lua"

function init()
  self.minSpeed = config.getParameter("minSpeed")
  self.maxSpeed = config.getParameter("maxSpeed")
  
  local targetSpeed = math.random(self.minSpeed, self.maxSpeed)
  local currentVelocity = mcontroller.velocity()
  local newVelocity = vec2.mul(vec2.norm(currentVelocity), targetSpeed)
  mcontroller.setVelocity(newVelocity)
end

function update()
end
