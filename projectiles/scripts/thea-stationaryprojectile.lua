require "/scripts/vec2.lua"

function init()
  message.setHandler("kill", function()
	projectile.die()
  end)
  
  self.startPosition = mcontroller.position()
end

function update(dt)
  mcontroller.setPosition(self.startPosition)
end
