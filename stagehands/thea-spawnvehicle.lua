require "/scripts/rect.lua"
require "/scripts/util.lua"

function init()
  if not storage.vehicleHasSpawned then
    storage.vehicleHasSpawned = false
  end
  self.vehicle = config.getParameter("vehicle")
end

function update(dt)
  local area = spawnArea()
  if storage.vehicleHasSpawned == false then
	if world.regionActive(area) then
	  local spawnedVehicle = world.spawnVehicle(self.vehicle, entity.position())
	  if spawnedVehicle then
		world.sendEntityMessage(spawnedVehicle, "setPersistent")
		storage.vehicleHasSpawned = true
		stagehand.die()
	  end
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
