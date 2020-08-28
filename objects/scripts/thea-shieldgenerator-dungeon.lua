require "/scripts/vec2.lua"

function init()
  self.dungeonId = world.dungeonId(object.position())
  self.hasDoneFirstCheck = false
  
  object.setInteractive(config.getParameter("interactive", true) and not (object.inputNodeCount() > 0 and object.isInputNodeConnected(0)))

  if storage.state == nil then
    storage.state = config.getParameter("defaultState", true);
  end

  updateAnimationState(storage.state)

  if object.outputNodeCount() > 0 then
    object.setOutputNodeLevel(0, storage.state)
  end

  script.setUpdateDelta(0);
end

function onInteraction(args)
  output(not storage.state)
end

function onNodeConnectionChange(args)
  object.setInteractive(config.getParameter("interactive", true) and not object.isInputNodeConnected(0))
end

function onInputNodeChange(args)
  output(object.getInputNodeLevel(0))
end

function output(state)
  if state ~= storage.state then
    storage.state = state
    updateAnimationState(storage.state)
    world.setTileProtection(self.dungeonId, storage.state)
    if object.outputNodeCount() > 0 then
      object.setOutputNodeLevel(0, storage.state)
    end
  end
end

function die(smash)
  if storage.state then
    output(not storage.state)
  end
  if config.getParameter("explodeOnSmash") and smash then
    world.spawnProjectile(config.getParameter("explosionProjectile"), vec2.add(object.position(), config.getParameter("explosionOffset", {0,0})), entity.id(), {0,0})
  end
end

function updateAnimationState(state)
  if state then
    animator.setAnimationState("switchState", "on")
    if not (config.getParameter("alwaysLit")) then object.setLightColor(config.getParameter("lightColor", {0, 0, 0, 0})) end
    animator.playSound("on");
  else
    animator.setAnimationState("switchState", "off")
    if not (config.getParameter("alwaysLit")) then object.setLightColor({0, 0, 0, 0}) end
    animator.playSound("off");
  end
end
