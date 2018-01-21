function init()
  if storage.state == nil then
	storage.state = config.getParameter("defaultLightState", true)
  end
  storage.timer = storage.timer or config.getParameter("onTime", 1)
  storage.progress = storage.progress or config.getParameter("transitionTime", 1)
  
  setLightState(storage.state)
end

function update(dt)
  storage.timer = math.max(0, storage.timer - dt)
  
  if storage.timer == 0 then
	storage.state = not storage.state
    setLightState(storage.state)
	if storage.state then
	  storage.timer = config.getParameter("onTime", 1)
	else
	  storage.timer = config.getParameter("offTime", 1)
	end
  end
  
  --If we have been configured to use smooth transitions, continuously update light state
  if config.getParameter("smoothTransition", false) then
	setLightState(storage.state)
	
	if storage.state then
	  storage.progress = math.min(config.getParameter("transitionTime", 1), storage.progress + dt)
	else
	  storage.progress = math.max(0, storage.progress - dt)
	end
  end
  
  --world.debugText(storage.progress, object.position(), "red")
end

function setLightState(newState)
  if newState then
    animator.setAnimationState("light", "on")
    object.setSoundEffectEnabled(true)
	if config.getParameter("smoothTransition", false) then
	  local R = math.ceil(config.getParameter("lightColor")[1] * (storage.progress / config.getParameter("transitionTime", 1)))
	  local G = math.ceil(config.getParameter("lightColor")[2] * (storage.progress / config.getParameter("transitionTime", 1)))
	  local B = math.ceil(config.getParameter("lightColor")[3] * (storage.progress / config.getParameter("transitionTime", 1)))
	  object.setLightColor({R, G, B})
	  
	  --world.debugText(sb.printJson({R, G, B}), entity.position(), "red")
	else
	  object.setLightColor(config.getParameter("lightColor", {255, 255, 255}))
	end
  else
    animator.setAnimationState("light", "off")
    object.setSoundEffectEnabled(false)
	if config.getParameter("smoothTransition", false) then
	  local R = math.ceil(config.getParameter("lightColor")[1] * (storage.progress / config.getParameter("transitionTime", 1)))
	  local G = math.ceil(config.getParameter("lightColor")[2] * (storage.progress / config.getParameter("transitionTime", 1)))
	  local B = math.ceil(config.getParameter("lightColor")[3] * (storage.progress / config.getParameter("transitionTime", 1)))
	  object.setLightColor({R, G, B})
	  
	  --world.debugText(sb.printJson({R, G, B}), entity.position(), "red")
	else
	  object.setLightColor(config.getParameter("lightColorOff", {0, 0, 0}))
	end
  end
end
