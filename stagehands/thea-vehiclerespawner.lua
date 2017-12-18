require "/scripts/rect.lua"
require "/scripts/util.lua"

function init()
  if not storage.vehicleHasSpawned or storage.spawnedVehicle == nil or not world.entityExists(storage.spawnedVehicle) then
    storage.vehicleHasSpawned = false
  end
  self.vehicle = config.getParameter("vehicle")
  self.facingDirection = config.getParameter("facingDirection")
  
  self.cooldownTimer = 3.0
end

function update(dt)
  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  
  local area = spawnArea()
  if storage.vehicleHasSpawned == false and self.cooldownTimer == 0 then
	if world.regionActive(area) then
	  local spawnParameters = {}
	  if self.facingDirection then
		spawnParameters.facingDirection = self.facingDirection
	  end
	  storage.spawnedVehicle = world.spawnVehicle(self.vehicle, entity.position(), spawnParameters)
	  if storage.spawnedVehicle then
		world.sendEntityMessage(storage.spawnedVehicle, "setPersistent")
		storage.vehicleHasSpawned = true
		--stagehand.die()
	  end
	  self.cooldownTimer = 3.0
	end
  end
  
  if storage.vehicleHasSpawned and self.cooldownTimer == 0 then
	if not world.entityExists(storage.spawnedVehicle) then
	  storage.spawnedVehicle = nil
	  storage.vehicleHasSpawned = false
	  self.cooldownTimer = 3.0
	end
  end
end

function spawnArea()
  local spawnArea = config.getParameter("vehicleSpawnArea", {-8, -8, 8, 8})
  local pos = entity.position()
  return {
      spawnArea[1] + pos[1],
      spawnArea[2] + pos[2],
      spawnArea[3] + pos[1],
      spawnArea[4] + pos[2]
    }
end
