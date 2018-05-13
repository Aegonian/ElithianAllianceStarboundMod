require "/scripts/vec2.lua"

function init()
  self.overrides = config.getParameter("overrides")
  self.activated = false
  self.overrideAccepted = false
  
  self.fireOffset = config.getParameter("fireOffset")
  updateAim()
end

function update(dt, fireMode, shiftHeld)
  updateAim()

  --If pressing mouse button, attempt to override the player's essential slot items
  if fireMode == "primary" and not self.activated then
	self.activated = true
	self.cooldownTimer = self.cooldownTime
	
	--sb.logInfo("Started an attempt to override the Matter Manipulator")
	
	--Get the item information for all essential slot items
	local currentBeamAxe = player.essentialItem("beamaxe")
	if currentBeamAxe then
	  currentBeamAxe.parameters = currentBeamAxe.parameters or {}
	end
	local currentWireTool = player.essentialItem("wiretool")
	local currentPaintTool = player.essentialItem("painttool")
	local currentInspectionTool = player.essentialItem("inspectiontool")
	
	sb.logInfo("Current INSPECTIONTOOL configuration is: " .. sb.printJson(currentInspectionTool, 1))
	
	--If we have unlocked all essential slot items, override them
	if currentBeamAxe and currentWireTool and currentPaintTool and currentInspectionTool then
	  if currentInspectionTool.name ~= "inspectionmode" then
		self.overrideAccepted = true
		--sb.logInfo("Matter Manipulator override request accepted")
	  
		animator.playSound("override")
	  
		--Create the configs for our new essential slot items
		local newBeamAxe = root.createItem(self.overrides.beamaxe)
		newBeamAxe.parameters = currentBeamAxe.parameters
		local newWireTool = root.createItem(self.overrides.wiretool)
		local newPaintTool = root.createItem(self.overrides.painttool)
		local newInspectionTool = root.createItem(self.overrides.inspectiontool)
	  
		--sb.logInfo("New BEAMAXE configuration is: " .. sb.printJson(newBeamAxe, 1))
		--sb.logInfo("New WIRETOOL configuration is: " .. sb.printJson(newWireTool, 1))
		--sb.logInfo("New PAINTTOOL configuration is: " .. sb.printJson(newPaintTool, 1))
		--sb.logInfo("New INSPECTIONTOOL configuration is: " .. sb.printJson(newInspectionTool, 1))
		player.giveEssentialItem("beamaxe", newBeamAxe)
		player.giveEssentialItem("wiretool", newWireTool)
		player.giveEssentialItem("painttool", newPaintTool)
		player.giveEssentialItem("inspectiontool", newInspectionTool)
		
		item.consume(1)
	  else --If our inspection tool is still the original tool and not part of the matter manipulator, play the fail sound
		animator.playSound("fail")
		--sb.logInfo("Matter Manipulator override request rejected")
	  end	  
	--If we are missing one or more essential slot items, play the fail sound
	else
	  animator.playSound("fail")
	  --sb.logInfo("Matter Manipulator override request rejected")
	end
  end
  
  if fireMode ~= "primary" and self.activated and not self.overrideAccepted then
	self.activated = false
  end
end

function updateAim()
  self.aimAngle, self.aimDirection = activeItem.aimAngleAndDirection(self.fireOffset[2], activeItem.ownerAimPosition())
  activeItem.setArmAngle(self.aimAngle)
  activeItem.setFacingDirection(self.aimDirection)
end

function firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.fireOffset))
end

function aimVector()
  local aimVector = vec2.rotate({1, 0}, self.aimAngle + sb.nrand(config.getParameter("inaccuracy", 0), 0))
  aimVector[1] = aimVector[1] * self.aimDirection
  return aimVector
end

function holdingItem()
  return true
end

function recoil()
  return false
end

function outsideOfHand()
  return false
end
