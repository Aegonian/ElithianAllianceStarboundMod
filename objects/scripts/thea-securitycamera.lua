require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/interp.lua"

function init()
  self.idleRotation = util.toRadians(config.getParameter("idleRotation"))
  self.baseRotation = util.toRadians(config.getParameter("baseRotation"))
  self.rotationSpeed = config.getParameter("rotationSpeed")
  self.rotationAngle = util.toRadians(config.getParameter("rotationAngle"))
  self.baseOffset = config.getParameter("baseOffset")
  self.basePosition = vec2.add(object.position(), self.baseOffset)
  self.scanRange = config.getParameter("scanRange")
  self.scanAngle = util.toRadians(config.getParameter("scanAngle"))
  self.maxScanAngle = self.scanAngle + self.baseRotation
  self.minScanAngle = -self.scanAngle + self.baseRotation
  
  self.cameraAngle = 0
  self.timer = 0
  self.hadTargetLastFrame = false
end

function update(dt)
  --If the input node is not connected, or if it's set to "true", search for targets
  if not object.isInputNodeConnected(0) or object.getInputNodeLevel(0) then
	--Search for targets
	local target = findTarget()
  
	--If we have found a valid target, rotate to face our target
	if target then
	  local targetPosition = world.entityPosition(target)
	  local toTarget = world.distance(targetPosition, self.basePosition)
	  local targetAngle = math.atan(toTarget[2], object.direction() * toTarget[1])
	  
	  self.timer = 0
	  
	  --If we didn't have a target before, play the alert sound
	  if not self.hadTargetLastFrame then
		animator.playSound("foundTarget")
	  end
	  
	  self.cameraAngle = targetAngle
	  animator.setAnimationState("camera", "foundTarget")
	  object.setOutputNodeLevel(0, true)
	--If we don't have a target, rotate up and down automatically
	else
	  self.timer = self.timer + (script.updateDt() * self.rotationSpeed)
	  if self.timer > 1 then
		self.timer = self.timer - 1
	  end
	  
	  --If we had a target before, play the lost target sound
	  if self.hadTargetLastFrame then
		animator.playSound("lostTarget")
	  end
	
	  self.cameraAngle = self.rotationAngle * math.sin(self.timer * math.pi*2) + self.baseRotation
	  animator.setAnimationState("camera", "scan")
	  object.setOutputNodeLevel(0, false)
	end
  
	--Debug functions
	world.debugText("MAX ANGLE: " .. self.scanAngle + self.baseRotation, vec2.add(entity.position(), {0,-1}), "yellow")
	world.debugText("MIN ANGLE: " .. -self.scanAngle + self.baseRotation, vec2.add(entity.position(), {0,-2}), "yellow")
	world.debugText(sb.print(findTarget()), vec2.add(entity.position(), {0,1}), "yellow")
	world.debugPoint(self.basePosition, "yellow")  
  
	animator.resetTransformationGroup("camera")
	animator.rotateTransformationGroup("camera", self.cameraAngle)
	
	--Update last target
	if target then
	  self.hadTargetLastFrame = true
	else
	  self.hadTargetLastFrame = false
	end
  
  --If input node is connected and set to "false", set camera to idle rotation
  else
	self.timer = 0
	
	animator.resetTransformationGroup("camera")
	animator.rotateTransformationGroup("camera", self.idleRotation)
	animator.setAnimationState("camera", "idle")
  end
end

function findTarget()
  --Search for targets within range
  local nearEntities = world.entityQuery(self.basePosition, self.scanRange, {
	includedTypes = { "monster", "npc", "player" },
	order = "nearest"
  })
  
  --If there are entities in range, filter them. Otherwise, return false
  if nearEntities then
	local validTarget = false
	
	--For every target in range, check if they are within scan parameters
	for _, entityId in ipairs(nearEntities) do
	  local targetPosition = world.entityPosition(entityId)
	  local toTarget = world.distance(targetPosition, self.basePosition)
	  local targetAngle = math.atan(toTarget[2], object.direction() * toTarget[1])
	  
	  world.debugText("TARGET", targetPosition, "yellow")
	  world.debugText("DIST: " .. world.magnitude(toTarget), vec2.add(targetPosition, {0,-1}), "yellow")
	  world.debugText("ANGLE: " .. targetAngle, vec2.add(targetPosition, {0,-2}), "yellow")
	  
	  --If target is in range, within scan angle range and in sight, set this entity to our validTarget
	  if world.magnitude(toTarget) < self.scanRange
		and targetAngle < self.maxScanAngle
		and targetAngle > self.minScanAngle
		and not world.getProperty("entityinvisible" .. tostring(entityId))
		and not world.lineTileCollision(self.basePosition, targetPosition) then
		
		if not validTarget then
		  validTarget = entityId
		end
	  end
	end
	
	--Return the entityId of our valid target, or return false
	if validTarget then
	  return validTarget
	else
	  return false
	end
  else
	return false
  end
end