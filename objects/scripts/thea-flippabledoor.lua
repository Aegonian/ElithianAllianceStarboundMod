require "/scripts/vec2.lua"

function init()  
  setDirection(storage.doorDirection or object.direction())
  self.forceClose = storage.state or false

  if storage.locked == nil then
    storage.locked = config.getParameter("locked", false)
  end

  if storage.state == nil then
    if config.getParameter("defaultState") == "open" then
      openDoor()
    else
      closeDoor(self.forceClose)
    end
  else
    animator.setAnimationState("doorState", storage.state and "open" or "closed")
  end

  updateCollisionAndWires()
  updateInteractive()
  updateLight()

  message.setHandler("openDoor", function() openDoor() end)
  message.setHandler("lockDoor", function() lockDoor() end)
end

function update()
  --local test = "Trying to close door? " .. sb.printJson(self.forceClose, 1)
  --world.debugText(test, entity.position(), "blue")
  --local test2 = "Door is currently open? " .. sb.printJson(storage.state, 1)
  --world.debugText(test2, vec2.add({0, 1}, entity.position()), "blue")
  --local test3 = "Door should be open? " .. sb.printJson(object.getInputNodeLevel(0) or storage.state, 1)
  --world.debugText(test3, vec2.add({0, 2}, entity.position()), "blue")
  
  --If the door was closed by a node input change, but the door was blocked, continue trying to close the door
  if self.forceClose then
	closeDoor(self.forceClose)
  end
  
  --If the door should be open, but it isn't, force it to open
  if object.isInputNodeConnected(0) then
	if object.getInputNodeLevel(0) and not storage.state then
	  openDoor()
	end
  end
end

function checkDoorBlocked()
  local lineStart = nil
  local lineEnd = nil
  local doorBlocked = false
  local scanIncludedTypes = config.getParameter("includedTypes") or { "monster", "npc", "player" }
  
  local scanLineCount = config.getParameter("scanLineCount") or 1
  for i = 1, scanLineCount do
	if object.direction() > 0 then
	  lineStart = vec2.add(entity.position(), config.getParameter("entityCheckLineStart")[i])
	  lineEnd = vec2.add(entity.position(), config.getParameter("entityCheckLineEnd")[i])
	else
	  lineStart = vec2.add(entity.position(), config.getParameter("flippedEntityCheckLineStart")[i])
	  lineEnd = vec2.add(entity.position(), config.getParameter("flippedEntityCheckLineEnd")[i])
	end
	
	world.debugLine(lineStart, lineEnd, "blue")
	local entities = world.entityLineQuery(lineStart, lineEnd, { includedTypes = scanIncludedTypes })
	if #entities > 0 then
	  doorBlocked = true
	end
  end
  
  if doorBlocked then
	--world.debugText("BLOCKED", entity.position(), "red")
	return true
  else
	--world.debugText("CLEAR", entity.position(), "green")
	return false
  end
end

function onNodeConnectionChange(args)
  updateInteractive()
  updateCollisionAndWires()
  if object.isInputNodeConnected(0) then
    onInputNodeChange({ level = object.getInputNodeLevel(0) })
  end
end

function onInputNodeChange(args)
  if args.level then
    openDoor(storage.doorDirection)
  else
	--closeDoor(not args.level)
	closeDoor(true)
  end
end

function onInteraction(args)
  if storage.locked then
    animator.playSound("locked")
  else
    if not storage.state then
      openDoor(args.source[1])
    else
      closeDoor(false)
    end
  end
end

function updateLight()
  if not storage.state then
    object.setLightColor(config.getParameter("closedLight", {0,0,0,0}))
  else
    object.setLightColor(config.getParameter("openLight", {0,0,0,0}))
  end
end

function updateInteractive()
  object.setInteractive(config.getParameter("interactive", true) and not object.isInputNodeConnected(0) and not storage.locked)
end

function updateCollisionAndWires()
  setupMaterialSpaces()
  object.setMaterialSpaces(storage.state and self.openMaterialSpaces or self.closedMaterialSpaces)
  object.setAllOutputNodes(storage.state)
end

function setupMaterialSpaces()
  self.closedMaterialSpaces = config.getParameter("closedMaterialSpaces")
  if not self.closedMaterialSpaces then
    self.closedMaterialSpaces = {}
    local metamaterial = "metamaterial:door"
    if object.isInputNodeConnected(0) then
      metamaterial = "metamaterial:lockedDoor"
    end
    for i, space in ipairs(object.spaces()) do
      table.insert(self.closedMaterialSpaces, {space, metamaterial})
    end
  end
  self.openMaterialSpaces = config.getParameter("openMaterialSpaces", {})
end

function setDirection(direction)
  storage.doorDirection = direction
  animator.setGlobalTag("doorDirection", direction < 0 and "Left" or "Right")
  if direction < 0 then
	object.setConfigParameter("inputNodes", config.getParameter("flippedInputNodes"))
	object.setConfigParameter("outputNodes", config.getParameter("flippedOutputNodes"))
  end
end

function hasCapability(capability)
  if capability == 'lockedDoor' then
    return storage.locked
  elseif object.isInputNodeConnected(0) or storage.locked then
    return false
  elseif capability == 'door' then
    return true
  elseif capability == 'closedDoor' then
    return not storage.state
  elseif capability == 'openDoor' then
    return storage.state
  else
    return false
  end
end

function doorOccupiesSpace(position)
  local relative = {position[1] - object.position()[1], position[2] - object.position()[2]}
  for _, space in ipairs(object.spaces()) do
    if math.floor(relative[1]) == space[1] and math.floor(relative[2]) == space[2] then
      return true
    end
  end
  return false
end

function lockDoor()
  if not storage.locked then
    storage.locked = true
    updateInteractive()
    if storage.state then
      -- close door before locking
      storage.state = false
      animator.playSound("close")
      animator.setAnimationState("doorState", "locking")
      updateCollisionAndWires()
    else
      animator.setAnimationState("doorState", "locked")
    end
    return true
  end
end

function unlockDoor()
  if storage.locked then
    storage.locked = false
    updateInteractive()
    animator.setAnimationState("doorState", "closed")
    return true
  end
end

function closeDoor(forceClose)
  self.forceClose = forceClose
  
  local allowClose = false  
  if storage.state ~= false then
    if config.getParameter("performEntityCheck") then
	  if not checkDoorBlocked() then
		allowClose = true
	  end
	else
	  allowClose = true
	end
  end
  
  if allowClose then
	storage.state = false
	updateInteractive()
	animator.playSound("close")
	animator.setAnimationState("doorState", "closing")
	updateCollisionAndWires()
	updateLight()
	self.forceClose = false
  end
end

function openDoor(direction)
  if not storage.state then
    storage.state = true
    storage.locked = false -- make sure we don't get out of sync when wired
    updateInteractive()
    animator.playSound("open")
    animator.setAnimationState("doorState", "open")
    updateCollisionAndWires()
    updateLight()
  end
end
