function init()
  --Set the item required for successful interaction
  self.requiredItem = config.getParameter("requiredItem")
  
  --Ensure that the object can be interacted with
  object.setInteractive(config.getParameter("interactive", true))
  
  --Set the initial state
  if storage.state == nil then
    output(config.getParameter("defaultSwitchState", false))
  else
    output(storage.state)
  end
  
  --Set up the timer function
  if storage.timer == nil then
    storage.timer = 0
  end
  
  --Set the time to remain active after being activated
  self.activeTime = config.getParameter("activeTime")
end

function state()
  return storage.state
end

function onInteraction(args)
  local playerId = args.sourceId
  if storage.state == false and world.entityHasCountOfItem(playerId, self.requiredItem) > 0 then
	output(true)

	animator.playSound("on")
	storage.timer = self.activeTime
  else
	animator.playSound("off")
  end
end

function output(state)
  if storage.state ~= state then
    storage.state = state
    object.setAllOutputNodes(state)
    if state then
      animator.setAnimationState("switchState", "on")
      --animator.playSound("on")
    else
      animator.setAnimationState("switchState", "off")
      --animator.playSound("off")
    end
  else
  end
end

function update(dt)
  if storage.timer > 0 then
    storage.timer = math.max(0, storage.timer - dt)

    if storage.timer == 0 then
      output(false)
    end
  end
end
