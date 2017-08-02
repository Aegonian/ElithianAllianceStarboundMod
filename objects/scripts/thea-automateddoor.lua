function init()
  setDirection(storage.doorDirection or object.direction())

  if storage.locked == nil then
    storage.locked = config.getParameter("locked", false)
  end

  if storage.state == nil then
    if config.getParameter("defaultState") == "open" then
      openDoor()
    else
      closeDoor()
    end
  else
    animator.setAnimationState("doorState", storage.state and "open" or "closed")
  end

  updateCollisionAndWires()
  updateLight()

  message.setHandler("openDoor", function() openDoor() end)
  message.setHandler("lockDoor", function() lockDoor() end)
  
  --Set the triggerTimer for entity detection
  self.triggerTimer = 0
  
  --Set the detection area
  local detectArea = config.getParameter("detectArea")
  local pos = object.position()
  if type(detectArea[2]) == "number" then
    --center and radius
    self.detectArea = {
      {pos[1] + detectArea[1][1], pos[2] + detectArea[1][2]},
      detectArea[2]
    }
  elseif type(detectArea[2]) == "table" and #detectArea[2] == 2 then
    --rect corner1 and corner2
    self.detectArea = {
      {pos[1] + detectArea[1][1], pos[2] + detectArea[1][2]},
      {pos[1] + detectArea[2][1], pos[2] + detectArea[2][2]}
    }
  end
end

function update(dt)
  --world.debugPoint(self.detectArea[1], "green")
  --world.debugPoint(self.detectArea[2], "green")
  
  if self.triggerTimer > 0 then
    self.triggerTimer = self.triggerTimer - dt
  elseif self.triggerTimer <= 0 then
    local entityIds = world.entityQuery(self.detectArea[1], self.detectArea[2], {
        withoutEntityId = entity.id(),
        includedTypes = {"creature"}
      })

    if self.detectDamageTeam then
      entityIds = util.filter(entityIds, function (entityId)
          local entityDamageTeam = world.entityDamageTeam(entityId)
          if self.detectDamageTeam.type and self.detectDamageTeam.type ~= entityDamageTeam.type then
            return false
          end
          if self.detectDamageTeam.team and self.detectDamageTeam.team ~= entityDamageTeam.team then
            return false
          end
          return true
        end)
    end

    if #entityIds > 0 then
      self.triggerTimer = config.getParameter("detectDuration")
	  openDoor()
    else
      closeDoor()
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
    for i, space in ipairs(object.spaces()) do
      table.insert(self.closedMaterialSpaces, {space, metamaterial})
    end
  end
  self.openMaterialSpaces = config.getParameter("openMaterialSpaces", {})
end

function setDirection(direction)
  storage.doorDirection = direction
  animator.setGlobalTag("doorDirection", direction < 0 and "Left" or "Right")
end

function hasCapability(capability)
  if capability == 'lockedDoor' then
    return storage.locked
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
    animator.setAnimationState("doorState", "closed")
    return true
  end
end

function closeDoor()
  if storage.state ~= false then
    storage.state = false
    animator.playSound("close")
    animator.setAnimationState("doorState", "closing")
    updateCollisionAndWires()
    updateLight()
  end
end

function openDoor(direction)
  if not storage.state then
    storage.state = true
    storage.locked = false -- make sure we don't get out of sync when wired
    setDirection((direction == nil or direction * object.direction() < 0) and -1 or 1)
    animator.playSound("open")
    animator.setAnimationState("doorState", "open")
    updateCollisionAndWires()
    updateLight()
  end
end
