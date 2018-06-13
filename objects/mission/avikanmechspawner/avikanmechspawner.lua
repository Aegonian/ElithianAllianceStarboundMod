require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  storage.spawnedVehicle = storage.spawnedVehicle or nil
  
  self.cooldownTimer = config.getParameter("initialCooldownTime", 1.0)
end

function update(dt)
  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  world.debugText(self.cooldownTimer, vec2.add(entity.position(), {0,1}), "red")
  world.debugText(sb.printJson(storage.spawnedVehicle), vec2.add(entity.position(), {0,2}), "red")
  
  if not storage.spawnedVehicle and self.cooldownTimer == 0 then
	spawnVehicle()
  end
  
  if storage.spawnedVehicle then
	if not world.entityExists(storage.spawnedVehicle) then
	  storage.spawnedVehicle = nil
	  self.cooldownTimer = config.getParameter("cooldownTime", 2.0)
	end
  end
end

function spawnVehicle()
  local parameters = config.getParameter("vehicleParameters", {})
  if parameters.facingDirection then
	if object.direction() < 0 then
	  parameters.facingDirection = parameters.facingDirection * -1
	end
  end
  storage.spawnedVehicle = world.spawnVehicle(config.getParameter("vehicleType", "avikanmech"), vec2.add(entity.position(), config.getParameter("spawnOffset", {0,0})), parameters)
  self.cooldownTimer = config.getParameter("cooldownTime", 2.0)
end
