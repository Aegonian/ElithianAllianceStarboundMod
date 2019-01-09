require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  self.detectArea = config.getParameter("detectArea")
  self.detectArea[1] = object.toAbsolutePosition(self.detectArea[1])
  self.detectArea[2] = object.toAbsolutePosition(self.detectArea[2])
  
  self.connectedDoor = nil
  self.connectionChecked = false
  
  message.setHandler("openDoor", function()
	if animator.animationState("doorState") == "closed" or animator.animationState("doorState") == "closing" then
	  animator.setAnimationState("doorState", "opening")
	end
  end)
end

function update(dt)
  if not self.connectedDoor and not self.connectionChecked then
	checkDoorConnection()
	self.connectionChecked = true
  end
  
  --Check if there are players nearby
  local players = world.entityQuery(self.detectArea[1], self.detectArea[2], {
	includedTypes = {"player"},
	boundMode = "CollisionArea"
  })

  --If the door is connected, open or close the door based on player proximity
  if #players > 0 and self.connectedDoor and animator.animationState("doorState") == "closed" then
	animator.setAnimationState("doorState", "opening")
  elseif #players == 0 and self.connectedDoor and animator.animationState("doorState") == "open" then
	animator.setAnimationState("doorState", "closing")
  --If the door isn't connected, try to close the door
  elseif not self.connectedDoor and animator.animationState("doorState") == "open" then
	animator.setAnimationState("doorState", "closing")
  end
  
  --If we have a connected door and it still exists, make the door interactive
  if self.connectedDoor and world.entityExists(self.connectedDoor) then
	object.setInteractive(true)
  else
	object.setInteractive(false)
	self.connectedDoor = false
  end
  
  --Debug the detectArea and the stored door connection ID
  local detectPoly = {self.detectArea[1], {self.detectArea[1][1], self.detectArea[2][2]}, self.detectArea[2], {self.detectArea[2][1], self.detectArea[1][2]}}
  world.debugPoly(detectPoly, "cyan")
  world.debugText(sb.print(self.connectedDoor), entity.position(), "yellow")
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
	  local entityName = world.entityName(entityId)
	  if entityName == world.entityName(entity.id()) then
		self.connectedDoor = entityId
	  end
	end
  end
end
