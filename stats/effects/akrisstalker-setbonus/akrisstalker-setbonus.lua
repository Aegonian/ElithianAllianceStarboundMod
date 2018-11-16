require "/scripts/util.lua"

function init()
end

function update(dt)
  --While invisible, improve speed and jumping
  if world.getProperty("entityinvisible" .. tostring(entity.id())) then
	mcontroller.controlModifiers(
	  {
		speedModifier = config.getParameter("speedModifier"),
		jumpModifier = config.getParameter("jumpModifier"),
		airJumpModifier = config.getParameter("airJumpModifier")
	  }
	)
  end
end

function uninit()
end
