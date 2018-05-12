function init()  
  if storage.state == nil then storage.state = config.getParameter("defaultLightState", true) end

  self.interactive = config.getParameter("interactive", true)
  object.setInteractive(self.interactive)

  if config.getParameter("inputNodes") then
    processWireInput()
  end

  setLightState(storage.state)
end

function onNodeConnectionChange(args)
  processWireInput()
end

function onInputNodeChange(args)
  processWireInput()
end

function onInteraction(args)
  if not config.getParameter("inputNodes") or not object.isInputNodeConnected(0) then
    storage.state = not storage.state
    setLightState(storage.state)
  end
end

function processWireInput()
  if object.isInputNodeConnected(0) then
    object.setInteractive(false)
    storage.state = object.getInputNodeLevel(0)
    setLightState(storage.state)
  elseif self.interactive then
    object.setInteractive(true)
  end
end

function setLightState(newState)
  --If we got activated
  if newState then
    object.setSoundEffectEnabled(true)
	animator.setAnimationState("light", "turnon")
	if animator.hasSound("on") then
      animator.playSound("on");
    end
    object.setLightColor(config.getParameter("lightColor", {255, 255, 255}))
  --If we got deactivated
  else
    object.setSoundEffectEnabled(false)
	animator.setAnimationState("light", "turnoff")
    if animator.hasSound("off") then
      animator.playSound("off");
    end
    object.setLightColor(config.getParameter("lightColorOff", {0, 0, 0}))
  end
end
