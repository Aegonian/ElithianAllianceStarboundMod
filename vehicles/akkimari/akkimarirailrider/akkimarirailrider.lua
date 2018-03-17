require "/scripts/rails.lua"

function init()
  message.setHandler("positionTileDamaged", function()
      if not world.isTileProtected(mcontroller.position()) then
        popVehicle()
      end
    end)
	
  self.railWheelFrame = 1
  animator.setGlobalTag("railWheelFrame", self.railWheelFrame)

  mcontroller.setRotation(0)

  self.driverDances = config.getParameter("driverDances")
  
  local railConfig = config.getParameter("railConfig", {})
  railConfig.facing = config.getParameter("initialFacing", 1)

  self.railRider = Rails.createRider(railConfig)
  self.railRider:init(storage.railStateData)

  self.driver = nil
end

function update(dt)
  if mcontroller.atWorldLimit() then
    vehicle.destroy()
    return
  end

  local driver = vehicle.entityLoungingIn("seat")
  if driver then
    local upHeld = vehicle.controlHeld("seat", "up")
    local downHeld = vehicle.controlHeld("seat", "down")
    local leftHeld = vehicle.controlHeld("seat", "left")
    local rightHeld = vehicle.controlHeld("seat", "right")

	--If at a rail stop and receiving input, resume riding
    if not self.railRider.moving then
      if upHeld then
        resume(Rails.dirs.n)
      elseif downHeld then
        resume(Rails.dirs.s)
      elseif leftHeld then
        resume(Rails.dirs.w)
      elseif rightHeld then
        resume(Rails.dirs.e)
      end
    end

	--Animating the lever
    if leftHeld or upHeld then
      animator.setAnimationState("lever", "left")
	  vehicle.setLoungeDance("seat", self.driverDances[1])
    elseif rightHeld or downHeld then
      animator.setAnimationState("lever", "right")
	  vehicle.setLoungeDance("seat", self.driverDances[2])
    else
      animator.setAnimationState("lever", "idle")
	  vehicle.setLoungeDance("seat", self.driverDances[3])
    end
    vehicle.setInteractive(false)
  else
    animator.setAnimationState("lever", "idle")
    vehicle.setInteractive(true)
  end
  self.driver = driver

  --Update or destroy vehicle based on collision
  if mcontroller.isColliding() then
    popVehicle()
  else
    self.railRider:update(dt)
    storage.railStateData = self.railRider:stateData()
  end

  --Rail riding animation
  if self.railRider.onRailType and self.railRider.moving then
	if self.railRider.direction <= 4 then
	  animator.setAnimationState("rail", "left")
	elseif self.railRider.direction >= 5 then
	  animator.setAnimationState("rail", "right")
	end
  elseif self.railRider.onRailType and not self.railRider.moving then
    animator.setAnimationState("rail", "idle")
  else
    animator.setAnimationState("rail", "off")
  end
end

function resume(direction)
  self.railRider:railResume(self.railRider:position(), nil, direction)
end

function uninit()
  self.railRider:uninit()
end

function popVehicle()
  local popItem = config.getParameter("popItem")
  if popItem then
    world.spawnItem(popItem, entity.position(), 1)
  end
  vehicle.destroy()
end

function isRailTramAt(nodePos)
  if nodePos and vec2.eq(nodePos, self.railRider:position()) then
    return true
  end
end

