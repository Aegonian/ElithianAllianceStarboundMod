require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  self.liquidConversions = config.getParameter("liquidConversions")
  self.minimumLiquidLevel = config.getParameter("minimumLiquidLevel")
end

function update(dt)
  --Convert liquids to materials if the projectile file is correctly configured
  if self.liquidConversions then
	local liquid = world.liquidAt(mcontroller.position())
	local liquidAbove = world.liquidAt(vec2.add(mcontroller.position(), {0,1}))
	local liquidBelow = world.liquidAt(vec2.add(mcontroller.position(), {0,-1}))
	local materialAbove = world.material(vec2.add(mcontroller.position(), {0,1}), "foreground")
	
	--Check if the liquid at the projectile's position is the surface of the liquid
	local isLiquidSurface = false
	if liquid and not materialAbove then
	  --If there is no liquid above and liquid is over minimum liquid level
	  if liquid[2] > self.minimumLiquidLevel and not liquidAbove then
		isLiquidSurface = true
	  --If the same liquid is also below and the liquid above is not full
	  elseif liquidBelow and liquidBelow[1] == liquid[1] and not liquidAbove then
		isLiquidSurface = true
	  end
	end
	
	if isLiquidSurface then
	  --For every configured conversion, check if the current liquid matches anything in our conversion lists
	  for _, conversion in pairs(self.liquidConversions) do
		if liquid[1] == conversion[1] then
		  --If placement of material succeeded, kill the projectile
		  if world.placeMaterial(mcontroller.position(), "foreground", conversion[2], nil, config.getParameter("allowOverlap", false)) then
			projectile.die()
		  end
		end
	  end
	end
  end
end