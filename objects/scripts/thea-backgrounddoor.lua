require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  self.detectArea = config.getParameter("detectArea")
  self.detectArea[1] = object.toAbsolutePosition(self.detectArea[1])
  self.detectArea[2] = object.toAbsolutePosition(self.detectArea[2])
  
  self.connectedDoor = nil
  self.doorLocked = false
  self.lockInputLevel = nil
  self.forceOpenTimer = 0
  
  message.setHandler("openDoor", function()
	if animator.animationState("doorState") == "closed" or animator.animationState("doorState") == "closing" then
	  animator.setAnimationState("doorState", "open")
	  self.forceOpenTimer = 0.5
	end
  end)
end

function update(dt)
  --If we don't have a connected door, check for one every frame
  --Doing this every frame prevents rare issues where the connection check fails when loading a new sector
  if not self.connectedDoor then
	checkDoorConnection()
  end
  
  --If we have input on the lock node, invert that to set lock state. If there is no connection in the lock node, unlock the door
  if object.isInputNodeConnected(1) then
	self.lockInputLevel = object.getInputNodeLevel(1)
	self.doorLocked = not self.lockInputLevel
  else
	self.doorLocked = false
  end
  
  --Count down the force open timer
  self.forceOpenTimer = math.max(0, self.forceOpenTimer - dt)
  
  --Check if there are players nearby
  local players = world.entityQuery(self.detectArea[1], self.detectArea[2], {
	includedTypes = {"player"},
	boundMode = "CollisionArea"
  })

  --If the door is connected, open or close the door based on player proximity
  if #players > 0 and self.connectedDoor and animator.animationState("doorState") == "closed" and not self.doorLocked then
	animator.setAnimationState("doorState", "opening")
	animator.playSound("open")
  elseif #players == 0 and self.connectedDoor and animator.animationState("doorState") == "open" and self.forceOpenTimer == 0 and not self.doorLocked then
	animator.setAnimationState("doorState", "closing")
	animator.playSound("close")
  --If the door isn't connected, try to close the door
  elseif not self.connectedDoor and animator.animationState("doorState") == "open" and self.forceOpenTimer == 0 and not self.doorLocked then
	animator.setAnimationState("doorState", "closing")
	animator.playSound("close")
  elseif animator.animationState("doorState") == "open" and self.doorLocked then
	animator.setAnimationState("doorState", "closing")
	animator.playSound("close")
  end
  
  --If we have a connected door and it still exists, make the door interactive
  if self.connectedDoor and world.entityExists(self.connectedDoor) and not self.doorLocked then
	object.setInteractive(true)
  else
	object.setInteractive(false)
	self.connectedDoor = false
  end
  
  --Debug the detectArea and the stored door connection ID
  local detectPoly = {self.detectArea[1], {self.detectArea[1][1], self.detectArea[2][2]}, self.detectArea[2], {self.detectArea[2][1], self.detectArea[1][2]}}
  world.debugPoly(detectPoly, "cyan")
  world.debugText("Lock: " .. sb.printJson(self.doorLocked), vec2.add(entity.position(), {0,1}), "yellow")
  world.debugText("Link ID: " .. sb.printJson(self.connectedDoor), vec2.add(entity.position(), {0,0}), "yellow")
  world.debugPoint(world.entityMouthPosition(entity.id()), "cyan")
end

--Called on interaction from a player or NPC. Used for active teleportation
function onInteraction(args)  
  local targetPosition = world.entityMouthPosition(self.connectedDoor)
  local interactedEntity = args.sourceId
  
  if self.connectedDoor then
	world.sendEntityMessage(interactedEntity, "applyStatusEffect", "thea-teleportentity", 0.1, self.connectedDoor)
  end
  
  --TODO: Implement status effect that teleports an entity. Use the sourceEntity to transmit target position?
end

--Called when any node connection changes
function onNodeConnectionChange()
  checkDoorConnection()
end

--Can be called to check if there is a connected door
function checkDoorConnection()
  self.connectedDoor = nil
  for entityId, _ in pairs(object.getOutputNodeIds(0)) do
	if world.entityExists(entityId) then
	  --Check if the connected object allows background door connections
	  if world.getObjectParameter(entityId, "allowBackgroundDoorConnection", false) then
		self.connectedDoor = entityId
	  end
	  
	  --local entityName = world.entityName(entityId)
	  --if entityName == world.entityName(entity.id()) then
		--self.connectedDoor = entityId
	  --end
	end
  end
end
