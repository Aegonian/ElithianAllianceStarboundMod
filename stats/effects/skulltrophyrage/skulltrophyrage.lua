function init()
  --Power
  self.powerModifier = config.getParameter("powerModifier", 0)
  effect.addStatModifierGroup({
	{stat = "powerMultiplier", effectiveMultiplier = self.powerModifier}
  })
  effect.addStatModifierGroup({
    {stat = "jumpModifier", amount = 0.2}
  })
end


function update(dt)
  mcontroller.controlModifiers({
	speedModifier = 1.25,
	airJumpModifier = 1.20
  })
end

function uninit()

end
