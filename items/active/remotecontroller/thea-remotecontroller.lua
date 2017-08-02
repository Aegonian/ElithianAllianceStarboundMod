require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  if config.getParameter("key") == nil then
    activeItem.setInstanceValue("key", sb.makeUuid())
  end

  VehicleBlocked, VehiclePlaceable, VehicleEmpty = 1, 2, 3

  if config.getParameter("filled") then
    self.vehicleState = VehicleBlocked
  else
    self.vehicleState = VehicleEmpty
  end
  
  self.cooldownTimer = 0
  self.vehicleType = config.getParameter("vehicleType")
  self.transmissionRange = config.getParameter("transmissionRange")
  self.vehicleBoundingBox = config.getParameter("vehicleBoundingBox")

  activeItem.setScriptedAnimationParameter("vehicleImage", config.getParameter("vehicleImage"))
  activeItem.setScriptedAnimationParameter("vehicleState", self.vehicleState)
end

function update(dt, fireMode, shiftHeld)
  if config.getParameter("filled") and self.cooldownTimer == 0 then
	if placementValid() then
	  self.vehicleState = VehiclePlaceable
	else
	  self.vehicleState = VehicleBlocked
	end
  end
  
  --Search for our vehicle every frame
  --local nearbyVehicles = world.entityQuery(mcontroller.position(), self.transmissionRange, { includedTypes = {"vehicle"}, callScript = "requestIsControlled", callScriptArgs = {config.getParameter("key")} })
  local nearbyVehicles = world.entityQuery(mcontroller.position(), self.transmissionRange, {includedTypes = {"vehicle"}})
  
  --If we haven't deployed a vehicle yet, prmary fire will spawn a new one
  if config.getParameter("filled") then
	animator.setAnimationState("controller", "inactive")
	activeItem.setInventoryIcon(config.getParameter("filledInventoryIcon"))
	if fireMode == "primary" and self.cooldownTimer == 0 then
	  if self.vehicleState == VehiclePlaceable then
		local vehicleParams = {
		  ownerKey = config.getParameter("key"),
		  startHealthFactor = config.getParameter("vehicleStartHealthFactor"),
	    }
		world.spawnVehicle(self.vehicleType, activeItem.ownerAimPosition(), vehicleParams)
		animator.playSound("placeOk")
		activeItem.setInstanceValue("filled", false)
		self.vehicleState = VehicleEmpty
		activeItem.setScriptedAnimationParameter("vehicleState", self.vehicleState)
	  else
		animator.playSound("placeBad")
		self.cooldownTimer = config.getParameter("cooldownTime")
	  end
	end
  end
  
  --If a vehicle has been deployed, continuosuly update it
  if config.getParameter("filled") == false then
	--If there are vehicle nearby
	if #nearbyVehicles > 0 then	
	  local aimPosition = activeItem.ownerAimPosition()
	  local controlHeld = fireMode
	  local ownerShiftHeld = shiftHeld
	  local ownerEntityId = activeItem.ownerEntityId()
	  for _, vehicle in ipairs(nearbyVehicles) do
		--Send a message to all nearby vehicles
		world.sendEntityMessage(vehicle, "updateInputParameters", aimPosition, controlHeld, ownerShiftHeld, config.getParameter("key"), ownerEntityId)
	  end
	  animator.setAnimationState("controller", "active")
	  activeItem.setInventoryIcon(config.getParameter("emptyInventoryIcon"))
	--If there are no vehicles nearby
	else
	  animator.setAnimationState("controller", "searching")
	  activeItem.setInventoryIcon(config.getParameter("emptyInventoryIcon"))
	end
  end
  
  --If a vehicle has been deployed, and we press alt fire, try to store the vehicle again
  if config.getParameter("filled") == false and fireMode == "alt" and self.consumePromise == nil then
	local vehicleId = world.entityQuery(activeItem.ownerAimPosition(), 0, {includedTypes = {"vehicle"}, order = "nearest"})[1]
	if vehicleId then
      self.consumePromise = world.sendEntityMessage(vehicleId, "storeVehicle", config.getParameter("key"))
    end
  end
  
  --If we sent out a storage request, check to see if it was successful
  if self.consumePromise then
	if self.consumePromise:finished() then
	  local messageResult = self.consumePromise:result()
	  if messageResult then
		world.debugText(messageResult.healthFactor, mcontroller.position(), "green")
		if messageResult.storeVehicleSuccess == true then
		  activeItem.setInstanceValue("vehicleStartHealthFactor", messageResult.healthFactor)
		  activeItem.setInstanceValue("filled", true)
		  self.cooldownTimer = config.getParameter("cooldownTime")
		end
	  end
	  self.consumePromise = nil
	end
  end
  
  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  activeItem.setScriptedAnimationParameter("vehicleState", self.vehicleState)
end

function updateIcon()
  if config.getParameter("filled") then
    activeItem.setInventoryIcon(config.getParameter("filledInventoryIcon"))
  else
    activeItem.setInventoryIcon(config.getParameter("emptyInventoryIcon"))
  end
end

function placementValid()
  local aimPosition = activeItem.ownerAimPosition()

  if world.lineTileCollision(mcontroller.position(), aimPosition) then
    return false
  end

  local vehicleBounds = {
    self.vehicleBoundingBox[1] + aimPosition[1],
    self.vehicleBoundingBox[2] + aimPosition[2],
    self.vehicleBoundingBox[3] + aimPosition[1],
    self.vehicleBoundingBox[4] + aimPosition[2]
  }

  if world.rectTileCollision(vehicleBounds, {"Null", "Block", "Dynamic"}) then
    return false
  end

  return true
end

function uninit()
end