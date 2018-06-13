require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/poly.lua"

function init()  
  setDirection(storage.doorDirection or object.direction())
  
  --Setting up storage for making door rotation persistent
  storage.cycle = storage.cycle or 0		--goes from 0 (closed) to 1 (open)
  storage.state = storage.state or "closed"

  --Setting starting and config values
  self.closedRotation = config.getParameter("closedRotation") or 0
  self.openRotation = config.getParameter("openRotation") or 90
  self.openTime = config.getParameter("openTime") or 1.0
  self.hingePoint = config.getParameter("hingePoint") or {0, 0}
  self.doorVector = config.getParameter("doorVector") or {0, -1}
  self.doorPolyPoints = config.getParameter("doorPoly") or {
	{0,-1}, {0,1}, {1,1}, {1,-1}
  }
  
  self.wasClosed = true
  self.wasMoving = false
  
  --Keeping track of our previous state
  self.lastState = storage.state

  updateInteractive()
  updatePhysicsCollision(storage.state)
end

function update()
  local cycle = storage.cycle
  local state = storage.state
  
  if state == "closed" then
	if not self.wasClosed then
	  animator.playSound("close")
	  animator.stopAllSounds("openingLoop")
	  self.wasClosed = true
	  self.wasMoving = false
	end
  elseif state == "opening" then
	if not self.wasMoving then
	  animator.playSound("openingLoop", -1)
	  self.wasClosed = false
	  self.wasMoving = true
	end
	cycle = math.min(1, (cycle + script.updateDt() / self.openTime))
	if cycle == 1 then
	  state = "open"
	end
  elseif state == "open" then
	if not self.wasClosed then
	  animator.playSound("close")
	  animator.stopAllSounds("openingLoop")
	  self.wasClosed = true
	  self.wasMoving = false
	end
  elseif state == "closing" then
	if not self.wasMoving then
	  animator.playSound("openingLoop", -1)
	  self.wasClosed = false
	  self.wasMoving = true
	end
	cycle = math.max(0, (cycle - script.updateDt() / self.openTime))
	if cycle == 0 then
	  state = "closed"
	end
  end
  
  --world.debugText(cycle, vec2.add(entity.position(), {0,0}), "red")
  --world.debugText(state, vec2.add(entity.position(), {0,1}), "red")
  --world.debugText(self.lastState, vec2.add(entity.position(), {0,2}), "red")
  
  local targetRotationDegrees = self.closedRotation + (cycle * self.openRotation)
  local targetRotationRadians = util.toRadians(targetRotationDegrees)
  animator.resetTransformationGroup("door")
  if storage.doorDirection < 0 then
	animator.rotateTransformationGroup("door", targetRotationRadians, animator.partPoint("door", "hingePointFlipped"))
  else
	animator.rotateTransformationGroup("door", targetRotationRadians, animator.partPoint("door", "hingePoint"))
  end
  
  --Figuring out the hinge and end point locations for the door
  --These values are used for debugging, but some parts are also used for calculating dynamic spaces and  damageSources
  local hinge = vec2.add(entity.position(), self.hingePoint)
  local doorVector = vec2.rotate(self.doorVector, targetRotationRadians)
  if storage.doorDirection < 0 then
	doorVector[1] = doorVector[1] * -1
  end
  local doorEndPoint = vec2.add(hinge, doorVector)
  world.debugPoint(hinge, "red")
  world.debugPoint(doorEndPoint, "red")
  world.debugLine(hinge, doorEndPoint, "red")
  
  --Setting the knockback for the door
  if config.getParameter("useDamageSource") then
	if state == "opening" or state == "closing" then
	  local damageSource = config.getParameter("damageSource")
	  local p1 = vec2.add(vec2.rotate(self.doorPolyPoints[1], targetRotationRadians), self.hingePoint)
	  local p2 = vec2.add(vec2.rotate(self.doorPolyPoints[2], targetRotationRadians), self.hingePoint)
	  local p3 = vec2.add(vec2.rotate(self.doorPolyPoints[3], targetRotationRadians), self.hingePoint)
	  local p4 = vec2.add(vec2.rotate(self.doorPolyPoints[4], targetRotationRadians), self.hingePoint)
	  if storage.doorDirection < 0 then
		local doorWidth = config.getParameter("doorWidth") or 1
		p1[1] = p1[1] * -1 + doorWidth
		p2[1] = p2[1] * -1 + doorWidth
		p3[1] = p3[1] * -1 + doorWidth
		p4[1] = p4[1] * -1 + doorWidth
	  end 
	  damageSource.poly = {p1, p2, p3, p4}	
	  object.setDamageSources({damageSource})
	else
	  object.setDamageSources()
	end
  end
  
  if self.lastState ~= state or state == "opening" or state == "closing" then
	updatePhysicsCollision(state, targetRotationRadians)
  end
  
  storage.cycle = cycle
  storage.state = state
  self.lastState = storage.state
