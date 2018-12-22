function init()
  effect.addStatModifierGroup({
	{stat = "jumpModifier", amount = config.getParameter("jumpModifier", 0.25)},
	{stat = "jumpModifier", amount = config.getParameter("jumpModifier", 0.25)}
  })
end

function update(dt)
  mcontroller.controlModifiers({
	airJumpModifier = config.getParameter("jumpModifier", 0.25)
  })
end

function uninit()

end
