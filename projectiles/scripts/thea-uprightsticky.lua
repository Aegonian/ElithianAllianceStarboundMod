require "/scripts/vec2.lua"

function init()
  self.rotateInAir = config.getParameter("rotateInAir")
end

function update(dt)
  if self.hitGround or mcontroller.onGround() or mcontroller.isColliding() then
    mcontroller.setRotation(0)
    self.hitGround = true
  else
    if self.rotateInAir and self.rotateInAir == true then
      mcontroller.setRotation(math.atan(mcontroller.velocity()[2], mcontroller.velocity()[1]))
	end
  end
end