function init()
  effect.addStatModifierGroup({
    {stat = "protection", amount = config.getParameter("protectionAmount", 10)}, --Adds the specified value to the player's protection stat
    {stat = "protection", effectiveMultiplier = config.getParameter("protectionModifier", 2.0)} --Multiplies the player's protection stat by the specified value
    --{stat = "protection", baseMultiplier = config.getParameter("protection", 100)} --Doesn't seem to do anything...
  })

  script.setUpdateDelta(0)
end

function update(dt)
  --world.debugText(status.stat("protection"), mcontroller.position(), "blue")
end

function uninit()
end
