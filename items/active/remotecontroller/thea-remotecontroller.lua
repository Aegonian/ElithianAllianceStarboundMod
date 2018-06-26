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
  self.inputTimer = 0
  self.warningSoundTimer = 0
  self.vehicleType = config.getParameter("vehicleType")
  self.transmissionRange = config.getParameter("transmissionRange")
  self.edgeOfRangeDistance = config.getParameter("edgeOfRangeDistance")
  self.vehicleBoundingBox = config.getParameter("vehicleBoundingBox")

  activeItem.setScriptedAnimationParameter("vehicleImage", config.getParameter("vehicleImage"))
  activeItem.setScriptedAnimationParameter("vehicleState", self.vehicleState)
  
  self.controlledVehicleId = nil
  self.controlledVehicleInRange = false
  
  message.setHandler("receiveVehicleResponse", receiveVehicleResponse)
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
  --local nearbyVehicles = world.entityQuery(mcontroller.position(), self.transmissionRange, { includedTypes = {"vehicle"}, callScript = "requestIsControlled", callScriptArgs = {config.getParameter("key")}, callScriptResult = true })
  local nearbyVehicles = world.entityQuery(mcontroller.position(), self.transmissionRange, {includedTypes = {"vehicle"}})
  
  --Debug functionality
  world.debugText("Controller Key = " .. sb.printJson(config.getParameter("key")), vec2.add(mcontroller.position(), {0,3}), "red")
  world.debugText("Controlled Vehicle ID = " .. sb.printJson(self.controlledVehicleId), vec2.add(mcontroller.position(), {0,2}), "red")
  world.debugText("Controlled Vehicle In Range = " .. sb.printJson(self.controlledVehicleInRange), vec2.add(mcontroller.position(), {0,1}), "red")
  --world.debugText("Vehicle List = " .. sb.printJson(nearbyVehicles, 1), vec2.add(mcontroller.position(), {0,-1}), "red")
  --if #nearbyVehicles > 0 then
	--for _, vehicle in ipairs(nearbyVehicles) do
	  --world.debugText(sb.printJson(world.entityType(vehicle), 1), vec2.add(mcontroller.position(), {0,-2}), "red")
	  --world.debugText(sb.printJson(world.entityName(vehicle), 1), vec2.add(mcontroller.position(), {0,-3}), "red")
	  --world.debugText(sb.printJson(world.entityUniqueId(vehicle), 1), vec2.add(mcontroller.position(), {0,-4}), "red")
	--end
  --end
  
  --If we haven't deployed a vehicle yet, primary fire will spawn a new one
  if config.getParameter("filled") then
	animator.setAnimationState("controller", "inactive")
	activeItem.setInventoryIcon(config.getParameter("filledInventoryIcon"))
	if fireMode == "primary" and self.cooldownTimer == 0 then
	  if self.vehicleState == VehiclePlaceable then
		local vehicleParams = {
		  ownerKey = config.getParameter("key"),
		  startHealthFactor = config.getParameter("vehicleStartHealthFactor"),
		  scriptConfig = {
			uniqueId = ownerKey
		  }
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
  
  --If a vehicle has been deployed, continuously update it
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
	--If there are no vehicles nearby
	else
	  --Nothing here!
	end
  end
  
  --If a vehicle has been deployed, and we press alt fire, try to store the vehicle again
  if config.getParameter("filled") == false and fireMode == "alt" and self.consumePromise == nil then
	local vehicleId = world.entityQuery(activeItem.ownerAimPosition(), config.getParameter("pickUpRange") or 0, {includedTypes = {"vehicle"}, order = "nearest"})[1]
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
  
  --Functions to perform while we have identified our controlled vehicle
  if self.controlledVehicleId then
	self.controlledVehicleInRange = false
	
	--Check if our controlled vehicle is in range
	if #nearbyVehicles > 0 then
	  for _, vehicle in ipairs(nearbyVehicles) do
		if vehicle == self.controlledVehicleId then
		  self.controlledVehicleInRange = true
		end
	  end
	end
	
	--If we have identified our controlled vehicle but haven't received a response for some time, disconnect from the controlled vehicle
	if self.inputTimer == 0 then
	  self.controlledVehicleId = nil
	  self.controlledVehicleInRange = false
	end
  end
  
  --Update animation state and inventory icon based on whether or not we are in range of our controlled vehicle, but only if we have already deployed our vehicle
  if config.getParameter("filled") == false then
	if self.controlledVehicleInRange then
	  activeItem.setInventoryIcon(config.getParameter("emptyInventoryIcon"))
	  if config.getParameter("cameraFocusOnVehicle") and self.controlledVehicleId then
		if world.entityExists(self.controlledVehicleId) then
		  activeItem.setCameraFocusEntity(self.controlledVehicleId)
		end
	  end
	  --Check distance to vehicle and optionally play warning sound
	  local distanceToVehicle = world.magnitude(mcontroller.position(), world.entityPosition(self.controlledVehicleId))
	  if distanceToVehicle > self.edgeOfRangeDistance then
		if self.warningSoundTimer == 0 then
		  animator.playSound("warning")
		  self.warningSoundTimer = config.getParameter("warningSoundFrequency", 0.25)
		end
		animator.setAnimationState("controller", "warning")
	  else
		animator.setAnimationState("controller", "active")
	  end
	else
	  animator.setAnimationState("controller", "searching")
	  activeItem.setInventoryIcon(config.getParameter("emptyInventoryIcon"))
	  if config.getParameter("cameraFocusOnVehicle") then
		activeItem.setCameraFocusEntity()
	  end
	end
  end
  
  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  self.inputTimer = math.max(0, self.inputTimer - dt)
  self.warningSoundTimer = math.max(0, self.warningSoundTimer - dt)
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

--This function gets called by any vehicle that successfully received input from our controller, and is used to identify our controlled vehicle's entityID
function receiveVehicleResponse(_, _, ownerKey, vehicleId)
  if ownerKey then
	world.debugText("Received Key = " .. sb.printJson(ownerKey), vec2.add(mcontroller.position(), {0,5}), "green")
	world.debugText("Received from = " .. sb.printJson(vehicleId), vec2.add(mcontroller.position(), {0,4}), "green")
	
	if ownerKey == config.getParameter("key") then
	  self.controlledVehicleId = vehicleId
	  self.inputTimer = config.getParameter("receiveInputTimeout")
	else
	  self.controlledVehicleId = nil
	end
  end
end

function uninit()
  if config.getParameter("cameraFocusOnVehicle") then
	activeItem.setCameraFocusEntity()
  end
end