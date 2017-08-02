require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()  
  setDirection(storage.doorDirection or object.direction())
  
  --Setting up storage for making door rotation persistent
  storage.cycle = storage.cycle or 0		--goes from 0 (closed) to 1 (open)
  storage.state = storage.state or "closed"

  --Setting starting and config values
  self.closedRotation = config.getParameter("closedRotation") or 0
  self.openRotation = config.getParameter("openRotation") or 90
  self.openTime = config.getParameter("openTime") or 1.0
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
  
  if self.lastState ~= state then
	updatePhysicsCollision(state)
  end
  
  storage.cycle = cycle
  storage.state = state
  self.lastState = storage.state
end

function updatePhysicsCollision(state)
  self.collideSpaces = {}
  local metamaterial = "metamaterial:lockedDoor"
  
  if state == "open" then
	self.newSpaces = config.getParameter("collisionSpacesOpen")
	for i, space in ipairs(self.newSpaces) do
	  table.insert(self.collideSpaces, {space, metamaterial})
	end
  elseif state == "opening" or state == "closing" then
	self.newSpaces = config.getParameter("collisionSpacesTransition")
	for i, space in ipairs(self.newSpaces) do
	  table.insert(self.collideSpaces, {space, metamaterial})
	end
  elseif state == "closed" then
	self.newSpaces = config.getParameter("collisionSpacesClosed")
	for i, space in ipairs(self.newSpaces) do
	  table.insert(self.collideSpaces, {space, metamaterial})
	end
  end
  
  object.setMaterialSpaces(self.collideSpaces)
  
--Old code, might be useful for other stuff later down the line
  --local isFlipped = storage.doorDirection < 0
  --physics.setCollisionEnabled("openLeft", isFlipped and state == "open")
  --physics.setCollisionEnabled("closedLeft", isFlipped and state == "closed")
  --physics.setCollisionEnabled("transitionLeft", isFlipped and (state == "opening" or state == "closing"))
  --physics.setCollisionEnabled("openRight", not isFlipped and state == "open")
  --physics.setCollisionEnabled("closedRight", not isFlipped and state == "closed")
  --physics.setCollisionEnabled("transitionRight", not isFlipped and (state == "opening" or state == "closing"))
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
