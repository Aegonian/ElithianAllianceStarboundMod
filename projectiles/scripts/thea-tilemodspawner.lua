require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  self.liquidConversions = config.getParameter("liquidConversions")
  self.minimumLiquidLevel = config.getParameter("minimumLiquidLevel")
  self.tileModProjectile = config.getParameter("tileModProjectile")
  self.tickTime = config.getParameter("tickTime")
  self.tickTimer = self.tickTime
end

function update(dt)  
  self.tickTimer = self.tickTimer - dt
  if self.tickTimer <= 0 then
    self.tickTimer = self.tickTime
    
	local sourceEntityId = projectile.sourceEntity() or entity.id()
	world.spawnProjectile(
	  self.tileModProjectile,
	  mcontroller.position(),
	  sourceEntityId,
	  {0,0},
	  false,
	  {
		--damage dealt by the bolt is base damage (boltPower) multiplied by the player's power modifier
		power = 1,
		damageTeam = sourceDamageTeam
	  }
	)
  end
  
  --Optionally convert liquids to materials
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