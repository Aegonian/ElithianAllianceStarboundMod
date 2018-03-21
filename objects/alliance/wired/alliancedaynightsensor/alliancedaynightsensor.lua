function init()
end

function update(dt)
  local timeofDay = world.timeOfDay()

  if timeofDay <= 0.5 then
    object.setOutputNodeLevel(0, false)
    object.setOutputNodeLevel(1, true)
    animator.setAnimationState("switchState", "day")
  else
    object.setOutputNodeLevel(0, true)
    object.setOutputNodeLevel(1, false)
    animator.setAnimationState("switchState", "night")
  end
  
  --world.debugText(sb.printJson(timeofDay), entity.position(), "red")
end