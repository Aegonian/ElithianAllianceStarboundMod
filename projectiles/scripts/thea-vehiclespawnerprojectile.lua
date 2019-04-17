require "/scripts/vec2.lua"

function init()
  self.targetDistance = config.getParameter("targetDistance", 0.5)
  self.vehicleType = config.getParameter("vehicleType")
  self.vehicleSpawned = false
end

function update(dt)
  if self.targetPosition then
	if world.magnitude(mcontroller.position(), self.targetPosition) < self.targetDistance then
	  projectile.die()
	end
	
	world.debugPoint(self.targetPosition, "yellow")
  end
end

function setTarget(position)
  self.targetPosition = position
end

function destroy()
  if not self.vehicleSpawned then
	world.spawnVehicle(self.vehicleType, mcontroller.position())
  end
end