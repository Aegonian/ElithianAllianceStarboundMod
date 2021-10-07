require "/scripts/vec2.lua"

function init()
  self.onMessage = config.getParameter("onMessage")
  self.offMessage = config.getParameter("offMessage")
  self.errorMessage = config.getParameter("errorMessage")
  
  self.dungeonId = world.dungeonId(object.position())
  self.protectedIds = {65531, 65532, 65533, 65534, 65535}
  self.validPlacement = false
  
  --Check if we were placed in a valid dungeonId
  self.validPlacement = false
  for _, id in ipairs(self.protectedIds) do
	if self.dungeonId == id then
	  self.validPlacement = true
	end
  end
  
  --If we are valid, update according to state. Otherwise, set as non-interactive and set state to false
  if self.validPlacement then
	object.setInteractive(config.getParameter("interactive", true) and not (object.inputNodeCount() > 0 and object.isInputNodeConnected(0)))
	if storage.state == nil then
	  storage.state = config.getParameter("defaultState", true)
	end
  else
	object.setInteractive(true)
	storage.state = false
	if self.errorMessage then
	  object.say(self.errorMessage)
	end
  end
  
  updateAnimationState(storage.state)
  
  if object.outputNodeCount() > 0 then
	object.setOutputNodeLevel(0, storage.state)
  end
  
  self.lastState = storage.state
  storage.health = storage.health or object.health()
end

function update()
  --If our position is no longer protected but it was last frame, something else changed the world protection. Set our state to false and update animation
  if not world.isTileProtected(entity.position()) and self.lastState and self.validPlacement then
	setState(false)
  end
  
  --If our position is now protected but it wasn't last frame, something else changed the world protection. Set our state to true and update animation
  if world.isTileProtected(entity.position()) and not self.lastState and self.validPlacement then
	setState(true)
  end
  
  --If our current health is lower than stored health, we received damage and should burst the damage particle emitter
  if object.health() ~= storage.health then
	animator.burstParticleEmitter("damage")
	animator.playSound("damage")
  end
  
  self.lastState = storage.state
  storage.health = object.health()
  
  world.debugText("ID at position: " .. self.dungeonId, entity.position(), "yellow")
  world.debugText("Placement is valid: " .. sb.print(self.validPlacement), vec2.add(entity.position(), {0,1}), "yellow")
  world.debugText("Current state: " .. sb.print(storage.state), vec2.add(entity.position(), {0,2}), "yellow")
end

--When we get interacted with:
-- If we are validly placed, switch our state
-- If we are invalidly placed, play error sound and message
function onInteraction(args)
  if self.validPlacement then
	setState(not storage.state)
  else
	animator.playSound("error")
	if self.errorMessage then
	  object.say(self.errorMessage)
	end
  end
end

--When our nodes are modified (detached/attached)
function onNodeConnectionChange(args)
  if self.validPlacement then
	object.setInteractive(config.getParameter("interactive", true) and not object.isInputNodeConnected(0))
  else
	object.setInteractive(true)
  end
end

--When our input nodes change state
function onInputNodeChange(args)
  if self.validPlacement then
	setState(object.getInputNodeLevel(0))
  end
end

--Set the state of the shield generator
function setState(state)
  if self.validPlacement then
	if state ~= storage.state then
	  storage.state = state
	  updateAnimationState(storage.state)
	  for _, id in ipairs(self.protectedIds) do
		world.setTileProtection(id, storage.state)
	  end
	  world.setTileProtection(self.dungeonId, storage.state)
	  if object.outputNodeCount() > 0 then
		object.setOutputNodeLevel(0, storage.state)
	  end
	  
	  --Optionally show a message
	  if storage.state then
		if self.onMessage then
		  object.say(self.onMessage)
		end
	  else
		if self.offMessage then
		  object.say(self.offMessage)
		end
	  end
	end
  end
end

--When we die
function die(smash)
  --If we are validly placed, set our state to false
  if self.validPlacement and storage.state then
	setState(false)
  end
  
  --If we were smashed and are set to explode, spawn explosion
  if config.getParameter("explodeOnSmash") and smash then
	for _, position in ipairs(config.getParameter("explosionPositions")) do
	  local projectileConfig = {
		damageTeam = { type = "indiscriminate" },
		power = config.getParameter("explosionDamage"),
		onlyHitTerrain = false,
		timeToLive = 0,
		damageRepeatGroup = "theagenerator",
		actionOnReap = {
		  {
			action = "config",
			file =  config.getParameter("explosionConfig")
		  }
		}
	  }
	  
	  world.spawnProjectile("invisibleprojectile", vec2.add(object.position(), position), entity.id(), {0,0}, false, projectileConfig)
	end
  end
end

--Update the animation of our object
function updateAnimationState(state)
  --If we are turned on
  if state and self.validPlacement then
	animator.setAnimationState("switchState", "on")
	animator.playSound("on")
	if not (config.getParameter("alwaysLit")) then
	  object.setLightColor(config.getParameter("lightColor", {0, 0, 0, 0}))
	end
  --If we are turned off
  elseif not state and self.validPlacement then
	animator.setAnimationState("switchState", "off")
	animator.playSound("off")
	if not (config.getParameter("alwaysLit")) then
	  object.setLightColor({0, 0, 0, 0})
	end
  --If we are invalidly placed
  else
	animator.setAnimationState("switchState", "error")
	animator.playSound("error")
	if not (config.getParameter("alwaysLit")) then
	  object.setLightColor({0, 0, 0, 0})
	end
  end
end
