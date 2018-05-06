--Switch code that allow the object to be configured as non-interactive

function init()
  object.setInteractive(config.getParameter("interactive", true))
  if storage.state == nil then
    output(config.getParameter("defaultSwitchState", false))
  else
    output(storage.state)
  end
end

function state()
  return storage.state
end

function onInteraction(args)
  output(not storage.state)
end

function onNpcPlay(npcId)
  onInteraction()
end

function output(state)
  storage.state = state
  if state then
    animator.setAnimationState("switchState", "on")
    if not (config.getParameter("alwaysLit")) then object.setLightColor(config.getParameter("lightColor", {0, 0, 0, 0})) end
    object.setSoundEffectEnabled(true)
    animator.playSound("on");
    object.setAllOutputNodes(true)
  else
    animator.setAnimationState("switchState", "off")
    if not (config.getParameter("alwaysLit")) then object.setLightColor(config.getParameter("lightColorOff", {0, 0, 0})) end
    object.setSoundEffectEnabled(false)
    animator.playSound("off");
    object.setAllOutputNodes(false)
  end
end