end

function dynamicSpaces(radians)
  spaces = {}
    
  for _, space in ipairs(config.getParameter("doorSpaces")) do
	local spaceVector = vec2.rotate(space, radians)
	if storage.doorDirection < 0 then
	  spaceVector[1] = spaceVector[1] * -1
	end
	local tilePos = vec2.floor(vec2.add(self.hingePoint, spaceVector))
	--world.debugPoint(vec2.add(tilePos, entity.position()), "pink")
	local p1 = {tilePos[1] + 0, tilePos[2] + 0}
	local p2 = {tilePos[1] + 1, tilePos[2] + 0}
	local p3 = {tilePos[1] + 1, tilePos[2] + 1}
	local p4 = {tilePos[1] + 0, tilePos[2] + 1}
	local tilePoly = {p1, p2, p3, p4}
	world.debugPoly(poly.translate(tilePoly, entity.position()), "pink")
	table.insert(spaces, tilePos)
  end
  
  return spaces
end

function updatePhysicsCollision(state, radians)
  self.collideSpaces = {}
  local metamaterial = "metamaterial:lockedDoor"
  
  --While OPEN
  if state == "open" then
	self.newSpaces = config.getParameter("collisionSpacesOpen")
	for i, space in ipairs(self.newSpaces) do
	  table.insert(self.collideSpaces, {space, metamaterial})
	end
	object.setOutputNodeLevel(0, false)
	object.setOutputNodeLevel(1, true)
	--While OPENING or CLOSING
  elseif state == "opening" or state == "closing" then
	self.newSpaces = config.getParameter("collisionSpacesTransition")
	for i, space in ipairs(self.newSpaces) do
	  table.insert(self.collideSpaces, {space, metamaterial})
	end
	--Optionally calculate dynamic spaces
	if config.getParameter("useDynamicSpaces") then
	  self.dynamicSpaces = dynamicSpaces(radians)
	  for i, space in ipairs(self.dynamicSpaces) do
		table.insert(self.collideSpaces, {space, metamaterial})
	  end
	end
	object.setOutputNodeLevel(0, true)
	object.setOutputNodeLevel(1, false)
  --While CLOSED
  elseif state == "closed" then
	self.newSpaces = config.getParameter("collisionSpacesClosed")
	for i, space in ipairs(self.newSpaces) do
	  table.insert(self.collideSpaces, {space, metamaterial})
	end
	object.setOutputNodeLevel(0, false)
	object.setOutputNodeLevel(1, false)
  end
  
  object.setMaterialSpaces(self.collideSpaces)
  
  if config.getParameter("removeLiquids") then
	for _, space in ipairs(self.collideSpaces) do
	  local targetPos = vec2.add(vec2.add(entity.position(), space[1]), {0.5, 0.5})
	  world.forceDestroyLiquid(targetPos)
	  world.debugPoint(targetPos, "yellow")
	end
  end
end

function onNodeConnectionChange(args)
  updateInteractive()
  if object.isInputNodeConnected(0) then
    onInputNodeChange({ level = object.getInputNodeLevel(0) })
  end
end

function onInputNodeChange(args)
  if args.level then
    --Attempt to open the door
	if storage.state == "closed" or storage.state == "closing" then
	  storage.state = "opening"
	end
  else
    --Attempt to close the door
	if storage.state == "open" or storage.state == "opening" then
	  storage.state = "closing"
	end
  end
end

function onInteraction(args)
  if storage.state == "closed" or storage.state == "closing" then
	storage.state = "opening"
  elseif storage.state == "open" or storage.state == "opening" then
	storage.state = "closing"
  end
end

function updateInteractive()
  object.setInteractive(config.getParameter("interactive", true) and not object.isInputNodeConnected(0))
end

function setDirection(direction)
  storage.doorDirection = direction
  --animator.setGlobalTag("doorDirection", direction < 0 and "Left" or "Right")
  if direction < 0 then
	object.setConfigParameter("inputNodes", config.getParameter("flippedInputNodes"))
	object.setConfigParameter("outputNodes", config.getParameter("flippedOutputNodes"))
  end
end

--This function can be called by a colony deed scanning a house's content
--The function was slightly modified so that the scanner will only consider the 'closed' spaces as being part of the door, not all worldspaces the door occupies
function doorOccupiesSpace(position)
  local relative = {position[1] - object.position()[1], position[2] - object.position()[2]}
  --for _, space in ipairs(object.spaces()) do --This would have made the scanner consider ALL of the occupied spaces
  for _, space in ipairs(config.getParameter("collisionSpacesClosed")) do
    if math.floor(relative[1]) == space[1] and math.floor(relative[2]) == space[2] then
      return true
    end
  end
  return false
end
